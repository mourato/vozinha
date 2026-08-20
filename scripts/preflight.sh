#!/bin/bash
# =============================================================================
# preflight.sh - Standard local pre-merge validation checks
# =============================================================================
# Runs the canonical quality gates:
# 1) build and lint in parallel
# 2) tests
# 3) optional strict-concurrency tests
# 4) summary benchmark gate
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/agent-output.sh
source "${SCRIPT_DIR}/lib/agent-output.sh"

AGENT_MODE=0
STRICT_CONCURRENCY=0
FAST_MODE=0
STRICT_LINT_MODE="${STRICT_LINT:-0}"
SUMMARY_BENCHMARK_MODE="${MA_SUMMARY_BENCHMARK_GATE_MODE:-report-only}"
if ma_agent_mode_enabled; then
    AGENT_MODE=1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)
            AGENT_MODE=1
            MA_AGENT_MODE=1
            shift
            ;;
        --strict-concurrency)
            STRICT_CONCURRENCY=1
            shift
            ;;
        --fast)
            FAST_MODE=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--agent] [--strict-concurrency] [--fast]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ "${SUMMARY_BENCHMARK_MODE}" != "report-only" ] && [ "${SUMMARY_BENCHMARK_MODE}" != "enforce" ]; then
    echo "Invalid MA_SUMMARY_BENCHMARK_GATE_MODE: ${SUMMARY_BENCHMARK_MODE}"
    echo "Valid values: report-only, enforce"
    exit 1
fi

if [ "${STRICT_LINT_MODE}" != "0" ] && [ "${STRICT_LINT_MODE}" != "1" ]; then
    echo "Invalid STRICT_LINT value: ${STRICT_LINT_MODE}"
    echo "Valid values: 0, 1"
    exit 1
fi

BENCHMARK_ARG="--report-only"
if [ "${SUMMARY_BENCHMARK_MODE}" = "enforce" ]; then
    BENCHMARK_ARG="--enforce"
fi

cd "${PROJECT_ROOT}"

run_parallel_lint_and_build() {
    local lint_target="$1"
    local build_target="$2"
    local lint_status=0
    local build_status=0

    if [ "${AGENT_MODE}" -eq 0 ]; then
        echo "[1/3] make ${lint_target} (parallel)"
    fi
    make "${lint_target}" &
    local lint_pid=$!

    if [ "${AGENT_MODE}" -eq 0 ]; then
        echo "[2/3] make ${build_target} (parallel)"
    fi
    make "${build_target}" &
    local build_pid=$!

    wait "${lint_pid}" || lint_status=$?
    wait "${build_pid}" || build_status=$?

    if [ "${AGENT_MODE}" -eq 1 ]; then
        if [ "${lint_status}" -ne 0 ]; then
            emit_preflight_failure "lint" "Preflight failed during lint"
        fi
        if [ "${build_status}" -ne 0 ]; then
            emit_preflight_failure "build" "Preflight failed during build"
        fi
    elif [ "${lint_status}" -ne 0 ] || [ "${build_status}" -ne 0 ]; then
        return 1
    fi

    return 0
}

if [ "${AGENT_MODE}" -eq 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ "${FAST_MODE}" -eq 1 ]; then
        if [ "${STRICT_CONCURRENCY}" -eq 1 ]; then
            echo "  Preflight (fast): lint + build + test + test-strict"
        else
            echo "  Preflight (fast): lint + build + test"
        fi
    else
        if [ "${STRICT_LINT_MODE}" -eq 1 ]; then
            if [ "${STRICT_CONCURRENCY}" -eq 1 ]; then
                echo "  Preflight: build + lint(strict) + test + test-strict + summary-benchmark(${SUMMARY_BENCHMARK_MODE})"
            else
                echo "  Preflight: build + lint(strict) + test + summary-benchmark(${SUMMARY_BENCHMARK_MODE})"
            fi
        else
            if [ "${STRICT_CONCURRENCY}" -eq 1 ]; then
                echo "  Preflight: build + test + test-strict + lint + summary-benchmark(${SUMMARY_BENCHMARK_MODE})"
            else
                echo "  Preflight: build + test + lint + summary-benchmark(${SUMMARY_BENCHMARK_MODE})"
            fi
        fi
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    run_parallel_lint_and_build "lint" "build"

    if [ "${FAST_MODE}" -eq 1 ]; then
        echo "[3/3] make test"
        make test-full

        if [ "${STRICT_CONCURRENCY}" -eq 1 ]; then
            echo "[4/4] make test-strict"
            make test-strict
        fi
    else
        echo "[3/4] make test"
        make test-full

        if [ "${STRICT_CONCURRENCY}" -eq 1 ]; then
            echo "[4/5] make test-strict"
            make test-strict
            echo "[5/5] summary benchmark (${SUMMARY_BENCHMARK_MODE})"
            ./scripts/run-summary-benchmark.sh "${BENCHMARK_ARG}"
        else
            echo "[4/4] summary benchmark (${SUMMARY_BENCHMARK_MODE})"
            ./scripts/run-summary-benchmark.sh "${BENCHMARK_ARG}"
        fi
    fi

    echo "✓ Preflight completed successfully"
    exit 0
fi

ma_agent_prepare_run_dir
LOG_DIR="${MA_AGENT_RUN_DIR}"
RESULT_PATH="${LOG_DIR}/preflight.result.json"
START_TIME=$(date +%s)

SUMMARY="Preflight completed successfully"

emit_preflight_failure() {
    local failed_step="$1"
    local summary="$2"
    local end_time
    local duration
    end_time=$(date +%s)
    duration=$((end_time - START_TIME))
    local commands_json="[{\"name\":\"${failed_step}\",\"status\":\"FAIL\",\"durationSec\":${duration},\"log\":\"$(ma_agent_json_escape "${LOG_DIR}")\"}]"
    local decision_json="{\"strategy\":\"preflight\",\"failedStep\":\"$(ma_agent_json_escape "${failed_step}")\"}"
    ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${duration}" "${LOG_DIR}" 1 "${summary}" "${commands_json}" "${decision_json}"
    ma_agent_emit_result "preflight" "FAIL" "${duration}" "${LOG_DIR}" 1 "${summary}" "${RESULT_PATH}"
    exit 1
}

run_parallel_lint_and_build "lint-agent" "build-agent"

if ! make test-full-agent; then
    emit_preflight_failure "test" "Preflight failed during test"
fi

if [ "${STRICT_CONCURRENCY}" -eq 1 ]; then
    echo "AGENT_NOTE=running strict concurrency gate"
    if ! MA_AGENT_MODE=1 ./scripts/run-tests.sh --strict --agent; then
        emit_preflight_failure "strict-concurrency" "Preflight failed during strict concurrency test"
    fi
fi

if [ "${FAST_MODE}" -eq 0 ]; then
    if ! MA_AGENT_MODE=1 ./scripts/run-summary-benchmark.sh "${BENCHMARK_ARG}" --agent; then
        SUMMARY="Preflight failed during summary benchmark"
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        COMMANDS_JSON="[{\"name\":\"summary-benchmark\",\"status\":\"FAIL\",\"durationSec\":${DURATION},\"log\":\"$(ma_agent_json_escape "${LOG_DIR}")\"}]"
        DECISION_JSON="{\"strategy\":\"preflight\",\"failedStep\":\"summary-benchmark\"}"
        ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${COMMANDS_JSON}" "${DECISION_JSON}"
        ma_agent_emit_result "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${RESULT_PATH}"
        exit 1
    fi
fi

if [ "${FAST_MODE}" -eq 1 ]; then
    SUMMARY="Preflight fast completed successfully"
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
COMMANDS_JSON="[{\"name\":\"preflight\",\"status\":\"PASS\",\"durationSec\":${DURATION},\"log\":\"$(ma_agent_json_escape "${LOG_DIR}")\"}]"
DECISION_JSON="{\"strategy\":\"preflight\",\"benchmark\":$([ "${FAST_MODE}" -eq 0 ] && echo true || echo false),\"strictConcurrency\":$([ "${STRICT_CONCURRENCY}" -eq 1 ] && echo true || echo false)}"
ma_agent_write_result_json "${RESULT_PATH}" "preflight" "PASS" "${DURATION}" "${LOG_DIR}" 0 "${SUMMARY}" "${COMMANDS_JSON}" "${DECISION_JSON}"
ma_agent_emit_result "preflight" "PASS" "${DURATION}" "${LOG_DIR}" 0 "${SUMMARY}" "${RESULT_PATH}"
