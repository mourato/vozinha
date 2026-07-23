#!/bin/bash
# build-and-run.sh - Build Debug or install the signed Release app transactionally.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${PROJECT_ROOT}/scripts/config/app_identity.sh"
CONFIGURATION=""; CLEAN=0; NO_INTERACTIVE=0; FORCE_TERMINATE=0; SKIP_LAUNCH=0
APPLICATIONS_DIR="${VOZINHA_APPLICATIONS_DIR:-/Applications}"
SHUTDOWN_TIMEOUT="${VOZINHA_SHUTDOWN_TIMEOUT_SECONDS:-15}"; STARTUP_TIMEOUT="${VOZINHA_STARTUP_TIMEOUT_SECONDS:-15}"
usage() { cat <<'USAGE'
Usage: scripts/build-and-run.sh [options]

Build Debug for local iteration or build/sign/install Release into the exact Vozinha.app target.
Options:
  --configuration Debug|Release  Select a deterministic build mode.
  --clean                       Remove this repository's .xcode-build first.
  --no-interactive              Never read stdin; requires --configuration.
  --force-terminate             Allow exact-process TERM fallback after graceful timeout.
  --skip-launch                 Verify Release installation without relaunching it.
  --applications-dir PATH       Test-only applications root; defaults to /Applications.
  --help                        Show this help without building.
USAGE
}
fail() { echo "Error: $*" >&2; exit 1; }
require_positive_integer() { [[ "$1" =~ ^[1-9][0-9]*$ ]] || fail "timeout must be a positive integer: $1"; }
validate_applications_dir() {
    local root="$1" resolved
    [ -d "$root" ] || fail "applications directory does not exist: $root"
    resolved="$(cd "$root" && pwd -P)"
    [ "$resolved" != "/" ] || fail "refusing the filesystem root as an installation target"
    [ "$resolved" != "${HOME:-}" ] || fail "refusing the home directory as an installation target"
    printf '%s\n' "$resolved"
}
bundle_path() { printf '%s/%s.app\n' "$1" "$APP_PRODUCT_NAME"; }
validate_bundle() {
    local bundle="$1" identifier
    [ -d "$bundle" ] || return 1
    [ "$(basename "$bundle")" = "${APP_PRODUCT_NAME}.app" ] || return 1
    [ -f "$bundle/Contents/Info.plist" ] || return 1
    identifier="$(plutil -extract CFBundleIdentifier raw -o - "$bundle/Contents/Info.plist" 2>/dev/null || true)"
    [ -n "$identifier" ] || return 1
    [ -f "$bundle/Contents/MacOS/${APP_PRODUCT_NAME}" ] || return 1
    codesign --verify --deep --strict "$bundle" >/dev/null 2>&1 || return 1
}
running_pids() { pgrep -x "$APP_PRODUCT_NAME" 2>/dev/null || true; }
wait_for_exit() {
    local deadline=$((SECONDS + SHUTDOWN_TIMEOUT))
    while [ "$SECONDS" -lt "$deadline" ]; do [ -z "$(running_pids)" ] && return 0; sleep 1; done
    return 1
}
stop_running_app() {
    local pids; pids="$(running_pids)"; [ -z "$pids" ] && return 0
    echo "Requesting graceful shutdown via vozinha://internal/quit..."
    open "vozinha://internal/quit" >/dev/null 2>&1 || true
    wait_for_exit && return 0
    [ "$FORCE_TERMINATE" -eq 1 ] || fail "Vozinha did not terminate gracefully within ${SHUTDOWN_TIMEOUT}s; rerun with --force-terminate only if intended"
    echo "Graceful shutdown timed out; using explicit TERM fallback for PID(s): ${pids}" >&2
    while IFS= read -r pid; do [ -n "$pid" ] && kill -TERM "$pid" 2>/dev/null || true; done <<< "$pids"
    wait_for_exit || fail "Vozinha remained running after explicit force fallback"
}
rollback() {
    local target="$1" backup="$2"; rm -rf "$target"
    if [ -d "$backup" ]; then mv "$backup" "$target"; echo "Rollback restored ${target}" >&2; else echo "Rollback had no previous bundle to restore" >&2; fi
}
install_release() {
    local candidate="$PROJECT_ROOT/dist/${APP_PRODUCT_NAME}.app" target stage backup had_backup=0
    target="$(bundle_path "$APPLICATIONS_DIR")"; stage="${target}.stage.$$"; backup="${target}.backup.$$"
    validate_bundle "$candidate" || fail "Release candidate is not installable"
    case "$target" in "${APPLICATIONS_DIR}/${APP_PRODUCT_NAME}.app") ;; *) fail "Refusing unexpected installation target: $target" ;; esac
    stop_running_app; rm -rf "$stage"
    ditto "$candidate" "$stage" || { rm -rf "$stage"; fail "Could not stage Release candidate"; }
    if [ -e "$target" ]; then mv "$target" "$backup" || { rm -rf "$stage"; fail "Could not create installation backup"; }; had_backup=1; fi
    if ! mv "$stage" "$target" || ! validate_bundle "$target"; then rm -rf "$stage"; [ "$had_backup" -eq 1 ] && mv "$backup" "$target"; fail "Release installation failed; rollback was attempted"; fi
    if [ "$SKIP_LAUNCH" -eq 0 ]; then
        open "$target" >/dev/null 2>&1 || { rollback "$target" "$backup"; fail "Release app failed to launch"; }
        local deadline=$((SECONDS + STARTUP_TIMEOUT)); while [ "$SECONDS" -lt "$deadline" ] && [ -z "$(running_pids)" ]; do sleep 1; done
        [ -n "$(running_pids)" ] || { rollback "$target" "$backup"; fail "Release app did not remain alive after launch"; }
    fi
    rm -rf "$backup"; echo "Installed and validated ${target}"
}
run_selected() {
    [ "$CLEAN" -eq 1 ] && rm -rf "$PROJECT_ROOT/.xcode-build"
    if [ "$CONFIGURATION" = "Debug" ]; then
        "$PROJECT_ROOT/scripts/run-build.sh" --configuration Debug
        open "$PROJECT_ROOT/.xcode-build/Build/Products/Debug/${APP_PRODUCT_NAME}.app"
    else
        MA_RELEASE_SIGNING_MODE="${MA_RELEASE_SIGNING_MODE:-adhoc}" "$PROJECT_ROOT/scripts/build-release.sh" --no-interactive
        install_release
    fi
}
while [[ $# -gt 0 ]]; do
    case "$1" in
        --configuration) [ $# -ge 2 ] || fail "--configuration requires Debug or Release"; CONFIGURATION="$2"; shift 2 ;;
        --clean) CLEAN=1; shift ;;
        --no-interactive) NO_INTERACTIVE=1; shift ;;
        --force-terminate) FORCE_TERMINATE=1; shift ;;
        --skip-launch) SKIP_LAUNCH=1; shift ;;
        --applications-dir) [ $# -ge 2 ] || fail "--applications-dir requires a path"; APPLICATIONS_DIR="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) fail "unknown option: $1" ;;
    esac
done
require_positive_integer "$SHUTDOWN_TIMEOUT"; require_positive_integer "$STARTUP_TIMEOUT"
if [ "$NO_INTERACTIVE" -eq 1 ]; then
    [ -n "$CONFIGURATION" ] || fail "--no-interactive requires --configuration Debug|Release"
elif [ -z "$CONFIGURATION" ]; then
    [ -t 0 ] && [ -t 1 ] || fail "interactive selection requires a TTY; pass --no-interactive --configuration ..."
    printf '%s\n' '1) Debug' '2) Release' '3) Exit'; read -r -p "Choose [1/2/3]: " choice
    case "$choice" in 1) CONFIGURATION=Debug ;; 2) CONFIGURATION=Release ;; *) exit 0 ;; esac
fi
case "$CONFIGURATION" in Debug) ;; Release) APPLICATIONS_DIR="$(validate_applications_dir "$APPLICATIONS_DIR")" ;; *) fail "configuration must be Debug or Release" ;; esac
run_selected
