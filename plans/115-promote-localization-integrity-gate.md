# Plan 115: Promote Localization Integrity to a Deterministic Gate

> Status: DONE  |  Priority: P0  |  Effort: M

## Executor instructions

Implement only the localization validation path. Preserve the existing XCTest behavior and unrelated worktree changes. Do not log source text, transcripts, credentials, or machine state.

## Drift check

- Planned baseline SHA: 5875628a
- Existing localization logic is in Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/LocalizationKeyIntegrityTests.swift:4-87.
- Existing guidance gate is Makefile:228-231 and runs scripts/validate-agent-guidance.py plus the app identity check.
- Re-read these files before editing. If the XCTest semantics changed, update this plan before implementation.

## Execution profile

- Recommended profile: implementer
- Risk/lane: Medium / Full
- Parallelizable: no; one validation workstream
- Reviewer required: yes; a false positive or false negative can block delivery or ship missing UI text
- Rationale: the new script must become a stable producer of evidence while XCTest remains defense in depth
- Escalate when: the script cannot share the existing parsing semantics without creating a second incompatible implementation

## Why this matters

Localization integrity is already tested, but only through a package XCTest. A deterministic script and Make target can run earlier, cheaply, and in agent or pre-commit workflows. The implementation must promote the existing logic rather than invent a different definition of a valid key.

## Scope

In scope:

- Extract or share the key-set and literal-key checks currently covered by the XCTest.
- Add a focused script with stable exit codes and concise diagnostics.
- Add a Make target and invoke it from the appropriate guidance or validation gate.
- Keep the XCTest as a defense-in-depth test and remove duplication only when behavior remains provably equivalent.

Out of scope:

- Changing localization keys or user-facing copy.
- Adding new locale policy beyond the current en and pt symmetry.
- Scanning generated, build, or temporary artifacts.

## Ordered steps

1. Capture current XCTest cases and fixtures, including missing keys, orphaned keys, and literal localized references. Verify the script acceptance cases match these semantics.
2. Choose reuse before extraction: prefer a small shared parser or a script invoked by XCTest only if the project tooling can consume it without fragile subprocess coupling. Verify malformed input fails closed.
3. Add the script under scripts/ with explicit roots for App and package Sources and the existing locale resource directories. Verify output contains paths and key names but no sensitive content.
4. Add the narrow Make target and wire it into the selected agent gate. Verify a clean tree passes and intentionally missing or orphaned keys fail.
5. Keep or simplify the XCTest only after comparing pass and fail cases against the script. Verify no coverage is lost.
6. Run the required validation and inspect the diff.

## Test plan

- make guidance-check
- make workflow-test
- the new localization target
- the existing MeetingAssistantCore localization XCTest
- git diff --check

## Done criteria

- The script and Make target detect the same missing, orphaned, and literal-key cases as the current XCTest.
- The check is deterministic, fast, and safe for agent execution.
- The gate produces actionable file and key diagnostics.
- Existing tests remain green and no product source is changed.

## STOP conditions

Stop if behavior would diverge from LocalizationKeyIntegrityTests without an explicit policy decision, if locale discovery is ambiguous, if generated resources are mixed with source resources, or if validation cannot distinguish baseline failures from the new check.

## Maintenance notes

When adding a locale or changing key syntax, update the single canonical parser and its fixture coverage first. Keep this check independent of network services and model calls.
