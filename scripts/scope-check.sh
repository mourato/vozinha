#!/bin/bash
# =============================================================================
# scope-check.sh - Scoped validation driven by changed files
# =============================================================================

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_MAPPING_CONFIG="${SCRIPT_DIR}/config/test-target-mapping.conf"

# shellcheck source=scripts/lib/agent-output.sh
source "${SCRIPT_DIR}/lib/agent-output.sh"

AGENT_MODE=0
BASE_REF=""
MAX_TARGETED=8
RUN_BUILD=1
DRY_RUN=0
FORCE_FULL=0

START_TIME="$(date +%s)"
LOG_PATH="/tmp/ma-scope-check-$$.log"
RESULT_PATH=""

TMP_FILES=()

if ma_agent_mode_enabled; then
    AGENT_MODE=1
fi

usage() {
    cat <<'USAGE'
Usage: ./scripts/scope-check.sh [options]

Options:
  --base REF            Compare against git ref in addition to local working tree
  --max-targeted N      Maximum mapped targeted tests before escalating (default: 8)
  --no-build            Skip narrow build step before targeted tests
  --dry-run             Print decisions and commands without executing checks
  --force-full          Always run full gate (`make build-test`)
  --agent               Emit compact AGENT_* result lines
  --help, -h            Show this help

Examples:
  ./scripts/scope-check.sh
  ./scripts/scope-check.sh --dry-run
  ./scripts/scope-check.sh --base main --max-targeted 10
USAGE
}

new_tmp_file() {
    local tmp
    tmp="$(mktemp /tmp/ma-scope-check.XXXXXX)"
    TMP_FILES+=("${tmp}")
    printf '%s\n' "${tmp}"
}

cleanup_tmp_files() {
    local tmp
    for tmp in "${TMP_FILES[@]+"${TMP_FILES[@]}"}"; do
        if [ -f "${tmp}" ]; then
            rm -f "${tmp}"
        fi
    done
}

append_line_once() {
    local value="$1"
    local file_path="$2"
    if [ -z "${value}" ]; then
        return
    fi
    if [ ! -f "${file_path}" ]; then
        return
    fi
    if ! grep -Fxq "${value}" "${file_path}" 2>/dev/null; then
        echo "${value}" >> "${file_path}"
    fi
}

lowercase() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

run_cmd() {
    local cmd="$1"
    if [ "${DRY_RUN}" -eq 1 ]; then
        echo "[dry-run] ${cmd}"
        return 0
    fi
    echo "→ ${cmd}"
    eval "${cmd}"
}

collect_changed_files() {
    local changed_file_list="$1"
    : > "${changed_file_list}"

    if [ -n "${BASE_REF}" ]; then
        if ! git rev-parse --verify --quiet "${BASE_REF}" >/dev/null; then
            echo "Error: base ref '${BASE_REF}' does not exist."
            return 1
        fi
        git diff --name-only --diff-filter=ACMR "${BASE_REF}"...HEAD >> "${changed_file_list}"
    fi

    git diff --name-only --diff-filter=ACMR HEAD >> "${changed_file_list}"
    git ls-files --others --exclude-standard >> "${changed_file_list}"

    sed '/^$/d' "${changed_file_list}" | sort -u > "${changed_file_list}.sorted"
    mv "${changed_file_list}.sorted" "${changed_file_list}"
    return 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --base)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --base requires a ref value."
                    exit 1
                fi
                BASE_REF="$2"
                shift 2
                ;;
            --max-targeted)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --max-targeted requires a numeric value."
                    exit 1
                fi
                MAX_TARGETED="$2"
                shift 2
                ;;
            --no-build)
                RUN_BUILD=0
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --force-full)
                FORCE_FULL=1
                shift
                ;;
            --agent)
                AGENT_MODE=1
                MA_AGENT_MODE=1
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    if ! [[ "${MAX_TARGETED}" =~ ^[0-9]+$ ]] || [ "${MAX_TARGETED}" -le 0 ]; then
        echo "Error: --max-targeted must be a positive integer."
        exit 1
    fi
}

prepare_agent_logging() {
    if [ "${AGENT_MODE}" -eq 0 ]; then
        return
    fi
    local log_dir
    log_dir="$(ma_agent_prepare_log_dir)"
    LOG_PATH="${log_dir}/scope-check.log"
    RESULT_PATH="${log_dir}/scope-check.result.json"
    : > "${LOG_PATH}"
    exec > >(tee "${LOG_PATH}") 2>&1
}

should_treat_as_infra_trigger() {
    local file_path="$1"
    case "${file_path}" in
        Makefile|Package.swift|scripts/*|.github/workflows/*|*.xcodeproj/*|*.xcworkspace/*|*.pbxproj)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

should_treat_as_high_risk_path() {
    local file_path="$1"
    case "${file_path}" in
        *Packages/MeetingAssistantCore/Sources/Audio/*|*Packages/MeetingAssistantCore/Sources/Data/*|*Security/*|*Keychain*|*Concurrency*|*actor*|*Actor*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

map_tokens_from_changed_file() {
    local file_path="$1"
    local token_file="$2"
    local file_name
    local stem
    local root
    local parent_dir
    local grandparent_dir

    file_name="$(basename "${file_path}")"
    stem="${file_name%.swift}"
    root="${stem%%+*}"
    parent_dir="$(basename "$(dirname "${file_path}")")"
    grandparent_dir="$(basename "$(dirname "$(dirname "${file_path}")")")"

    append_line_once "${stem}" "${token_file}"
    if [ "${root}" != "${stem}" ]; then
        append_line_once "${root}" "${token_file}"
    fi

    if [ "${parent_dir}" != "$(basename "${PROJECT_DIR}")" ] && [ "${parent_dir}" != "$(basename "$(pwd)")" ]; then
        append_line_once "${parent_dir}" "${token_file}"
    fi

    if [ "${parent_dir}" = "AppDelegate" ] || [ "${parent_dir}" = "AssistantShortcutController" ] || [ "${parent_dir}" = "AppSettingsStore" ] || [ "${parent_dir}" = "RecordingManager" ]; then
        append_line_once "${parent_dir}" "${token_file}"
    elif [ "${parent_dir}" = "Models" ] || [ "${parent_dir}" = "Services" ] || [ "${parent_dir}" = "ViewModels" ] || [ "${parent_dir}" = "components" ]; then
        append_line_once "${grandparent_dir}" "${token_file}"
    fi
}

build_targeted_test_candidates() {
    local changed_file_list="$1"
    local targeted_tests_file="$2"
    local full_reasons_file="$3"
    local token_file
    local test_file_paths
    local exact_matches
    local fuzzy_matches
    local file_path
    local token
    local token_lower
    local base_name
    local base_lower

    token_file="$(new_tmp_file)"
    test_file_paths="$(new_tmp_file)"
    exact_matches="$(new_tmp_file)"
    fuzzy_matches="$(new_tmp_file)"

    : > "${targeted_tests_file}"
    : > "${exact_matches}"
    : > "${fuzzy_matches}"

    find "${PROJECT_DIR}/Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests" \
        -type f -name '*Tests.swift' | sort > "${test_file_paths}"

    while IFS= read -r file_path; do
        [ -n "${file_path}" ] || continue
        case "${file_path}" in
            Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/*Tests.swift)
                append_line_once "$(basename "${file_path}" .swift)" "${exact_matches}"
                ;;
            *.swift)
                map_tokens_from_changed_file "${file_path}" "${token_file}"
                ;;
        esac
    done < "${changed_file_list}"

    while IFS= read -r token; do
        [ -n "${token}" ] || continue
        token_lower="$(lowercase "${token}")"

        if [ "${#token_lower}" -lt 4 ]; then
            continue
        fi

        while IFS= read -r file_path; do
            [ -n "${file_path}" ] || continue
            base_name="$(basename "${file_path}" .swift)"
            base_lower="$(lowercase "${base_name}")"

            if [ "${base_lower}" = "${token_lower}tests" ] || [ "${base_lower}" = "${token_lower}" ]; then
                append_line_once "${base_name}" "${exact_matches}"
            elif [ "${#token_lower}" -ge 6 ] && [[ "${base_lower}" == *"${token_lower}"*tests* ]]; then
                append_line_once "${base_name}" "${fuzzy_matches}"
            fi
        done < "${test_file_paths}"
    done < "${token_file}"

    if [ -f "${TEST_MAPPING_CONFIG}" ]; then
        while IFS='|' read -r pattern mapped_tests; do
            [ -n "${pattern}" ] || continue
            case "${pattern}" in
                \#*)
                    continue
                    ;;
            esac

            while IFS= read -r file_path; do
                [ -n "${file_path}" ] || continue
                if [[ "${file_path}" == ${pattern} ]]; then
                    IFS=',' read -r -a mapped_array <<< "${mapped_tests}"
                    for mapped_test in "${mapped_array[@]}"; do
                        append_line_once "${mapped_test}" "${exact_matches}"
                    done
                fi
            done < "${changed_file_list}"
        done < "${TEST_MAPPING_CONFIG}"
    fi

    cat "${exact_matches}" "${fuzzy_matches}" | sed '/^$/d' | sort -u > "${targeted_tests_file}"

    if [ ! -s "${targeted_tests_file}" ]; then
        append_line_once "No trustworthy targeted test mapping from changed files" "${full_reasons_file}"
    fi
}

main() {
    local changed_file_list
    local full_reasons_file
    local targeted_tests_file
    local modules_file
    local source_files_changed=0
    local added_lines=0
    local module_count=0
    local targeted_count=0
    local code_relevant=0
    local should_run_full=0
    local should_run_intermediate=0
    local reason
    local test_identifier
    local file_path
    local module_name

    trap cleanup_tmp_files EXIT
    cd "${PROJECT_DIR}" || return 1

    changed_file_list="$(new_tmp_file)"
    full_reasons_file="$(new_tmp_file)"
    targeted_tests_file="$(new_tmp_file)"
    modules_file="$(new_tmp_file)"

    if ! collect_changed_files "${changed_file_list}"; then
        return 1
    fi

    if [ ! -s "${changed_file_list}" ]; then
        echo "No changed files detected. Nothing to validate."
        return 0
    fi

    while IFS= read -r file_path; do
        [ -n "${file_path}" ] || continue

        case "${file_path}" in
            *.swift|*.m|*.mm|*.h|*.c|*.cpp|Makefile|Package.swift|scripts/*|.github/workflows/*|*.xcodeproj/*|*.xcworkspace/*)
                code_relevant=1
                ;;
        esac

        case "${file_path}" in
            *.swift)
                source_files_changed=$((source_files_changed + 1))
                ;;
        esac

        if should_treat_as_infra_trigger "${file_path}"; then
            append_line_once "Build/release/test infrastructure changed (${file_path})" "${full_reasons_file}"
        fi

        if should_treat_as_high_risk_path "${file_path}"; then
            append_line_once "High-risk path changed (${file_path})" "${full_reasons_file}"
        fi

        case "${file_path}" in
            Packages/MeetingAssistantCore/Sources/*/*)
                module_name="$(printf '%s\n' "${file_path}" | awk -F/ '{print $4}')"
                append_line_once "${module_name}" "${modules_file}"
                ;;
        esac
    done < "${changed_file_list}"

    module_count="$(sort -u "${modules_file}" | sed '/^$/d' | wc -l | tr -d ' ')"
    if [ "${module_count}" -gt 1 ]; then
        append_line_once "Cross-module change detected (${module_count} modules touched)" "${full_reasons_file}"
    fi

    added_lines="$(git diff --numstat HEAD -- | awk '$1 ~ /^[0-9]+$/ {sum += $1} END {print sum+0}')"
    if [ "${added_lines}" -gt 300 ]; then
        append_line_once "Large delta detected (${added_lines} added lines > 300)" "${full_reasons_file}"
    fi

    if [ "${source_files_changed}" -gt 8 ]; then
        append_line_once "High source-file churn detected (${source_files_changed} files > 8)" "${full_reasons_file}"
    fi

    if [ "${code_relevant}" -eq 0 ]; then
        echo "Only non-code files changed. Skipping scoped build/tests."
        return 0
    fi

    build_targeted_test_candidates "${changed_file_list}" "${targeted_tests_file}" "${full_reasons_file}"
    targeted_count="$(sed '/^$/d' "${targeted_tests_file}" | wc -l | tr -d ' ')"

    if [ "${targeted_count}" -gt "${MAX_TARGETED}" ]; then
        should_run_intermediate=1
    fi

    if [ "${FORCE_FULL}" -eq 1 ]; then
        append_line_once "Forced full gate by flag (--force-full)" "${full_reasons_file}"
    fi

    if [ -s "${full_reasons_file}" ]; then
        should_run_full=1
    fi

    echo "Scoped validation plan:"
    echo "- Changed files: $(wc -l < "${changed_file_list}" | tr -d ' ')"
    echo "- Source files changed: ${source_files_changed}"
    echo "- Added lines vs HEAD: ${added_lines}"
    echo "- Candidate targeted tests: ${targeted_count}"

    if [ "${should_run_full}" -eq 1 ]; then
        echo "- Strategy: full gate (make build-test)"
        echo "- Full-gate reasons:"
        while IFS= read -r reason; do
            [ -n "${reason}" ] || continue
            echo "  - ${reason}"
        done < "${full_reasons_file}"

        run_cmd "make build-test"
        return $?
    fi

    if [ "${should_run_intermediate}" -eq 1 ]; then
        echo "- Strategy: intermediate gate (build + test-full)"
        echo "- Reason: mapped targeted tests exceed threshold (${targeted_count} > ${MAX_TARGETED})"

        if [ "${RUN_BUILD}" -eq 1 ]; then
            if [ "${AGENT_MODE}" -eq 1 ]; then
                run_cmd "make build-agent" || return $?
            else
                run_cmd "make build" || return $?
            fi
        else
            echo "- Narrow build step skipped (--no-build)"
        fi

        if [ "${AGENT_MODE}" -eq 1 ]; then
            run_cmd "make test-full-agent" || return $?
        else
            run_cmd "make test-full" || return $?
        fi

        return 0
    fi

    echo "- Strategy: scoped checks"
    if [ "${RUN_BUILD}" -eq 1 ]; then
        if [ "${AGENT_MODE}" -eq 1 ]; then
            run_cmd "make build-agent" || return $?
        else
            run_cmd "make build" || return $?
        fi
    else
        echo "- Narrow build step skipped (--no-build)"
    fi

    while IFS= read -r test_identifier; do
        [ -n "${test_identifier}" ] || continue
        if [ "${AGENT_MODE}" -eq 1 ]; then
            run_cmd "./scripts/run-tests.sh --suite dev --file ${test_identifier} --agent" || return $?
        else
            run_cmd "./scripts/run-tests.sh --suite dev --file ${test_identifier}" || return $?
        fi
    done < "${targeted_tests_file}"

    return 0
}

emit_agent_result() {
    local exit_code="$1"
    if [ "${AGENT_MODE}" -eq 0 ]; then
        return
    fi

    local end_time
    local duration
    local status
    local error_count
    local summary

    end_time="$(date +%s)"
    duration=$((end_time - START_TIME))
    status="PASS"
    summary="Scoped validation passed"

    if [ "${exit_code}" -ne 0 ]; then
        status="FAIL"
        summary="Scoped validation failed"
    fi

    error_count="0"
    if [ "${exit_code}" -ne 0 ] && [ -f "${LOG_PATH}" ]; then
        error_count="$(ma_agent_error_count "${LOG_PATH}")"
        if [ "${error_count}" -eq 0 ]; then
            error_count=1
        fi
    fi

    ma_agent_write_result_json "${RESULT_PATH}" "scope-check" "${status}" "${duration}" "${LOG_PATH}" "${error_count}" "${summary}"
    ma_agent_emit_result "scope-check" "${status}" "${duration}" "${LOG_PATH}" "${error_count}" "${summary}" "${RESULT_PATH}"
}

parse_args "$@"
prepare_agent_logging
main
EXIT_CODE=$?
emit_agent_result "${EXIT_CODE}"
exit "${EXIT_CODE}"
