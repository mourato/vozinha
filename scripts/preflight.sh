#!/bin/bash
# =============================================================================
# preflight.sh - Standard local pre-merge validation checks
# =============================================================================
# Runs the canonical quality gates in sequence:
# 1) build
# 2) test
# 3) lint
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

    run_tests() {
        make test-full
    }

    run_parallel_build_and_lint() {
        local lint_status=0
        local build_status=0

        echo "[1/3] make lint (parallel)"
        make lint &
        local lint_pid=$!

        echo "[2/3] make build (parallel)"
        make build &
        local build_pid=$!

        wait "${lint_pid}" || lint_status=$?
        wait "${build_pid}" || build_status=$?

        if [ "${lint_status}" -ne 0 ] || [ "${build_status}" -ne 0 ]; then
            return 1
        fi

        return 0
    }

    if [ "${FAST_MODE}" -eq 1 ]; then
        run_parallel_build_and_lint

        echo "[3/3] make test"
        run_tests

        if [ "${STRICT_CONCURRENCY}" -eq 1 ]; then
            echo "[4/4] make test-strict"
            make test-strict
        fi
    else
        run_parallel_build_and_lint

        echo "[3/4] make test"
        run_tests

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

LOG_DIR="$(ma_agent_prepare_log_dir)"
RESULT_PATH="${LOG_DIR}/preflight.result.json"
START_TIME=$(date +%s)

SUMMARY="Preflight completed successfully"

run_test_agent() {
    make test-full-agent
}

if [ "${FAST_MODE}" -eq 1 ]; then
    if ! make lint-agent; then
        SUMMARY="Preflight failed during lint"
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}"
        ma_agent_emit_result "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${RESULT_PATH}"
        exit 1
    fi

    if ! make build-agent; then
        SUMMARY="Preflight failed during build"
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}"
        ma_agent_emit_result "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${RESULT_PATH}"
        exit 1
    fi

    if ! run_test_agent; then
        SUMMARY="Preflight failed during test"
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}"
        ma_agent_emit_result "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${RESULT_PATH}"
        exit 1
    fi
else
if ! make build-agent; then
    SUMMARY="Preflight failed during build"
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}"
    ma_agent_emit_result "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${RESULT_PATH}"
    exit 1
fi

if [ "${STRICT_LINT_MODE}" -eq 1 ]; then
    if ! make lint-agent; then
        SUMMARY="Preflight failed during lint"
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}"
        ma_agent_emit_result "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${RESULT_PATH}"
        exit 1
    fi
fi

if ! run_test_agent; then
    SUMMARY="Preflight failed during test"
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}"
    ma_agent_emit_result "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${RESULT_PATH}"
    exit 1
fi

if [ "${STRICT_LINT_MODE}" -ne 1 ]; then
    if ! make lint-agent; then
        SUMMARY="Preflight failed during lint"
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}"
        ma_agent_emit_result "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${RESULT_PATH}"
        exit 1
    fi
fi

if ! MA_AGENT_MODE=1 ./scripts/run-summary-benchmark.sh "${BENCHMARK_ARG}" --agent; then
    SUMMARY="Preflight failed during summary benchmark"
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}"
    ma_agent_emit_result "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${RESULT_PATH}"
    exit 1
fi
fi

if [ "${FAST_MODE}" -eq 0 ] && [ "${STRICT_CONCURRENCY}" -eq 1 ]; then
    echo "AGENT_NOTE=running strict concurrency gate"
    if ! MA_AGENT_MODE=1 ./scripts/run-tests.sh --strict --agent; then
        SUMMARY="Preflight failed during strict concurrency test"
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}"
        ma_agent_emit_result "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${RESULT_PATH}"
        exit 1
    fi
fi

if [ "${FAST_MODE}" -eq 1 ] && [ "${STRICT_CONCURRENCY}" -eq 1 ]; then
    echo "AGENT_NOTE=running strict concurrency gate"
    if ! MA_AGENT_MODE=1 ./scripts/run-tests.sh --strict --agent; then
        SUMMARY="Preflight failed during strict concurrency test"
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        ma_agent_write_result_json "${RESULT_PATH}" "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}"
        ma_agent_emit_result "preflight" "FAIL" "${DURATION}" "${LOG_DIR}" 1 "${SUMMARY}" "${RESULT_PATH}"
        exit 1
    fi
fi

if [ "${FAST_MODE}" -eq 1 ]; then
    SUMMARY="Preflight fast completed successfully"
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
ma_agent_write_result_json "${RESULT_PATH}" "preflight" "PASS" "${DURATION}" "${LOG_DIR}" 0 "${SUMMARY}"
ma_agent_emit_result "preflight" "PASS" "${DURATION}" "${LOG_DIR}" 0 "${SUMMARY}" "${RESULT_PATH}"
