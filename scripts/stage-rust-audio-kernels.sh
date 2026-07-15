#!/bin/bash
# =============================================================================
# stage-rust-audio-kernels.sh - Build and stage Rust audio kernels dylib
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/config/app_identity.sh
source "${SCRIPT_DIR}/config/app_identity.sh"

CONFIGURATION="Debug"
DERIVED_DATA_PATH="${PROJECT_DIR}/.xcode-build"
APP_NAME="${APP_PRODUCT_NAME}"
XPC_NAME="${XPC_PRODUCT_NAME}"
STAGE_MODE="${MA_RUST_AUDIO_KERNELS_BUILD:-auto}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --configuration|-c)
            CONFIGURATION="$2"
            shift 2
            ;;
        --derived-data)
            DERIVED_DATA_PATH="$2"
            shift 2
            ;;
        --app-product-name)
            APP_NAME="$2"
            shift 2
            ;;
        --xpc-product-name)
            XPC_NAME="$2"
            shift 2
            ;;
        --mode)
            STAGE_MODE="$2"
            shift 2
            ;;
        --help|-h)
            cat <<'EOF'
Usage: scripts/stage-rust-audio-kernels.sh [options]

Options:
  --configuration, -c <Debug|Release>  Build profile selector (default: Debug)
  --derived-data <path>                DerivedData root (default: .xcode-build)
  --app-product-name <name>            App bundle product name
  --xpc-product-name <name>            XPC bundle product name
  --mode <off|auto|on>                 Override stage mode

Environment:
  MA_RUST_AUDIO_KERNELS_BUILD=off|auto|on
    off  - skip build/staging
    auto - stage when cargo is available (default)
    on   - require cargo and fail if Rust build/staging fails
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

case "${STAGE_MODE}" in
    off|auto|on)
        ;;
    *)
        echo "Invalid Rust stage mode: ${STAGE_MODE}. Use off|auto|on." >&2
        exit 1
        ;;
esac

if [ "${STAGE_MODE}" = "off" ]; then
    echo "[rust-audio] staging disabled (mode=off)"
    exit 0
fi

if ! command -v cargo >/dev/null 2>&1; then
    if [ "${STAGE_MODE}" = "on" ]; then
        echo "[rust-audio] cargo not found and mode=on" >&2
        exit 1
    fi

    echo "[rust-audio] cargo not found; skipping staging (mode=auto)"
    exit 0
fi

CRATE_DIR="${PROJECT_DIR}/Native/AudioKernelsRust"
MANIFEST_PATH="${CRATE_DIR}/Cargo.toml"
LIB_NAME="libaudio_kernels_rust.dylib"

if [ ! -f "${MANIFEST_PATH}" ]; then
    if [ "${STAGE_MODE}" = "on" ]; then
        echo "[rust-audio] missing manifest at ${MANIFEST_PATH}" >&2
        exit 1
    fi

    echo "[rust-audio] manifest not found; skipping staging (mode=auto)"
    exit 0
fi

# Override ambient CARGO_TARGET_DIR so validate worktrees always stage from a
# deterministic crate-local target directory.
CARGO_TARGET_DIR="${CRATE_DIR}/target"
CARGO_ARGS=(build --manifest-path "${MANIFEST_PATH}" --target-dir "${CARGO_TARGET_DIR}")
CARGO_PROFILE_DIR="debug"
if [ "${CONFIGURATION}" = "Release" ]; then
    CARGO_ARGS+=(--release)
    CARGO_PROFILE_DIR="release"
fi

echo "[rust-audio] building ${LIB_NAME} (${CONFIGURATION})"
cargo "${CARGO_ARGS[@]}"

ARTIFACT_PATH="${CRATE_DIR}/target/${CARGO_PROFILE_DIR}/${LIB_NAME}"
if [ ! -f "${ARTIFACT_PATH}" ]; then
    echo "[rust-audio] expected artifact not found: ${ARTIFACT_PATH}" >&2
    exit 1
fi

PRODUCT_ROOT="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}"
TARGET_BUNDLES=(
    "${PRODUCT_ROOT}/${APP_NAME}.app"
    "${PRODUCT_ROOT}/${XPC_NAME}.xpc"
)

STAGED_COUNT=0
for bundle_path in "${TARGET_BUNDLES[@]}"; do
    if [ ! -d "${bundle_path}" ]; then
        continue
    fi

    framework_dir="${bundle_path}/Contents/Frameworks"
    mkdir -p "${framework_dir}"
    destination_path="${framework_dir}/${LIB_NAME}"

    cp "${ARTIFACT_PATH}" "${destination_path}"
    chmod 755 "${destination_path}"
    codesign --force --sign - "${destination_path}" >/dev/null 2>&1 || true

    STAGED_COUNT=$((STAGED_COUNT + 1))
    echo "[rust-audio] staged ${LIB_NAME} -> ${destination_path}"
done

if [ "${STAGED_COUNT}" -eq 0 ]; then
    message="[rust-audio] no app/xpc bundle found under ${PRODUCT_ROOT}"
    if [ "${STAGE_MODE}" = "on" ]; then
        echo "${message}" >&2
        exit 1
    fi

    echo "${message}; skipping (mode=auto)"
    exit 0
fi

echo "[rust-audio] staging completed (${STAGED_COUNT} bundle(s))"
