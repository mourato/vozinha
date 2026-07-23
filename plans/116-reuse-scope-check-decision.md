# Plan 116: Reuse the Scope Check Decision in Agent Validation

> Status: DONE  |  Priority: P1  |  Effort: S

## Executor instructions

Refactor only the agent validation decision flow. Preserve the current lane policy and exact technical validation behavior.

## Drift check

- Planned baseline SHA: 5875628a
- scripts/validate-agent.sh:305-343 already calls scope-check in dry-run mode and parses its JSON.
- scripts/validate-agent.sh:650-674 separately invokes make scope-check-agent for the Fast lane.
- scripts/scope-check.sh:469-611 owns classification and targeted mapping.

## Execution profile

- Recommended profile: implementer-fast
- Risk/lane: Medium / Full
- Parallelizable: no; validation control-flow workstream
- Reviewer required: yes; lane selection changes which checks execute
- Rationale: remove duplicate classification while preserving scope-check as policy owner
- Escalate when: the existing JSON lacks enough evidence to replace the second invocation

## Why this matters

The auto decision obtains a scope-check result, then the Fast path runs scope-check again. Reusing the first decision reduces redundant work and prevents classification from diverging.

## Scope

In scope: pass the validated scope-check decision through agent validation, remove only the redundant invocation, and retain current evidence and failure behavior.

Out of scope: changing risk triggers, target mapping, Make ownership, or the explicit scope-check target.

## Ordered steps

1. Document current JSON fields and call sites. Verify Full, Fast, guidance, and dry-run paths.
2. Add the smallest structured handoff for the validated decision. Verify missing or malformed data fails closed.
3. Replace the duplicate Fast-path call after confirming identical base, changed files, lane, and target mapping.
4. Add workflow fixtures for reuse and malformed output. Verify the old duplicate call is absent.
5. Run validation and compare command traces before and after.

## Test plan

- make workflow-test
- make validate-agent ARGS="--lane auto --dry-run --base main --agent"
- make guidance-check
- git diff --check

## Done criteria

- Auto validation performs one scope decision per run.
- Existing lane selection is unchanged.
- Malformed or missing data fails closed.
- Workflow tests and the dry-run gate pass.

## STOP conditions

Stop if the refactor changes a lane decision, hides scope-check output, makes direct scope-check invocation impossible, or duplicates policy logic in validate-agent.

## Maintenance notes

Keep scripts/scope-check.sh as the single owner of classification and target mapping.
