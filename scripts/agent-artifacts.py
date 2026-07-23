#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import shutil
import sys
import time
from pathlib import Path


ALLOWED_ROOTS = (
    ".tmp",
    ".xcode-build",
    ".xcode-build-ci-parity",
    ".xcode-build-release-parity",
    ".xcode-build-tests",
    "build",
    "dist",
)
ACTIVE_WINDOW_SECONDS = 15 * 60
ACTIVE_MARKERS = (".lock", "build.db.lock", "index.lock")


def human_size(size: int) -> str:
    value = float(size)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if value < 1024 or unit == "TiB":
            return f"{value:.1f}{unit}"
        value /= 1024
    return f"{size}B"


def artifact_root(project_root: Path, name: str) -> Path:
    path = project_root / name
    if path.parent != project_root:
        raise ValueError(f"artifact path is outside project root: {name}")
    return path


def artifact_result(name: str, path: Path, status: str, size: int = 0, files: int = 0, newest: float | None = None) -> dict[str, object]:
    return {
        "name": name,
        "path": str(path),
        "status": status,
        "size": size,
        "files": files,
        "newest": newest,
        "active": False,
    }


def walk_artifact(path: Path) -> tuple[int, int, float]:
    total_size = 0
    files = 0
    newest = path.stat().st_mtime
    for directory, directory_names, file_names in os.walk(path, topdown=True, followlinks=False):
        directory_names[:] = sorted(
            name for name in directory_names if not (Path(directory) / name).is_symlink()
        )
        for file_name in sorted(file_names):
            file_path = Path(directory) / file_name
            if file_path.is_symlink():
                continue
            try:
                stat = file_path.stat()
            except OSError:
                continue
            total_size += stat.st_size
            files += 1
            newest = max(newest, stat.st_mtime)
    return total_size, files, newest


def inspect_root(project_root: Path, name: str, now: float) -> dict[str, object]:
    path = artifact_root(project_root, name)
    if not path.exists():
        return artifact_result(name, path, "missing")
    if path.is_symlink():
        return artifact_result(name, path, "symlink-skipped")
    if not path.is_dir():
        raise ValueError(f"managed artifact root is not a directory: {path}")

    total_size, files, newest = walk_artifact(path)
    active = any((path / marker).exists() for marker in ACTIVE_MARKERS)
    active = active or now - newest <= ACTIVE_WINDOW_SECONDS
    age_days = max(0.0, (now - newest) / 86400)
    return {
        "name": name,
        "path": str(path),
        "status": "present",
        "size": total_size,
        "files": files,
        "newest": newest,
        "age_days": age_days,
        "active": active,
    }


def print_report(items: list[dict[str, object]], now: float) -> None:
    total_size = sum(int(item["size"]) for item in items)
    print("AGENT_ARTIFACTS_STATUS=PASS")
    print(f"AGENT_ARTIFACTS_TOTAL_BYTES={total_size}")
    print(f"AGENT_ARTIFACTS_TOTAL_HUMAN={human_size(total_size)}")
    for item in items:
        newest = item["newest"]
        age_days = item.get("age_days")
        age = "missing" if newest is None else f"{float(age_days):.1f}d"
        print(
            "ARTIFACT_ROOT "
            f"name={item['name']} status={item['status']} "
            f"size_bytes={item['size']} size={human_size(int(item['size']))} "
            f"files={item['files']} age={age} active={str(item['active']).lower()} "
            f"path={item['path']}"
        )


def cleanup(project_root: Path, items: list[dict[str, object]], older_than_days: float, dry_run: bool, confirm: bool) -> int:
    candidates = [
        item
        for item in items
        if item["status"] == "present"
        and not bool(item["active"])
        and float(item.get("age_days", 0)) >= older_than_days
    ]
    protected = [item for item in items if item["status"] == "present" and item not in candidates]
    report_cleanup(candidates, protected, older_than_days)

    if dry_run:
        print(f"AGENT_ARTIFACTS_CLEANUP_STATUS=DRY_RUN targets={len(candidates)}")
        return 0
    if not confirm:
        print(
            "ERROR: cleanup requires --confirm; use --clean --dry-run to preview targets.",
            file=sys.stderr,
        )
        return 2

    for item in candidates:
        if not remove_artifact(project_root, item):
            return 1
    print(f"AGENT_ARTIFACTS_CLEANUP_STATUS=PASS removed={len(candidates)}")
    return 0


def report_cleanup(candidates: list[dict[str, object]], protected: list[dict[str, object]], older_than_days: float) -> None:
    for item in candidates:
        print(
            "CLEANUP_TARGET "
            f"path={item['path']} size_bytes={item['size']} "
            f"reason=older-than-{older_than_days:g}-days"
        )
    for item in protected:
        print(
            "CLEANUP_PROTECTED "
            f"path={item['path']} active={str(item['active']).lower()} "
            f"age_days={float(item.get('age_days', 0)):.1f}"
        )


def remove_artifact(project_root: Path, item: dict[str, object]) -> bool:
    path = Path(str(item["path"]))
    if path.parent != project_root or path.name not in ALLOWED_ROOTS:
        print(f"ERROR: refusing unexpected cleanup path: {path}", file=sys.stderr)
        return False
    if path.is_symlink() or not path.is_dir():
        print(f"ERROR: refusing changed cleanup path: {path}", file=sys.stderr)
        return False
    shutil.rmtree(path)
    print(f"CLEANUP_REMOVED path={path}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Report managed build/agent artifact roots and safely clean inactive roots after explicit confirmation.",
        epilog="Examples:\n  make agent-artifacts-report\n  make agent-artifacts-dry-run\n  make agent-artifacts-clean ARTIFACT_CLEAN_CONFIRM=1",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Project root to inspect (default: repository root).",
    )
    parser.add_argument("--clean", action="store_true", help="Select eligible generated roots for cleanup.")
    parser.add_argument("--dry-run", action="store_true", help="Report cleanup targets without deleting them.")
    parser.add_argument("--confirm", action="store_true", help="Explicitly authorize deletion of eligible roots.")
    parser.add_argument(
        "--older-than-days",
        type=float,
        default=7.0,
        help="Minimum inactive age eligible for cleanup (default: 7 days).",
    )
    args = parser.parse_args()
    if args.older_than_days < 0:
        parser.error("--older-than-days must be non-negative")
    if args.dry_run and not args.clean:
        parser.error("--dry-run requires --clean")

    project_root = args.root.resolve()
    if not project_root.is_dir():
        print(f"ERROR: project root is not a directory: {project_root}", file=sys.stderr)
        return 1
    now = time.time()
    try:
        items = [inspect_root(project_root, name, now) for name in ALLOWED_ROOTS]
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print_report(items, now)
    if args.clean:
        return cleanup(project_root, items, args.older_than_days, args.dry_run, args.confirm)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
