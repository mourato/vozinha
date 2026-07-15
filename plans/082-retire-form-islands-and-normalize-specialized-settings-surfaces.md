# Plan 082: Retire per-group Form islands and normalize specialized settings surfaces

> **Executor instructions**: Execute only after Plans 080 and 081 are DONE.
> This is the consolidation pass: remove transitional primitives, verify Modes,
> Activity, History, collections, and editors, and leave intentional non-Form
> surfaces explicit. Do not redesign dashboards or collection interactions.

> **Drift check (run first)**:
>
> ```bash
> git diff --stat a9a86350..HEAD -- \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsFormGroup.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsListGroup.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSGroup.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ActivitySettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/TranscriptionsSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModesSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorDetailView.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MetricsDashboardPages.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MetricsDashboardPerformanceComponents.swift \
>   plans/README.md
> ```

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: `plans/080-migrate-primary-settings-journeys-to-form-sections.md`, `plans/081-migrate-system-settings-hierarchy-to-form-sections.md`
- **Category**: tech-debt
- **Planned at**: commit `a9a86350`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no` — deletion and repo-wide caller audit require the earlier migrations to be stable.
- **Reviewer required**: `yes` — reviewer must confirm retained exceptions are intentional and no scalar settings were missed.
- **Rationale**: Repo-wide UI audit plus shared primitive deletion and specialized route verification.
- **Escalate when**: A remaining scalar group needs behavior changes, or more than eight source files require non-mechanical edits.

## Why this matters

After the route migrations, leaving `SettingsFormGroup` available would let the
same nested Form regression return. At the same time, forcing Activity
dashboards, transcription history, Modes lists, monitored apps/sites, provider
catalogs, dictionary rules, or permission status into Form rows would damage
their semantics. This plan removes the obsolete island primitive and makes the
remaining non-Form surfaces deliberate, fluid, and reviewable.

## Current state and retained exceptions

The following are not scalar settings Forms and should remain specialized:

- Activity analytics/dashboard and performance cards;
- transcription History list and conversation view;
- Modes list, trigger/app/site collections, and prompt collection;
- monitored apps/sites and integration collections;
- provider registration/model download/service status collections;
- dictionary rule list and permission status blocks.

`DictationStyleEditorDetailView.swift:123-190` already uses one grouped Form in
the 400 pt Modes drawer; keep that architecture and convert its content to
native Sections if any per-group wrappers remain. The fixed 400 pt width belongs
only to `SettingsSidePanel`, never main settings pages.

## Reuse -> extend -> create decision

- Reuse `SettingsScrollableContent` for retained dashboards/lists and Plan 079's
  Form owner for scalar editor content.
- Extend doc comments on `SettingsListGroup`/`DSGroup` to state that they are for
  composed collection/status/data surfaces, not ordinary scalar settings.
- Delete `SettingsFormGroup.swift` after `rg` proves zero production callers.
- Do not create a registry, protocol, source scanner, or second surface wrapper.

## Scope

**In scope**: shared primitives in the drift check; Activity/History/Modes files
only where width/scroll/background ownership is inconsistent; affected previews,
tests, plan/ledger status.

**Out of scope**: analytics layout/content, transcription data/conversation,
dictation-style persistence, triggers/runtime matching, search/filter behavior,
collection row redesign, global Settings chrome, 400 pt drawer geometry.

## Commands

```bash
rg -n 'SettingsFormGroup|Form \{' Packages/MeetingAssistantCore/Sources/UI/pages/settings Packages/MeetingAssistantCore/Sources/UI/components/settings --glob '*.swift'
swift test --package-path Packages/MeetingAssistantCore --filter 'ActivitySettingsNavigationStateTests|TranscriptionSettingsViewModelTests|SettingsSubpageNavigationStateTests|DictationStylesSettingsViewModelTests|AppSettingsDictationStylesTests|SettingsSearchIndexTests'
make preview-check
make build-agent
make lint-agent
git diff --check
make validate-agent ARGS="--lane full --no-reuse --agent"
```

Expected: no `SettingsFormGroup` caller/file remains; every remaining `Form` is
a page/editor owner rather than nested under `SettingsScrollableContent`; tests
and Full gate pass.

## Git workflow

- Branch/worktree: `refactor/082-retire-settings-form-islands` in one isolated worktree.
- Use atomic Conventional Commits: primitive retirement, Modes audit, then Activity/collection normalization.
- Do not push, merge, or open a PR unless instructed; preserve all unrelated changes.

## Steps

### Step 1: Produce the final container inventory

Classify every remaining `DSGroup`, `SettingsListGroup`, and `Form` occurrence
as scalar settings, collection, status, analytics, editor, or preview. Any
scalar occurrence is a missed migration: move it into the owning page Form
without broadening behavior.

**Verify**: reviewer can map every occurrence to one category and rejects any unexplained exception.

### Step 2: Remove the transitional island primitive

Delete `SettingsFormGroup.swift` only after zero callers. Remove obsolete
previews/comments and update shared primitive documentation. Do not hide a
missed caller behind a renamed equivalent.

**Verify**: `rg -n 'SettingsFormGroup' Packages/MeetingAssistantCore` returns no matches.

### Step 3: Normalize Modes

Confirm the list remains a collection surface and the drawer editor uses one
Form with native Sections, one scroll owner, visible labels, and full drawer
width. Preserve prompt child route, draft transaction, focus restoration,
Reduce Motion/Transparency, and 400 pt overlay width.

**Verify**: existing Modes normal/narrow/accessibility previews and focused tests pass.

### Step 4: Normalize Activity and History outer surfaces

Keep analytics cards and native lists. Correct only outer full-width/header/
gutter/background or nested-scroll inconsistencies. Do not turn filters,
heatmaps, charts, event details, history rows, or conversations into a Form.

**Verify**: root/history/performance/more-insights/event-detail previews show one scroll owner and no accidental centered outer surface.

### Step 5: Audit all retained collections

Confirm monitored apps/sites, integrations, providers/models/status, dictionary,
and permissions keep their interaction semantics while sharing full-width outer
guides. Remove redundant outer cards only if Plans 080/081 left them.

**Verify**: grep inventory and visual route matrix contain no unexplained scalar exception.

## Test plan

- Modes: list/editor/prompt route, draft save/cancel/delete, focus restoration,
  narrow/accessibility/reduced-effects previews.
- Activity: root/history/performance/more-insights/event-detail navigation and
  empty/populated/loading/error states without changing analytics behavior.
- Inventory regression: zero `SettingsFormGroup`; every remaining `Form` has a
  documented page/editor owner; every retained DS/list group has a semantic
  collection/status/data classification reviewed in the diff.

## Done criteria

- [ ] `SettingsFormGroup` is deleted with zero references.
- [ ] Every remaining Form is the sole page/editor scroll owner.
- [ ] Every remaining DS/list group has a documented collection/status/data reason.
- [ ] Main pages have no hard maximum width; Modes alone keeps its 400 pt panel.
- [ ] Activity/History/Modes behavior and tests are unchanged.
- [ ] Full gate and required review pass.

## STOP conditions

- Plans 080/081 are incomplete or still use `SettingsFormGroup`.
- Removing a card changes collection selection/edit/status behavior.
- Modes draft/navigation/runtime matching must change.
- Activity/History requires a product redesign rather than outer normalization.

## Maintenance notes

The durable review question is semantic: scalar configuration belongs in the
page Form; collection, status, analytics, and rich editors may use specialized
surfaces but must keep one scroll owner and fluid outer width.
