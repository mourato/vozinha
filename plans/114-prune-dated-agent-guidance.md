# Plan 114: Prune Dated Agent Guidance Without Losing Durable Rules

> Status: DONE  |  Priority: P0  |  Effort: M

## Executor instructions

Guidance-only change. Preserve unrelated worktree changes.

## Drift check

Planned baseline SHA: 5875628a. Inspect the current diff before editing. If any target skill changed materially, re-audit its dated section first.

## Execution profile

- Recommended profile: implementer-fast
- Risk/lane: Low / Fast
- Parallelizable: no; one serial guidance workstream
- Reviewer required: yes; guidance changes affect future agent behavior
- Rationale: remove stale repetition after relocating unique durable rules
- Escalate when: a dated section contains behavior that is not represented elsewhere

## Why this matters

Six skills contain dated progression or operational-update blocks that repeat current rules. They increase context size and make historical notes look authoritative.

## Current state

Review these exact ranges:

- .agents/skills/audio-realtime/SKILL.md:68-93
- .agents/skills/code-quality/SKILL.md:100-113
- .agents/skills/data-persistence/SKILL.md:48-102
- .agents/skills/intelligence-kernel/SKILL.md:96-138
- .agents/skills/swift-concurrency-expert/SKILL.md:77-138
- .agents/skills/testing-xctest/SKILL.md:83-96

The current guidance validator checks structure and links, but does not classify historical guidance as stale.

## Scope

In scope: move unique durable rules into timeless sections, then remove historical narrative and duplicate prose.

Out of scope: scripts, Make targets, source code, routing ownership, or user-owned plan files.

## Ordered steps

1. Compare each dated block with the rest of its skill and identify unique durable rules. Verify that each rule has one canonical location.
2. Move unique rules into the existing section for the same concern. Keep wording imperative and concise.
3. Remove stale blocks. Verify no dated progression or update heading remains in the six target files.
4. Run make guidance-check, make workflow-test, and git diff --check.

## Test plan

- make guidance-check
- make workflow-test
- git diff --check

## Done criteria

- No dated historical block remains in the six target skills.
- Every unique safety, validation, and architecture rule remains in a current section.
- Validation passes and the diff contains only intended guidance files.

## STOP conditions

Stop if a historical block is the only source for a non-obvious invariant, current versions conflict, validation fails for an unexplained reason, or the diff touches product source or user-owned plans.

## Maintenance notes

Keep current rules in timeless sections. Historical migration notes belong in Git history or a dedicated archive, not in the agent execution path.
