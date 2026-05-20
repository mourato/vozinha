#!/bin/bash
# =============================================================================
# run-build-and-test.sh - Sequential build + test with concise progress output
# =============================================================================

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/agent-output.sh
source "${SCRIPT_DIR}/lib/agent-output.sh"
TEST_PROGRESS_INTERVAL_SEC="${MA_BUILD_TEST_HEARTBEAT_INTERVAL_SEC:-15}"

print_step() {
    local pct="$1"
    local msg="$2"
    printf "[%s%%] %s\n" "${pct}" "${msg}"
}

extract_agent_field() {
    local field="$1"
    local log_file="$2"
    grep -E "^${field}=" "${log_file}" | tail -n 1 | cut -d'=' -f2-
}

run_step() {
    local label="$1"
    local pct_start="$2"
    local cmd="$3"
    local out_file="$4"
    local progress_log_path="${5:-}"
    local progress_interval_sec="${6:-15}"

    print_step "${pct_start}" "${label}"
    local exit_code=0

    if [ -n "${progress_log_path}" ]; then
        eval "${cmd}" > "${out_file}" 2>&1 &
        local step_pid=$!
        local start_time
        local now
        local next_heartbeat
        local elapsed
        local progress_counts
        local executed
        local passed
        local failed
        local fallback_progress_log_path

        start_time=$(date +%s)
        next_heartbeat=$((start_time + progress_interval_sec))
        fallback_progress_log_path="${progress_log_path%.log}-swift-fallback.log"

        while kill -0 "${step_pid}" 2>/dev/null; do
            sleep 1
            now=$(date +%s)
            if [ "${now}" -ge "${next_heartbeat}" ]; then
                elapsed=$((now - start_time))
                if progress_counts="$(ma_agent_extract_running_test_counts "${progress_log_path}")"; then
                    read -r executed passed failed <<< "${progress_counts}"
                    printf "      ... progress (%ss) | Executed: %s | Passed: %s | Failed: %s\n" "${elapsed}" "${executed}" "${passed}" "${failed}"
                elif progress_counts="$(ma_agent_extract_running_test_counts "${fallback_progress_log_path}")"; then
                    read -r executed passed failed <<< "${progress_counts}"
                    printf "      ... progress (%ss) | Executed: %s | Passed: %s | Failed: %s (fallback)\n" "${elapsed}" "${executed}" "${passed}" "${failed}"
                else
                    printf "      ... progress (%ss)\n" "${elapsed}"
                fi
                next_heartbeat=$((now + progress_interval_sec))
            fi
        done

        wait "${step_pid}"
        exit_code=$?
    else
        eval "${cmd}" > "${out_file}" 2>&1
        exit_code=$?
    fi

    local status summary duration
    status="$(extract_agent_field "AGENT_STATUS" "${out_file}")"
    summary="$(extract_agent_field "AGENT_SUMMARY" "${out_file}")"
    duration="$(extract_agent_field "AGENT_DURATION_SEC" "${out_file}")"

    if [ -z "${status}" ]; then
        status="FAIL"
    fi

    if [ -z "${duration}" ]; then
        duration="0"
    fi

    if [ -z "${summary}" ]; then
        summary="${label} failed"
    fi

    printf "      %s (%ss)\n" "${summary}" "${duration}"

    if [ "${exit_code}" -ne 0 ]; then
        echo ""
        sed -n '/AGENT_FAILURE_SNIPPET_BEGIN/,/AGENT_FAILURE_SNIPPET_END/p' "${out_file}" || true
    fi

    return "${exit_code}"
}

LOG_DIR="${MA_AGENT_LOG_DIR:-/tmp/ma-agent}"
mkdir -p "${LOG_DIR}"

BUILD_OUT="${LOG_DIR}/build-test-build.step.log"
TEST_OUT="${LOG_DIR}/build-test-test.step.log"
TEST_PROGRESS_LOG="${LOG_DIR}/test-xcode.log"
rm -f "${TEST_PROGRESS_LOG}" "${TEST_PROGRESS_LOG%.log}-swift-fallback.log"

STRICT_XCODE_MODE="${MA_BUILD_TEST_STRICT_XCODE:-}"
if [ -z "${STRICT_XCODE_MODE}" ]; then
    if [ "${CI:-}" = "true" ]; then
        STRICT_XCODE_MODE="1"
    else
        STRICT_XCODE_MODE="0"
    fi
fi

TEST_CMD="MA_AGENT_MODE=1 ./scripts/run-tests-xcode.sh --agent"
if [ "${STRICT_XCODE_MODE}" = "1" ]; then
    TEST_CMD="MA_AGENT_MODE=1 MA_SERIAL_SWIFT_FALLBACK_TESTS=1 ./scripts/run-tests-xcode.sh --strict-xcode --agent"
fi

run_step "Build" "0" "MA_AGENT_MODE=1 ./scripts/run-build.sh --configuration Debug --agent" "${BUILD_OUT}" || exit $?
run_step "Test" "50" "${TEST_CMD}" "${TEST_OUT}" "${TEST_PROGRESS_LOG}" "${TEST_PROGRESS_INTERVAL_SEC}" || exit $?

print_step "100" "Build + Test completed"
