# Plan 118: Add Report-First Cleanup for Agent Build Artifacts

> Status: DONE  |  Priority: P2  |  Effort: M

## Executor instructions

Design a safe cleanup and reporting workflow. Do not delete artifacts during this plan and do not add broad recursive deletion.

## Drift check

- Planned baseline SHA: 5875628a
- Observed local directories include .tmp at about 4.6G, .xcode-build at about 5.0G, .xcode-build-ci-parity at about 2.0G, .xcode-build-tests at about 385M, dist at about 347M, and build at about 2.5G.
- Makefile:291-295 currently removes only .xcode-build and dist.
- .gitignore:76-90 ignores temporary and build output directories.

## Execution profile

- Recommended profile: implementer-fast
- Risk/lane: High / Full
- Parallelizable: no; filesystem lifecycle workstream
- Reviewer required: yes; cleanup can destroy useful diagnostics or user data
- Rationale: first inventory exact managed roots, then offer explicit scoped cleanup with dry-run and retention rules
- Escalate when: an artifact directory can contain user-created files, active build state, or evidence needed by another task

## Why this matters

Agent and build artifacts consume disk space and can slow scans, but blind cleanup is unsafe. A report-first command can make the cost visible and allow an explicit, recoverable action.

## Scope

In scope: inventory managed artifact roots, report sizes and age buckets, add dry-run output, and add explicit cleanup of only validated generated roots.

Out of scope: deleting user directories, changing Git ignore policy without evidence, deleting active build state, or cleaning package caches outside the repository.

## Ordered steps

1. Define an allowlist of generated roots and ownership markers. Verify the command refuses unknown paths, symlinks, and repository roots.
2. Implement report mode first, including total size, largest roots, age ranges, and whether a root is currently active. Verify output is deterministic and contains no secret or source content.
3. Add dry-run cleanup showing exact paths and estimated reclaimed space. Verify no filesystem mutation occurs in dry-run mode.
4. Add explicit cleanup only for safe roots, with a confirmation or non-interactive opt-in required by the project workflow. Verify failure is fail-closed.
5. Add fixture tests using temporary directories and run the normal workflow checks.

## Test plan

- the new report command against the current worktree
- dry-run cleanup against isolated fixtures
- make workflow-test
- make guidance-check
- git diff --check

## Done criteria

- Report mode identifies the major generated roots without scanning outside the project allowlist.
- Dry-run is non-mutating and prints exact targets.
- Cleanup cannot target broad or unresolved paths.
- Active or recently modified artifacts are protected by explicit rules.

## STOP conditions

Stop if ownership cannot be proven, if cleanup requires deleting a shared or active directory, if path canonicalization is incomplete, or if the command cannot prove dry-run non-mutation.

## Maintenance notes

Keep report mode usable without cleanup permission. Review retention windows when build tooling or CI output locations change.
