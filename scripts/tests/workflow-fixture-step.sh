#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/agent-output.sh"

STEP="${1:?step is required}"
ma_agent_prepare_run_dir >/dev/null
LOG_PATH="${MA_AGENT_RUN_DIR}/fixture-${STEP}.log"
RESULT_PATH="${MA_AGENT_RUN_DIR}/fixture-${STEP}.result.json"
: > "${LOG_PATH}"
ma_agent_write_result_json "${RESULT_PATH}" "${STEP}" "PASS" 0 "${LOG_PATH}" 0 "fixture pass"
ma_agent_emit_result "${STEP}" "PASS" 0 "${LOG_PATH}" 0 "fixture pass" "${RESULT_PATH}"
