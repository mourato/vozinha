#!/bin/bash

set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/prisma-workflow-test.XXXXXX")"
trap 'rm -rf "${TMP_ROOT}"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    printf '%s\n' "${haystack}" | grep -Fq -- "${needle}" || fail "missing: ${needle}"
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    if printf '%s\n' "${haystack}" | grep -Fq -- "${needle}"; then
        fail "unexpected: ${needle}"
    fi
}

new_fixture() {
    local fixture="${TMP_ROOT}/repo"
    rm -rf "${fixture}"
    mkdir -p "${fixture}/scripts/lib" \
        "${fixture}/scripts/config" \
        "${fixture}/Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests"

    cp "${SCRIPT_ROOT}/scripts/scope-check.sh" "${fixture}/scripts/scope-check.sh"
    cp "${SCRIPT_ROOT}/scripts/lib/agent-output.sh" "${fixture}/scripts/lib/agent-output.sh"
    cp "${SCRIPT_ROOT}/scripts/config/test-target-mapping.conf" "${fixture}/scripts/config/test-target-mapping.conf"
    chmod +x "${fixture}/scripts/scope-check.sh"

    touch "${fixture}/Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AlphaTests.swift"
    touch "${fixture}/Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/BetaTests.swift"
    printf '%s\n' 'fixture baseline' > "${fixture}/README.md"

    git -C "${fixture}" init -q
    git -C "${fixture}" config user.email workflow-test@example.invalid
    git -C "${fixture}" config user.name workflow-test
    git -C "${fixture}" add .
    git -C "${fixture}" commit -qm baseline
    printf '%s\n' "${fixture}"
}

scope_output() {
    local fixture="$1"
    local log_root="$2"
    shift 2
    (cd "${fixture}" && MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="${log_root}" ./scripts/scope-check.sh --dry-run --agent "$@")
}

test_committed_delta_boundaries() {
    local fixture
    local base
    local output

    fixture="$(new_fixture)"
    base="$(git -C "${fixture}" rev-parse HEAD)"
    awk 'BEGIN { for (i = 1; i <= 300; i++) print "line-" i }' > "${fixture}/Changed.swift"
    git -C "${fixture}" add Changed.swift
    git -C "${fixture}" commit -qm "300 lines"
    output="$(scope_output "${fixture}" "${TMP_ROOT}/boundary-300" --base "${base}")"
    assert_contains "${output}" "Added lines (${base} -> working tree): 300"
    assert_not_contains "${output}" "Large delta detected"

    fixture="$(new_fixture)"
    base="$(git -C "${fixture}" rev-parse HEAD)"
    awk 'BEGIN { for (i = 1; i <= 301; i++) print "line-" i }' > "${fixture}/Changed.swift"
    git -C "${fixture}" add Changed.swift
    git -C "${fixture}" commit -qm "301 lines"
    output="$(scope_output "${fixture}" "${TMP_ROOT}/boundary-301" --base "${base}")"
    assert_contains "${output}" "Added lines (${base} -> working tree): 301"
    assert_contains "${output}" "Large delta detected (301 added lines > 300)"
}

test_source_file_churn() {
    local fixture
    local base
    local output
    local index

    fixture="$(new_fixture)"
    base="$(git -C "${fixture}" rev-parse HEAD)"
    for index in $(seq 1 9); do
        printf '%s\n' "source-${index}" > "${fixture}/Source${index}.swift"
    done
    git -C "${fixture}" add .
    git -C "${fixture}" commit -qm "source churn"
    output="$(scope_output "${fixture}" "${TMP_ROOT}/source-churn" --base "${base}")"
    assert_contains "${output}" "Source files changed: 9"
    assert_contains "${output}" "High source-file churn detected (9 files > 8)"
}

test_worktree_layers_are_unique() {
    local fixture
    local output

    fixture="$(new_fixture)"
    printf '%s\n' 'tracked' > "${fixture}/staged.swift"
    printf '%s\n' 'tracked' > "${fixture}/unstaged.swift"
    git -C "${fixture}" add staged.swift unstaged.swift
    git -C "${fixture}" commit -qm "tracked fixtures"
    printf '%s\n' 'staged change' >> "${fixture}/staged.swift"
    git -C "${fixture}" add staged.swift
    printf '%s\n' 'unstaged change' >> "${fixture}/unstaged.swift"
    printf '%s\n' 'untracked change' > "${fixture}/untracked.swift"
    output="$(scope_output "${fixture}" "${TMP_ROOT}/layers")"
    assert_contains "${output}" "Changed files: 3"
    assert_contains "${output}" "Source files changed: 3"
}

test_repeated_file_targets_and_invalid_base() {
    local fixture
    local base
    local output
    local invalid_status

    fixture="$(new_fixture)"
    base="$(git -C "${fixture}" rev-parse HEAD)"
    printf '%s\n' 'alpha' > "${fixture}/Alpha.swift"
    printf '%s\n' 'beta' > "${fixture}/Beta.swift"
    git -C "${fixture}" add Alpha.swift Beta.swift
    git -C "${fixture}" commit -qm "mapped files"
    output="$(scope_output "${fixture}" "${TMP_ROOT}/targets" --base "${base}")"
    assert_contains "${output}" "./scripts/run-tests.sh --suite dev --file AlphaTests --file BetaTests --agent"
    test "$(printf '%s\n' "${output}" | grep -Fc './scripts/run-tests.sh')" -eq 1

    set +e
    output="$(scope_output "${fixture}" "${TMP_ROOT}/invalid" --base missing-ref 2>&1)"
    invalid_status=$?
    set -e
    test "${invalid_status}" -eq 1
    assert_contains "${output}" "Error: base ref 'missing-ref' does not exist."
}

test_schema_and_parallel_artifacts() {
    local fixture
    local output
    local result_path
    local first_path
    local second_path
    local first_status
    local second_status

    fixture="$(new_fixture)"
    output="$(scope_output "${fixture}" "${TMP_ROOT}/schema")"
    result_path="$(printf '%s\n' "${output}" | sed -n 's/^AGENT_RESULT_JSON=//p' | tail -n 1)"
    test -f "${result_path}"
    python3 - "${result_path}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    result = json.load(handle)
assert result["schemaVersion"] == 2
assert result["log"]
PY

    set +e
    (cd "${fixture}" && MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="${TMP_ROOT}/parallel" ./scripts/scope-check.sh --dry-run --agent > "${TMP_ROOT}/parallel-a.out" 2>&1) &
    local first_pid=$!
    (cd "${fixture}" && MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="${TMP_ROOT}/parallel" ./scripts/scope-check.sh --dry-run --agent > "${TMP_ROOT}/parallel-b.out" 2>&1) &
    local second_pid=$!
    wait "${first_pid}"
    first_status=$?
    wait "${second_pid}"
    second_status=$?
    set -e
    test "${first_status}" -eq 0
    test "${second_status}" -eq 0

    first_path="$(sed -n 's/^AGENT_RESULT_JSON=//p' "${TMP_ROOT}/parallel-a.out" | tail -n 1)"
    second_path="$(sed -n 's/^AGENT_RESULT_JSON=//p' "${TMP_ROOT}/parallel-b.out" | tail -n 1)"
    test -f "${first_path}"
    test -f "${second_path}"
    test "${first_path}" != "${second_path}"
    test "$(dirname "${first_path}")" != "$(dirname "${second_path}")"
}

test_nested_commands_inherit_run_tree() {
    local fixture

    fixture="$(new_fixture)"
    (
        cd "${fixture}"
        source scripts/lib/agent-output.sh
        ma_agent_prepare_run_dir >/dev/null
        bash -c 'source scripts/lib/agent-output.sh; ma_agent_prepare_run_dir >/dev/null; test "${MA_AGENT_RUN_DIR}" = "${1}"' bash "${MA_AGENT_RUN_DIR}"
    )
}

test_committed_delta_boundaries
test_source_file_churn
test_worktree_layers_are_unique
test_repeated_file_targets_and_invalid_base
test_schema_and_parallel_artifacts
test_nested_commands_inherit_run_tree
echo "WORKFLOW_TEST_STATUS=PASS"
