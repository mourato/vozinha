# Plan 117: Cache SwiftPM Resolution in the Agent Test Path

> Status: DONE  |  Priority: P1  |  Effort: M

## Executor instructions

Optimize dependency resolution only. Preserve package identity, scratch paths, patch application, test selection, and failure semantics.

## Drift check

- Planned baseline SHA: 5875628a
- scripts/run-tests.sh:285-321 resolves SwiftPM dependencies on every agent run.
- scripts/run-tests-xcode.sh:123-183 already uses a dependency fingerprint marker.
- scripts/xcodebuild-safe.sh:87-141 has a similar marker pattern.

## Execution profile

- Recommended profile: implementer
- Risk/lane: High / Full
- Parallelizable: no; build and test infrastructure workstream
- Reviewer required: yes; stale dependency state can produce misleading test results
- Rationale: reuse the proven fingerprint approach and keep an explicit forced-resolution escape hatch
- Escalate when: package-manager inputs cannot be fingerprinted safely or the cache would cross incompatible toolchains

## Why this matters

The agent SwiftPM path performs resolve on every invocation, even when manifests, lockfiles, and package configuration are unchanged. A safe fingerprint can avoid repeated network and package-manager work while retaining reproducibility.

## Scope

In scope: compute a deterministic fingerprint from package manifests, resolved versions, relevant configuration, and toolchain identity; skip resolve on a matching marker; invalidate on changes; provide an explicit force path.

Out of scope: changing dependency versions, moving the scratch directory, caching build products, or suppressing resolution failures.

## Ordered steps

1. Identify all inputs that affect resolution and the existing agent scratch lifecycle. Verify the fingerprint excludes timestamps and machine-specific absolute paths.
2. Reuse the marker style from the Xcode runners or extract a small shared shell helper without changing existing behavior. Verify missing markers resolve.
3. Add atomic marker creation only after successful resolution. Verify an interrupted resolve cannot create a false cache hit.
4. Add workflow fixtures for first run, cache hit, manifest change, lockfile change, toolchain change, and forced resolve. Verify each path emits concise evidence.
5. Run the affected package tests and the full workflow validation.

## Test plan

- make workflow-test
- the agent SwiftPM test command for MeetingAssistantCore
- make validate-agent ARGS="--lane auto --dry-run --base main --agent"
- git diff --check

## Done criteria

- Unchanged agent runs skip SwiftPM resolve.
- Relevant changes invalidate the marker and resolve again.
- Failed or interrupted resolution never creates a valid marker.
- The force path is documented and tested.
- Existing test and patch behavior remains unchanged.

## STOP conditions

Stop if the proposed fingerprint omits a resolution input, if markers can be shared across incompatible toolchains, if the first run no longer resolves, or if tests can run against stale dependencies without an explicit failure.

## Maintenance notes

Keep dependency-resolution caching separate from build-product caching. Treat cache evidence as an optimization, never as a substitute for a failed resolve.
