#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/agent-output.sh"

STEP="${1:?step is required}"
ma_agent_prepare_run_dir >/dev/null
LOG_PATH="${MA_AGENT_RUN_DIR}/fixture-${STEP}.log"
RESULT_PATH="${MA_AGENT_RUN_DIR}/fixture-${STEP}.result.json"
: > "${LOG_PATH}"
if [ -n "${WORKFLOW_STEP_LOG:-}" ]; then
    printf '%s\n' "${STEP}" >> "${WORKFLOW_STEP_LOG}"
fi

STATUS="PASS"
ERROR_COUNT=0
SUMMARY="fixture pass"
if [ "${WORKFLOW_FAIL_STEP:-}" = "${STEP}" ]; then
    STATUS="FAIL"
    ERROR_COUNT=1
    SUMMARY="fixture failure"
fi

ma_agent_write_result_json "${RESULT_PATH}" "${STEP}" "${STATUS}" 0 "${LOG_PATH}" "${ERROR_COUNT}" "${SUMMARY}"
ma_agent_emit_result "${STEP}" "${STATUS}" 0 "${LOG_PATH}" "${ERROR_COUNT}" "${SUMMARY}" "${RESULT_PATH}"
[ "${STATUS}" = "PASS" ]
