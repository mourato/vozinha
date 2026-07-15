#!/bin/bash

set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/prisma-rust-audio-staging-test.XXXXXX")"
trap 'rm -rf "${TMP_ROOT}"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

if ! command -v cargo >/dev/null 2>&1; then
    echo "RUST_AUDIO_STAGING_TEST_STATUS=SKIP (cargo unavailable)"
    exit 0
fi

if [ ! -f "${SCRIPT_ROOT}/Native/AudioKernelsRust/Cargo.toml" ]; then
    echo "RUST_AUDIO_STAGING_TEST_STATUS=SKIP (Rust crate unavailable)"
    exit 0
fi

fake_target_dir="${TMP_ROOT}/redirected-cargo-target"
mkdir -p "${fake_target_dir}"

output="$(
    cd "${SCRIPT_ROOT}" && \
        CARGO_TARGET_DIR="${fake_target_dir}" \
        ./scripts/stage-rust-audio-kernels.sh --mode on --configuration Debug 2>&1
)" || fail "staging failed with redirected CARGO_TARGET_DIR: ${output}"

if printf '%s\n' "${output}" | grep -Fq '[rust-audio] expected artifact not found'; then
    fail "staging looked in redirected target dir instead of crate-local target"
fi

artifact="${SCRIPT_ROOT}/Native/AudioKernelsRust/target/debug/libaudio_kernels_rust.dylib"
[ -f "${artifact}" ] || fail "expected dylib at ${artifact}"

if [ -f "${fake_target_dir}/debug/libaudio_kernels_rust.dylib" ]; then
    fail "dylib was built under redirected CARGO_TARGET_DIR"
fi

echo "RUST_AUDIO_STAGING_TEST_STATUS=PASS"
