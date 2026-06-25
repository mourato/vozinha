#!/bin/bash
# =============================================================================
# ci-release-parity.sh - Shared release parity gate for local and CI workflows
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/config/app_identity.sh
source "${SCRIPT_DIR}/config/app_identity.sh"
# shellcheck source=scripts/config/release_signing.sh
source "${SCRIPT_DIR}/config/release_signing.sh"

MODE="local"
PHASE="build-archive"
DERIVED_DATA=""
ARCHIVE_PATH="build/${APP_PRODUCT_NAME}.xcarchive"
XCODE_VERSION="16.4"
XCODE_APP="/Applications/Xcode_16.4.app"
STRICT_XCODE_VERSION="${MA_CI_PARITY_STRICT_XCODE_VERSION:-0}"
DRY_RUN=""
RELEASE_TAG="${RELEASE_TAG:-}"
DOWNLOAD_URL_PREFIX=""
SPARKLE_TOOLS_DIR=""
SIGNING_MODE_OVERRIDE=""
CODE_SIGN_IDENTITY_OVERRIDE=""

PARITY_WARNINGS=()

usage() {
  cat <<'USAGE'
Usage: scripts/ci-release-parity.sh [options]

Options:
  --mode <local|ci>                      Execution mode (default: local)
  --phase <build-archive|package-appcast>
                                         Phase to run (default: build-archive)
  --derived-data <path>                  DerivedData path (default: mode-specific)
  --archive-path <path>                  Archive path (default: build/Prisma.xcarchive)
  --xcode-version <version>              Pinned Xcode version check (default: 16.4)
  --xcode-app <path>                     Pinned Xcode app path (default: /Applications/Xcode_16.4.app)
  --strict-xcode-version <0|1>           Fail when version mismatches (default: 0 or MA_CI_PARITY_STRICT_XCODE_VERSION)
  --dry-run <0|1>                        Dry-run behavior (default: local=1, ci=0)
  --release-tag <tag>                    Release tag used to generate appcast URL prefix
  --download-url-prefix <url>            Explicit appcast download URL prefix
  --sparkle-tools-dir <path>             Directory containing Sparkle tools (generate_appcast)
  --signing-mode <adhoc|self-signed>     Override MA_RELEASE_SIGNING_MODE
  --code-sign-identity <name>            Override MA_RELEASE_CODE_SIGN_IDENTITY
  --help                                 Show this help

Examples:
  scripts/ci-release-parity.sh --mode local --phase build-archive --dry-run 1
  scripts/ci-release-parity.sh --mode ci --phase build-archive --dry-run 0
  scripts/ci-release-parity.sh --mode ci --phase package-appcast --dry-run 0 \
    --archive-path /tmp/sparkle-build-outputs/build/Prisma.xcarchive \
    --sparkle-tools-dir /tmp/sparkle-build-outputs/build/tools/sparkle
USAGE
}

log_info() { printf '[ci-release-parity] %s\n' "$*"; }
log_warn() { printf '[ci-release-parity][warn] %s\n' "$*"; }
log_error() { printf '[ci-release-parity][error] %s\n' "$*" >&2; }

append_warning() {
  PARITY_WARNINGS+=("$1")
  log_warn "$1"
}

xcode_signing_args() {
  printf '%s\n' \
    "CODE_SIGN_IDENTITY=-" \
    "CODE_SIGNING_REQUIRED=NO" \
    "CODE_SIGNING_ALLOWED=NO"
}

write_github_env() {
  local key="$1"
  local value="$2"
  if [ -n "${GITHUB_ENV:-}" ]; then
    printf '%s=%s\n' "${key}" "${value}" >> "${GITHUB_ENV}"
  fi
}

emit_result() {
  local status="$1"
  local summary="$2"

  echo "PARITY_MODE=${MODE}"
  echo "PARITY_PHASE=${PHASE}"
  echo "PARITY_STATUS=${status}"
  echo "PARITY_SUMMARY=${summary}"
  if [ "${#PARITY_WARNINGS[@]}" -gt 0 ]; then
    local joined=""
    local item
    for item in "${PARITY_WARNINGS[@]}"; do
      if [ -n "${joined}" ]; then
        joined+="; "
      fi
      joined+="${item}"
    done
    echo "PARITY_WARNINGS=${joined}"
  else
    echo "PARITY_WARNINGS="
  fi
}

abs_path_from_root() {
  local input_path="$1"
  if [[ "${input_path}" = /* ]]; then
    printf '%s' "${input_path}"
  else
    printf '%s' "${PROJECT_ROOT}/${input_path}"
  fi
}

xcode_version_check() {
  local current_version

  if [ -d "${XCODE_APP}" ]; then
    if [ "${MODE}" = "ci" ]; then
      log_info "Selecting pinned Xcode: ${XCODE_APP}"
      sudo xcode-select -s "${XCODE_APP}/Contents/Developer"
    else
      log_info "Pinned Xcode app found at ${XCODE_APP}."
    fi
  else
    if [ "${MODE}" = "ci" ]; then
      log_error "Pinned Xcode app not found at ${XCODE_APP}."
      return 1
    fi
    append_warning "Pinned Xcode app not found at ${XCODE_APP}; running with current selection."
  fi

  current_version="$(xcodebuild -version | awk 'NR==1 { print $2 }')"
  log_info "Detected Xcode version: ${current_version}"
  if [ "${current_version}" != "${XCODE_VERSION}" ]; then
    if [ "${STRICT_XCODE_VERSION}" = "1" ]; then
      log_error "Expected Xcode ${XCODE_VERSION}, got ${current_version}."
      return 1
    fi
    append_warning "Expected Xcode ${XCODE_VERSION}, got ${current_version} (continuing due to strict-xcode-version=0)."
  fi

  xcodebuild -version
}

resolve_spm_dependencies() {
  local resolve_log="$1"
  log_info "Resolving SPM dependencies"
  xcodebuild -resolvePackageDependencies \
    -project "${PROJECT_ROOT}/${XCODEPROJ_NAME}" \
    -scheme "${APP_SCHEME}" \
    -derivedDataPath "${DERIVED_DATA}" \
    2>&1 | tee "${resolve_log}"
}

apply_dependency_patches() {
  local fluidaudio_checkout="${DERIVED_DATA}/SourcePackages/checkouts/FluidAudio"

  if [ ! -d "${fluidaudio_checkout}" ]; then
    log_info "FluidAudio checkout not found at ${fluidaudio_checkout}; skipping dependency patches"
    return 0
  fi

  log_info "Applying FluidAudio compatibility patches"
  "${SCRIPT_DIR}/apply-fluidaudio-patches.sh" "${fluidaudio_checkout}"
}

locate_and_copy_sparkle_tools() {
  local sparkle_tool
  local sparkle_bin_dir
  local tool_destination="${PROJECT_ROOT}/build/tools/sparkle"

  sparkle_tool="$(find "${DERIVED_DATA}/SourcePackages" -type f -name generate_appcast | head -n 1 || true)"
  if [ -z "${sparkle_tool}" ] || [ ! -f "${sparkle_tool}" ]; then
    log_error "Could not locate Sparkle generate_appcast under ${DERIVED_DATA}/SourcePackages."
    return 1
  fi

  sparkle_bin_dir="$(dirname "${sparkle_tool}")"
  mkdir -p "${tool_destination}"
  cp -R "${sparkle_bin_dir}/." "${tool_destination}/"
  chmod +x "${tool_destination}/generate_appcast"
  log_info "Sparkle tools copied to ${tool_destination}"
}

run_build_archive_phase() {
  local build_log="${PROJECT_ROOT}/build/ci-release-build.log"
  local archive_log="${PROJECT_ROOT}/build/ci-release-archive.log"
  local -a signing_args=()
  while IFS= read -r signing_arg; do
    signing_args+=("${signing_arg}")
  done < <(xcode_signing_args)

  mkdir -p "${PROJECT_ROOT}/build"

  xcode_version_check
  resolve_spm_dependencies "${PROJECT_ROOT}/build/ci-release-resolve-packages.log"
  apply_dependency_patches
  locate_and_copy_sparkle_tools

  log_info "Running release build gate"
  log_info "Release signing mode: $(ma_release_signing_description)"
  if ! xcodebuild build \
    -project "${PROJECT_ROOT}/${XCODEPROJ_NAME}" \
    -scheme "${APP_SCHEME}" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "${DERIVED_DATA}" \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES \
    EXCLUDED_ARCHS=x86_64 \
    "${signing_args[@]}" \
    2>&1 | tee "${build_log}"; then
    emit_result "FAIL" "Release build gate failed"
    return 1
  fi

  log_info "Archiving app"
  if ! xcodebuild archive \
    -project "${PROJECT_ROOT}/${XCODEPROJ_NAME}" \
    -scheme "${APP_SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    -derivedDataPath "${DERIVED_DATA}" \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES \
    EXCLUDED_ARCHS=x86_64 \
    "${signing_args[@]}" \
    2>&1 | tee "${archive_log}"; then
    emit_result "FAIL" "Archive gate failed"
    return 1
  fi

  emit_result "PASS" "Release build/archive parity gate passed"
}

resolve_archive_and_bundle() {
  local resolved_archive="${ARCHIVE_PATH}"

  if [ ! -d "${resolved_archive}" ]; then
    local archive_basename
    archive_basename="$(basename "${ARCHIVE_PATH}")"
    resolved_archive="$(find "$(dirname "${ARCHIVE_PATH}")" -type d -name "${archive_basename}" 2>/dev/null | head -n 1 || true)"
  fi

  if [ -z "${resolved_archive}" ] || [ ! -d "${resolved_archive}" ]; then
    log_error "Archive not found (expected ${ARCHIVE_PATH})."
    return 1
  fi

  local app_bundle
  app_bundle="$(find "${resolved_archive}" -type d -path '*/Products/Applications/*.app' | head -n 1 || true)"
  if [ -z "${app_bundle}" ] || [ ! -d "${app_bundle}" ]; then
    log_error "App bundle not found inside archive ${resolved_archive}."
    return 1
  fi

  echo "${resolved_archive}|${app_bundle}"
}

prepare_bundle_for_packaging() {
  local app_bundle="$1"

  if [ "${MA_RELEASE_SIGNING_MODE}" = "self-signed" ]; then
    log_info "Applying self-signed code signature to app bundle"
    if ! /usr/bin/codesign --force --deep --keychain "${HOME}/Library/Keychains/login.keychain-db" --timestamp=none --sign "${MA_RELEASE_CODE_SIGN_IDENTITY}" "${app_bundle}"; then
      log_error "Self-signed bundle signing failed."
      return 1
    fi

    log_info "Validating self-signed app bundle"
    if ! /usr/bin/codesign --verify --deep --strict --verbose=2 "${app_bundle}"; then
      log_error "Self-signed bundle verification failed."
      return 1
    fi
    if /usr/bin/codesign --display --verbose=4 "${app_bundle}" 2>&1 | grep -q "Signature=adhoc"; then
      log_error "Bundle is ad-hoc signed but self-signed mode was requested."
      return 1
    fi
    return 0
  fi

  if /usr/bin/codesign --display --verbose=0 "${app_bundle}" >/dev/null 2>&1; then
    log_info "Removing existing app code signature for unsigned distribution mode"
    /usr/bin/codesign --remove-signature "${app_bundle}" || true
  else
    log_info "App bundle is already unsigned"
  fi

  if /usr/bin/codesign --display --verbose=0 "${app_bundle}" >/dev/null 2>&1; then
    append_warning "App bundle still appears signed after signature removal attempt."
  fi
}

locate_generate_appcast_tool() {
  local tool_path=""

  if [ -n "${SPARKLE_TOOLS_DIR}" ] && [ -f "${SPARKLE_TOOLS_DIR}/generate_appcast" ]; then
    tool_path="${SPARKLE_TOOLS_DIR}/generate_appcast"
  elif [ -x "${PROJECT_ROOT}/build/tools/sparkle/generate_appcast" ]; then
    tool_path="${PROJECT_ROOT}/build/tools/sparkle/generate_appcast"
  elif [ -f "/tmp/sparkle-build-outputs/tools/sparkle/generate_appcast" ]; then
    tool_path="/tmp/sparkle-build-outputs/tools/sparkle/generate_appcast"
  elif [ -x "/tmp/sparkle-build-outputs/build/tools/sparkle/generate_appcast" ]; then
    tool_path="/tmp/sparkle-build-outputs/build/tools/sparkle/generate_appcast"
  else
    tool_path="$(find "${DERIVED_DATA}/SourcePackages" -type f -name generate_appcast 2>/dev/null | head -n 1 || true)"
    if [ -z "${tool_path}" ]; then
      tool_path="$(find /tmp/sparkle-build-outputs -type f -name generate_appcast 2>/dev/null | head -n 1 || true)"
    fi
  fi

  if [ -z "${tool_path}" ] || [ ! -f "${tool_path}" ]; then
    echo ""
    return 1
  fi

  chmod +x "${tool_path}"
  echo "${tool_path}"
}

resolve_download_url_prefix() {
  if [ -n "${DOWNLOAD_URL_PREFIX}" ]; then
    printf '%s' "${DOWNLOAD_URL_PREFIX}"
    return 0
  fi

  if [ -n "${RELEASE_TAG}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
    printf '%s' "https://github.com/${GITHUB_REPOSITORY}/releases/download/${RELEASE_TAG}"
    return 0
  fi

  echo ""
  return 1
}

normalize_release_tag_version() {
  local raw_tag="$1"
  printf '%s' "${raw_tag#v}"
}

validate_release_tag_matches_bundle_version() {
  local app_bundle="$1"
  local info_plist="${app_bundle}/Contents/Info.plist"

  if [ -z "${RELEASE_TAG}" ]; then
    return 0
  fi

  if [ ! -f "${info_plist}" ]; then
    log_error "Bundle Info.plist not found at ${info_plist}."
    return 1
  fi

  local expected_short_version
  expected_short_version="$(normalize_release_tag_version "${RELEASE_TAG}")"
  if [ -z "${expected_short_version}" ]; then
    log_error "Could not derive expected short version from release tag '${RELEASE_TAG}'."
    return 1
  fi

  local actual_short_version
  actual_short_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${info_plist}" 2>/dev/null || true)"
  if [ -z "${actual_short_version}" ]; then
    log_error "Missing CFBundleShortVersionString in ${info_plist}."
    return 1
  fi

  if [ "${actual_short_version}" != "${expected_short_version}" ]; then
    log_error "Release tag ${RELEASE_TAG} expects CFBundleShortVersionString=${expected_short_version}, got ${actual_short_version}."
    return 1
  fi

  log_info "Validated bundle short version (${actual_short_version}) matches release tag ${RELEASE_TAG}."
}

generate_appcast() {
  local appcast_tool="$1"
  local appcast_dir="$2"
  local appcast_log="$3"

  local key_path="/tmp/sparkle_ed25519.pem"
  local key_source="env"
  local key_provided=1
  local keychain_account="${SPARKLE_KEYCHAIN_ACCOUNT:-ed25519}"
  local -a appcast_key_args=()
  local skip_reason=""

  if [ -z "${SPARKLE_PRIVATE_KEY_B64:-}" ] && [ -z "${SPARKLE_PRIVATE_KEY:-}" ]; then
    key_provided=0
    key_source="keychain"
  fi

  if [ "${key_provided}" -eq 0 ] && [ "${MODE}" = "ci" ]; then
    log_error "Missing Sparkle private key secret (SPARKLE_PRIVATE_KEY_B64 or SPARKLE_PRIVATE_KEY) in CI mode."
    return 1
  fi

  if [ "${key_provided}" -eq 0 ] && [ "${DRY_RUN}" = "1" ]; then
    skip_reason="missing_sparkle_key"
    append_warning "Skipping appcast generation in dry-run because Sparkle private key is missing."
    write_github_env "APPCAST_SKIPPED_REASON" "${skip_reason}"
    return 0
  fi

  if [ "${key_provided}" -eq 0 ]; then
    append_warning "Sparkle private key env not provided; trying Keychain account '${keychain_account}'."
    appcast_key_args=(--account "${keychain_account}")
  else
    appcast_key_args=(--ed-key-file "${key_path}")
  fi

  local url_prefix
  url_prefix="$(resolve_download_url_prefix || true)"
  if [ -z "${url_prefix}" ]; then
    if [ "${DRY_RUN}" = "1" ]; then
      skip_reason="missing_download_url_prefix"
      append_warning "Skipping appcast generation in dry-run because download URL prefix could not be resolved."
      write_github_env "APPCAST_SKIPPED_REASON" "${skip_reason}"
      return 0
    fi
    log_error "Download URL prefix is required for appcast generation (set --download-url-prefix or RELEASE_TAG + GITHUB_REPOSITORY)."
    return 1
  fi

  decode_base64() {
    if base64 --help 2>&1 | grep -q -- '--decode'; then
      base64 --decode
    else
      base64 -D
    fi
  }

  if [ "${key_source}" = "env" ]; then
    if [ -n "${SPARKLE_PRIVATE_KEY_B64:-}" ]; then
      printf '%s' "${SPARKLE_PRIVATE_KEY_B64}" | decode_base64 > "${key_path}"
    else
      printf '%s' "${SPARKLE_PRIVATE_KEY}" > "${key_path}"
    fi
    chmod 600 "${key_path}"
  fi

  if ! "${appcast_tool}" \
    "${appcast_key_args[@]}" \
    --download-url-prefix "${url_prefix}/" \
    "${appcast_dir}" 2>&1 | tee "${appcast_log}"; then
    if [ "${key_source}" = "env" ]; then
      rm -f "${key_path}"
    fi

    if [ "${DRY_RUN}" = "1" ] && grep -Eq "failed Apple Code Signing checks|No usable archives found" "${appcast_log}"; then
      skip_reason="unsigned_app"
      append_warning "Skipping appcast generation in dry-run because archived app is not Apple-signed yet."
      write_github_env "APPCAST_SKIPPED_REASON" "${skip_reason}"
      return 0
    fi

    log_error "generate_appcast failed."
    return 1
  fi

  if [ "${key_source}" = "env" ]; then
    rm -f "${key_path}"
  fi

  if grep -Eq "SUPublicEDKey in the app .* does not match key EdDSA" "${appcast_log}"; then
    log_error "Sparkle key mismatch: SUPublicEDKey in app Info.plist does not match the provided Sparkle private key."
    log_error "Regenerate Sparkle keys or update SUPublicEDKey to match the private key used in CI secrets."
    return 1
  fi

  local appcast_file="${appcast_dir}/appcast.xml"
  if [ ! -f "${appcast_file}" ]; then
    log_error "generate_appcast succeeded but appcast.xml was not found at ${appcast_file}."
    return 1
  fi

  if ! grep -q 'sparkle:edSignature=' "${appcast_file}"; then
    log_error "Generated appcast.xml is missing sparkle:edSignature enclosure attributes."
    return 1
  fi

  return 0
}

run_package_appcast_phase() {
  local resolved
  local archive_root
  local app_bundle
  local appcast_tool

  resolved="$(resolve_archive_and_bundle)"
  archive_root="${resolved%%|*}"
  app_bundle="${resolved##*|}"

  log_info "Using archive: ${archive_root}"
  log_info "Using app bundle: ${app_bundle}"

  if ! validate_release_tag_matches_bundle_version "${app_bundle}"; then
    emit_result "FAIL" "Package/appcast failed"
    return 1
  fi

  if ! prepare_bundle_for_packaging "${app_bundle}"; then
    emit_result "FAIL" "Package/appcast failed"
    return 1
  fi

  mkdir -p "${PROJECT_ROOT}/build" "${PROJECT_ROOT}/build/appcast"
  ditto -c -k --sequesterRsrc --keepParent "${app_bundle}" "${PROJECT_ROOT}/build/${APP_PRODUCT_NAME}.zip"
  cp "${PROJECT_ROOT}/build/${APP_PRODUCT_NAME}.zip" "${PROJECT_ROOT}/build/appcast/"

  appcast_tool="$(locate_generate_appcast_tool || true)"
  if [ -z "${appcast_tool}" ]; then
    if [ "${DRY_RUN}" = "1" ]; then
      append_warning "Skipping appcast generation in dry-run because generate_appcast tool could not be found."
      write_github_env "APPCAST_SKIPPED_REASON" "missing_generate_appcast"
      emit_result "WARN" "Package/appcast completed with reduced confidence"
      return 0
    fi
    log_error "Sparkle generate_appcast binary not found."
    emit_result "FAIL" "Package/appcast failed"
    return 1
  fi

  log_info "Using generate_appcast tool: ${appcast_tool}"
  if ! generate_appcast "${appcast_tool}" "${PROJECT_ROOT}/build/appcast" "${PROJECT_ROOT}/build/ci-release-appcast.log"; then
    emit_result "FAIL" "Package/appcast failed"
    return 1
  fi

  if [ "${#PARITY_WARNINGS[@]}" -gt 0 ]; then
    emit_result "WARN" "Package/appcast completed with reduced confidence"
  else
    emit_result "PASS" "Package/appcast parity gate passed"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --phase)
      PHASE="$2"
      shift 2
      ;;
    --derived-data)
      DERIVED_DATA="$2"
      shift 2
      ;;
    --archive-path)
      ARCHIVE_PATH="$2"
      shift 2
      ;;
    --xcode-version)
      XCODE_VERSION="$2"
      shift 2
      ;;
    --xcode-app)
      XCODE_APP="$2"
      shift 2
      ;;
    --strict-xcode-version)
      STRICT_XCODE_VERSION="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="$2"
      shift 2
      ;;
    --release-tag)
      RELEASE_TAG="$2"
      shift 2
      ;;
    --download-url-prefix)
      DOWNLOAD_URL_PREFIX="$2"
      shift 2
      ;;
    --sparkle-tools-dir)
      SPARKLE_TOOLS_DIR="$2"
      shift 2
      ;;
    --signing-mode)
      SIGNING_MODE_OVERRIDE="$2"
      shift 2
      ;;
    --code-sign-identity)
      CODE_SIGN_IDENTITY_OVERRIDE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [ -n "${SIGNING_MODE_OVERRIDE}" ]; then
  MA_RELEASE_SIGNING_MODE="${SIGNING_MODE_OVERRIDE}"
fi
if [ -n "${CODE_SIGN_IDENTITY_OVERRIDE}" ]; then
  MA_RELEASE_CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY_OVERRIDE}"
fi

if ! ma_validate_release_signing_mode; then
  exit 1
fi
if ! ma_require_self_signed_identity; then
  exit 1
fi

case "${MODE}" in
  local|ci)
    ;;
  *)
    log_error "Invalid mode: ${MODE}. Use local or ci."
    exit 1
    ;;
esac

case "${PHASE}" in
  build-archive|package-appcast)
    ;;
  *)
    log_error "Invalid phase: ${PHASE}. Use build-archive or package-appcast."
    exit 1
    ;;
esac

case "${STRICT_XCODE_VERSION}" in
  0|1)
    ;;
  *)
    log_error "Invalid --strict-xcode-version value: ${STRICT_XCODE_VERSION}. Use 0 or 1."
    exit 1
    ;;
esac

if [ -z "${DRY_RUN}" ]; then
  if [ "${MODE}" = "local" ]; then
    DRY_RUN="1"
  else
    DRY_RUN="0"
  fi
fi

case "${DRY_RUN}" in
  0|1)
    ;;
  *)
    log_error "Invalid --dry-run value: ${DRY_RUN}. Use 0 or 1."
    exit 1
    ;;
esac

if [ -z "${DERIVED_DATA}" ]; then
  if [ "${MODE}" = "ci" ]; then
    DERIVED_DATA="/tmp/DerivedData"
  else
    DERIVED_DATA="${PROJECT_ROOT}/.xcode-build-ci-parity"
  fi
fi

ARCHIVE_PATH="$(abs_path_from_root "${ARCHIVE_PATH}")"
if [ -n "${SPARKLE_TOOLS_DIR}" ]; then
  SPARKLE_TOOLS_DIR="$(abs_path_from_root "${SPARKLE_TOOLS_DIR}")"
fi

log_info "mode=${MODE} phase=${PHASE} dry_run=${DRY_RUN}"
log_info "derived_data=${DERIVED_DATA}"
log_info "archive_path=${ARCHIVE_PATH}"
log_info "release_signing=$(ma_release_signing_description)"

if [ "${PHASE}" = "build-archive" ]; then
  run_build_archive_phase
  exit $?
fi

run_package_appcast_phase
