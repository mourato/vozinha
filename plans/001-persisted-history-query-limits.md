# Plan 001: Push transcription-history filtering and limits into persistence

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. When done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 48329a03..HEAD -- Packages/MeetingAssistantCore/Sources/Domain/Models/TranscriptionMetadata.swift Packages/MeetingAssistantCore/Sources/Data/Services/StorageService/RetentionCleanup.swift Packages/MeetingAssistantCore/Sources/UI/ViewModels/TranscriptionSettingsViewModel Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/TranscriptionSettingsViewModelTests.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/CoreDataRepositoryTests.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/Mocks.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `48329a03`, 2026-06-25

## Why this matters

Prisma is local-first, so transcription history can grow without a server-side retention boundary. The history view model currently loads every visible metadata row and then filters, groups, and builds app options on the main actor. The storage layer already has a query object and predicate builder, but the UI path still bypasses it for the main history load.

This plan makes the first scalable slice: add query limits/sort to persistence, use the query path from the transcription history view model, and keep a safe fallback where a filter cannot yet be represented in Core Data. It is not an FTS or `NSFetchedResultsController` migration.

## Current state

- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/TranscriptionSettingsViewModel/TranscriptionSettingsViewModel.swift:207` loads all metadata:

```swift
public func loadTranscriptions() async {
    isLoading = true
    loadErrorMessage = nil
    do {
        transcriptions = try await storage.loadAllMetadata().filter {
            $0.lifecycleState == .failed || !($0.duration == 0 && $0.previewText.isEmpty)
        }
```

- `Packages/MeetingAssistantCore/Sources/Data/Services/StorageService/RetentionCleanup.swift:126` has a query path, but no sort or limit:

```swift
func loadMetadata(matching query: TranscriptionMetadataQuery) async throws -> [TranscriptionMetadata] {
    await coreDataStack.sanitizeMockTranscriptionArtifactsIfNeeded()
    ...
    let request = TranscriptionMO.fetchRequest()
    request.fetchBatchSize = 100
    request.relationshipKeyPathsForPrefetching = ["meeting"]
    request.predicate = Self.buildMetadataPredicate(for: query)

    let results = try context.fetch(request)
    return results.map(Self.convertToMetadata)
}
```

- `Packages/MeetingAssistantCore/Sources/Domain/Models/TranscriptionMetadata.swift:177` defines the query shape:

```swift
public struct TranscriptionMetadataQuery: Hashable, Sendable {
    public let sourceFilter: RecordingSourceFilter
    public let dateFilter: DateFilter
    public let searchText: String
    public let appRawValue: String?
    public let includeNonVisibleLifecycleStates: Bool
```

- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/TranscriptionSettingsViewModel/TranscriptionHistoryFilterEngine.swift:25` applies source/date/app/search filtering in memory.
- Open issues #53, #97, and #98 already track broader storage/query performance, FRC, and text indexing. Keep this plan narrower.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Focused tests | `./scripts/run-tests.sh --file Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/TranscriptionSettingsViewModelTests.swift` | exit 0, all tests in file pass |
| Persistence tests | `./scripts/run-tests.sh --file Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/CoreDataRepositoryTests.swift` | exit 0, all tests in file pass |
| Build | `make build-agent` | exit 0 |
| Full-lane lint | `make lint` | exit 0 |

## Scope

**In scope**:
- `Packages/MeetingAssistantCore/Sources/Domain/Models/TranscriptionMetadata.swift`
- `Packages/MeetingAssistantCore/Sources/Data/Services/StorageService/RetentionCleanup.swift`
- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/TranscriptionSettingsViewModel/TranscriptionSettingsViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/TranscriptionSettingsViewModel/TranscriptionHistoryFilterEngine.swift` only if needed for query conversion helpers
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/TranscriptionSettingsViewModelTests.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/CoreDataRepositoryTests.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/Mocks.swift`

**Out of scope**:
- Do not implement FTS.
- Do not migrate to `NSFetchedResultsController`.
- Do not change model-performance analytics.
- Do not change persisted Core Data schema unless absolutely required; this plan should not need a model version bump.

## Git workflow

- Branch: `advisor/001-history-query-limits`
- Use Conventional Commits, for example: `perf(storage): bound transcription history metadata queries`
- Do not push or open a PR unless the operator instructs it.

## Steps

### Step 1: Add query limit and sort contract

Extend `TranscriptionMetadataQuery` with:

- `limit: Int? = nil`
- `sortNewestFirst: Bool = true`

Keep the initializer backward compatible by adding default arguments at the end. Update mock storage query tracking to store the full query.

**Verify**: `./scripts/run-tests.sh --file Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/TranscriptionSettingsViewModelTests.swift` -> existing tests compile and either pass or show only expected call-count failures from the next step.

### Step 2: Apply sort and limit in the storage query

In `RetentionCleanup.loadMetadata(matching:)`, after setting the predicate:

- set `request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: !query.sortNewestFirst)]`
- set `request.fetchLimit = max(limit, 0)` when `query.limit` is non-nil
- preserve `fetchBatchSize = 100` and relationship prefetching.

Add a `CoreDataRepositoryTests` case that saves three transcriptions with distinct `createdAt`, calls `loadMetadata(matching: TranscriptionMetadataQuery(limit: 2))`, and asserts two newest rows are returned.

**Verify**: `./scripts/run-tests.sh --file Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/CoreDataRepositoryTests.swift` -> all tests pass, including the new limit/sort case.

### Step 3: Route history loads through the query path

In `TranscriptionSettingsViewModel`, replace the unconditional `storage.loadAllMetadata()` in `loadTranscriptions()` with a helper that builds a `TranscriptionMetadataQuery` from current `sourceFilter`, `dateFilter`, `searchText`, and the selected raw app filter when the filter id uses the existing `raw:` prefix.

Use an initial/default limit constant, for example:

```swift
private enum HistoryLoadConstants {
    static let defaultMetadataLimit = 250
}
```

Keep the existing in-memory `TranscriptionHistoryFilterEngine.filteredTranscriptions(...)` as a correctness backstop. If the selected app filter uses bundle/name prefixes that the query cannot represent yet, fall back to `loadAllMetadata()` and add a test for that fallback.

**Verify**: `./scripts/run-tests.sh --file Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/TranscriptionSettingsViewModelTests.swift` -> all tests pass after updating expected storage call counts.

### Step 4: Add focused behavior tests

Add tests in `TranscriptionSettingsViewModelTests` that cover:

- initial load calls `loadMetadata(matching:)` with limit 250 instead of `loadAllMetadata()`
- source/date/search values are reflected in the query
- raw app filter is reflected in the query
- bundle/name app filters fall back to `loadAllMetadata()` until a persistence predicate exists for them
- failed empty history items remain visible

**Verify**: `./scripts/run-tests.sh --file Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/TranscriptionSettingsViewModelTests.swift` -> all tests pass.

### Step 5: Run compile and lint gates

This is a Medium-risk Full-lane change because it changes UI state loading behavior in one subsystem.

**Verify**: `make build-agent` -> exit 0.

**Verify**: `make lint` -> exit 0.

## Test plan

- Add one Core Data persistence test for query limit/sort.
- Add view-model tests for query construction and fallback.
- Preserve existing history filtering tests as the behavior baseline.

## Done criteria

- [ ] `TranscriptionMetadataQuery` supports `limit` and `sortNewestFirst` with default initializer values.
- [ ] Core Data metadata queries set sort descriptors and honor `fetchLimit`.
- [ ] `TranscriptionSettingsViewModel.loadTranscriptions()` no longer unconditionally calls `loadAllMetadata()`.
- [ ] Tests prove fallback behavior for app filters that are not yet queryable.
- [ ] `./scripts/run-tests.sh --file Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/TranscriptionSettingsViewModelTests.swift` exits 0.
- [ ] `./scripts/run-tests.sh --file Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/CoreDataRepositoryTests.swift` exits 0.
- [ ] `make build-agent` exits 0.
- [ ] `make lint` exits 0.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report back if:

- The current history UI depends on showing app filter options from the entire lifetime history, and a bounded query would remove required product behavior.
- Implementing app bundle/name persistence filters requires a Core Data schema migration.
- Tests reveal `loadAllMetadata()` is required by another visible history path that this plan did not include.
- Any verification command fails twice after a reasonable fix attempt.

## Maintenance notes

This plan is a first slice. Full text search (#98) and live incremental UI updates (#97) should remain separate work. Reviewers should check that bounded loading does not silently hide records in ordinary date/source/search flows.
