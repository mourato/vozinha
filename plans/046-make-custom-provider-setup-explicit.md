# Plan 046: Make custom provider setup explicit and resilient

> **Executor instructions**: This plan changes credential/setup behavior. Use Keychain patterns, never expose or log secret values, and run thermo review with security emphasis. Correct all Critical/Medium findings.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- Packages/MeetingAssistantCore/Sources/UI/ViewModels/AISettingsViewModel Packages/MeetingAssistantCore/Sources/AI/Services/LLMService.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests plans/README.md`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: plans/039-align-swift6-concurrency-baseline.md
- **Category**: bug
- **Planned at**: commit `80ed5788`, 2026-07-12
- **Related issues**: #63, #65

## Why this matters

The current AI settings flow persists an API key only after `/models` verification succeeds, and custom providers are treated as if they always expose an OpenAI-compatible `/models` endpoint. This prevents valid chat-only or minimal providers from being configured and makes a failed verification indistinguishable from an unsaved credential.

## Current state

- `AISettingsViewModel.swift:224+` runs verify-and-save; `persistAPIKey` is called only in the success branch.
- `AISettingsViewModel.swift:289+` fetches models automatically after successful verification.
- `LLMService.swift:50+` decodes provider model catalogs and `:70+` builds `/models` requests for `.custom`.
- Keychain persistence uses `KeychainManager`; do not introduce another credential store.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| AI settings tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'AISettingsViewModelTests|KeychainManagerProviderKeyTests|KeychainManagerBatchRetrievalTests'` | exit 0 |
| Security/storage tests | `make test-sensitive` | exit 0 or baseline classified |
| Build/lint | `make build-agent && make lint` | exit 0 |
| Full gate | `make build-test` | exit 0, baseline classified |

## Scope

**In scope**:

- `AISettingsViewModel` and its existing provider setup state.
- `LLMService` request/verification policy for custom providers.
- Localized UI copy and tests for saved/unverified, verified, invalid, and catalog-unavailable states.
- Existing Keychain tests and focused AI settings tests.
- `plans/README.md`

**Out of scope**:

- Storing credentials outside Keychain.
- Provider-specific behavior changes for OpenAI, Groq, Anthropic, or Google unless regression tests require a compatibility fix.
- Automatic network retries or a general provider plugin architecture.

## Steps

### Step 1: Define explicit provider states

Separate `saved`, `verified`, `verificationFailed`, and `catalogUnavailable` state. Add an explicit “save without verification” path with clear localized warning, while preserving verify-and-save as the recommended action. The path must never log or display the key.

**Verify**: ViewModel tests cover every state and Keychain tests prove the same provider-scoped key is used.

### Step 2: Make model catalog optional for custom providers

Allow custom providers to opt into manual model entry or a configured verification strategy when `/models` is absent. Keep catalog fetch separate from credential verification. Preserve existing provider request contracts.

**Verify**: tests cover `/models` success, `/models` unavailable with manual model, invalid credentials, and regressions for built-in providers.

### Step 3: Review security and behavior

Run thermo review with `keychain-security` guidance. Check accidental secret capture in errors/logs, provider switching, stale state, cancellation, and UI copy. Correct all Critical/Medium findings.

**Verify**: review has no unresolved Critical/Medium findings; `make test-sensitive` passes.

### Step 4: Run full gates

Run `make build-agent`, `make lint`, and `make build-test`, then update the ledger and issues #63/#65 with the final state.

**Verify**: all results are recorded and no secret value appears in diffs, logs, tests, or issue comments.

## Validation evidence

- Focused AI settings and Keychain tests: 30 passed.
- `make preview-check`: passed.
- `make build-agent`: passed.
- `make test-sensitive`: the 7 storage-security tests passed; 6 `RecordingManagerTests` readiness assertions fail only in the combined sensitive suite and pass when isolated, so this remains baseline suite interference.
- `make lint`: completed with the repository baseline of 366/503 files requiring formatting and 286 warnings; touched files pass focused SwiftFormat/SwiftLint.
- `make build-test`: build passed; 989 tests ran with the known 16 `MetricsDashboardViewModelTests` baseline failures.
- Thermo/security review: no unresolved Critical or Medium findings; no secret value was added to logs, diffs, or issue comments.

## Done criteria

- [x] Users can explicitly save a provider key without verification.
- [x] Saved and verified states are distinct and localized.
- [x] Custom providers can operate without a mandatory `/models` endpoint.
- [x] Built-in provider behavior remains covered and unchanged.
- [x] Keychain tests pass; the six unrelated combined-suite readiness failures are classified as baseline interference.
- [x] Thermo/security review has no unresolved Critical/Medium findings.
- [x] Full gates and issue updates are recorded.
- [x] `plans/README.md` status row updated.

## STOP conditions

- The proposed flow would require displaying or persisting a secret outside Keychain.
- Provider-specific behavior cannot be separated without changing public domain contracts.
- A test or log captures credential material; stop, remove it, and report the exposure.

## Maintenance notes

Keep credential state and model catalog state separate. Future providers should declare verification/catalog capability rather than relying on a growing `switch` in UI code.
