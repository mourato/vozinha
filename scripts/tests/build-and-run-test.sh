#!/bin/bash

set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
help_output="$(${SCRIPT_ROOT}/scripts/build-and-run.sh --help)"
printf '%s\n' "$help_output" | grep -Fq -- '--no-interactive'
printf '%s\n' "$help_output" | grep -Fq -- '--force-terminate'
printf '%s\n' "$help_output" | grep -Fq -- 'Debug'
printf '%s\n' "$help_output" | grep -Fq -- 'Release'

set +e
noninteractive_output="$(${SCRIPT_ROOT}/scripts/build-and-run.sh --no-interactive 2>&1)"
noninteractive_status=$?
set -e
[ "$noninteractive_status" -ne 0 ]
printf '%s\n' "$noninteractive_output" | grep -Fq -- 'requires --configuration'

set +e
invalid_output="$(${SCRIPT_ROOT}/scripts/build-and-run.sh --configuration Release --no-interactive --applications-dir / 2>&1)"
invalid_status=$?
set -e
[ "$invalid_status" -ne 0 ]
printf '%s\n' "$invalid_output" | grep -Fq -- 'filesystem root'

echo "BUILD_AND_RUN_TEST_STATUS=PASS"
