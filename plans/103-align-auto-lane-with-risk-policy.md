# Plan 103: Make auto lane conservative for product Swift changes

> **Executor instructions**: Execute only after plan 102 is DONE. Follow each
> step and run its verification before continuing. Do not invent semantic diff
> analysis. If a STOP condition occurs, stop and report instead of weakening a
> Full trigger. Update this plan's row in `plans/README.md` when complete.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat fa93d031..HEAD -- \
>   scripts/scope-check.sh \
>   scripts/validate-agent.sh \
>   scripts/config/test-target-mapping.conf \
>   scripts/tests/workflow-test.sh \
>   AGENTS.md \
>   .agents/skills/delivery-workflow \
>   .agents/docs/build-and-test.md \
>   plans/README.md
> ```
>
> Plan 102 is expected to change several paths above. Compare live code with
> both plan 102's completed behavior and the current-state excerpts here. STOP
> only for incompatible drift, not for the expected plan 102 implementation.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: `plans/102-close-fast-validation-gate.md`
- **Category**: correctness
- **Planned at**: commit `fa93d031`, 2026-07-16

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no` — classification, execution, fixtures, and policy must change atomically
- **Reviewer required**: `yes` — under-classifying Medium/High work is merge-blocking
- **Rationale**: This changes validation infrastructure and the risk decision for every Swift change.
- **Escalate when**: The implementation proposes parsing Swift semantics, commit messages, prompts, Git notes, or agent-authored risk metadata.

## Why this matters

The policy says one-subsystem features, bug fixes, public APIs, and UI state
logic are Medium/Full. The automatic classifier cannot infer those semantics;
it currently chooses Fast unless path, size, module count, or test mapping
triggers Full. Real UI behavior commits have therefore selected Fast.

The safe and simple rule is: automatic classification treats production Swift
as Full because it cannot prove the change is non-functional. Fast automatic
validation remains available for guidance, localization/non-code, and
test-only changes with trustworthy mappings. This intentionally prefers a
false-positive Full over a false-negative Fast, matching `AGENTS.md`.

## Current state

### Policy

`AGENTS.md:55-59`:

```markdown
| Low | Docs/comments, localization, or non-functional refactor in one module | Fast |
| Medium | One-subsystem feature/bugfix, one-package public API, or UI state logic | Full |
| High | Audio, concurrency, persistence, security, cross-module architecture, ... | Full |
```

`AGENTS.md:23` also says uncertainty chooses the higher level.

### Classifier

`scripts/scope-check.sh:315-336` only recognizes infrastructure and a narrow
set of High-risk path patterns. `main` then escalates for multiple modules,
more than 300 added lines, more than eight Swift files, missing test mapping,
or forced Full.

There is no condition for ordinary production Swift. A replay of UI behavior
commit `c2fc714a` selected:

```text
selectedLane=fast
strategy=intermediate-gate
Candidate targeted tests: 33
```

The plan for that change explicitly classified it `Medium/Full`.

### Test mapping cost

`map_tokens_from_changed_file` adds a grandparent token for generic directories
such as `components`. For a settings component, that token is `settings`.
`build_targeted_test_candidates` then fuzzy-matches every `*Settings*Tests`
file, which mapped 33 tests for `c2fc714a`. This work occurs even when an
existing structural reason already requires Full.

## Target classification contract

Apply rules in this order:

1. Existing High/Full triggers remain Full: infrastructure, Audio, Data,
   security/Keychain/concurrency paths, cross-module, large delta, and high
   source-file count.
2. Any changed production Swift under either path is Full in `auto`:
   - `App/**/*.swift`
   - `Packages/MeetingAssistantCore/Sources/**/*.swift`
3. Swift under `Packages/MeetingAssistantCore/Tests/**` is not production source
   and may stay Fast when an exact/configured test mapping exists and no other
   Full trigger applies.
4. Guidance/non-code behavior implemented by plan 102 stays Fast and runs its
   dedicated check.
5. Localization/resources stay Fast unless another changed path triggers Full.
6. `--force-full` remains Full.
7. Do not claim that path heuristics can prove a production change is a
   non-functional refactor. Such a change is conservatively Full at final
   committed validation.
8. If a Full reason is already known, do not build fuzzy targeted-test
   candidates merely to choose the lane.

This plan does not add a “trust me, low risk” flag. A future exception mechanism
would need a separately designed, commit-bound and reviewable contract.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Shell syntax | `bash -n scripts/scope-check.sh scripts/validate-agent.sh scripts/tests/workflow-test.sh` | exit 0 |
| Workflow fixtures | `make workflow-test` | `WORKFLOW_TEST_STATUS=PASS` |
| Real UI replay | `./scripts/scope-check.sh --dry-run --agent --committed --base c2fc714a^ --head c2fc714a` | decision JSON has `selectedLane=full` |
| Guidance | `make guidance-check` | exit 0 |
| Full gate | `make validate-agent ARGS="--lane full --no-reuse --agent"` | `AGENT_STATUS=PASS` |
| Diff hygiene | `git diff --check` | no output |

## Suggested executor toolkit

- Use `delivery-workflow` for the risk matrix and validation contract.
- Use existing shell fixtures; do not use product files as mutable fixtures.
- Prefer explicit path predicates and fixture repositories over natural-language heuristics.

## Scope

**In scope**:

- `scripts/scope-check.sh`
- `scripts/validate-agent.sh` only if aggregate selected-lane reporting must be aligned with child escalation
- `scripts/config/test-target-mapping.conf` only to remove a proven broad mapping or add an exact fixture-supported mapping
- `scripts/tests/workflow-test.sh`
- `AGENTS.md` only for a short statement that `auto` is conservative
- `.agents/skills/delivery-workflow/SKILL.md`
- `.agents/skills/delivery-workflow/references/delivery-workflow-details.md`
- `.agents/docs/build-and-test.md`
- `plans/README.md`

**Out of scope**:

- Parsing Swift ASTs or diffs to guess “behavior change”
- Commit trailers, Git notes, databases, signed receipts, or prompt-derived risk
- Weakening existing High triggers
- Changing Full-lane commands
- Redesigning all targeted-test mappings
- Changing hook exact-range behavior from plan 102
- Product Swift changes

## Git workflow

- Work in an explicitly isolated worktree.
- Suggested branch: `fix/103-conservative-auto-lane`
- Suggested commits:
  1. `fix(workflow): classify product Swift as Full in auto lane`
  2. `test(workflow): cover semantic-risk classification boundaries`
  3. `docs(delivery): document conservative auto-lane semantics`
- Do not push or open a PR unless requested.

## Steps

### Step 1: Separate production-source count from all Swift files

Add a small predicate such as `is_product_swift_path` in
`scripts/scope-check.sh`. It must match only:

```text
App/*.swift and descendants
Packages/MeetingAssistantCore/Sources/*.swift and descendants
```

Use a `product_source_files_changed` counter. Do not count tests as product
source for the `>8 source files` rule. Preserve a separate all-Swift count only
if output/tests need it; name it truthfully.

For every production Swift path, append one deduplicated Full reason such as:

```text
Production Swift changed; auto lane is conservative because semantic Low risk cannot be proven
```

Do not emit one reason per file.

**Verify**:

```bash
bash -n scripts/scope-check.sh
./scripts/scope-check.sh --dry-run --agent --committed --base c2fc714a^ --head c2fc714a
```

Expected: `selectedLane=full`, one conservative production-Swift reason, no
33-test candidate expansion.

### Step 2: Short-circuit targeted mapping after Full is known

Reorder `main` without changing check contents:

1. Collect files and structural Full reasons.
2. Compute counts and finalize whether Full is already required.
3. If Full, set the decision and skip `build_targeted_test_candidates`.
4. If not Full and code-relevant, build candidates and apply the existing
   missing/too-many mapping logic.
5. Execute lint plus the selected gate exactly once.

Keep decision JSON valid. For Full caused before mapping, `targetedTests` may be
an empty array and `Candidate targeted tests` must truthfully print `0` or
`not evaluated (Full already required)`; choose one representation and test it.

**Verify**: the `c2fc714a` replay has no list of generic Settings tests and
still selects Full.

### Step 3: Add classification boundary fixtures

Extend `scripts/tests/workflow-test.sh` with separate, named tests:

- one `App/Feature.swift` change → Full;
- one `Packages/MeetingAssistantCore/Sources/UI/Feature.swift` change → Full;
- one public-looking Domain source change → Full without parsing `public`;
- one `Packages/.../Tests/.../AlphaTests.swift`-only change → Fast when mapped;
- nine test files do not trigger the product-source-count rule;
- guidance-only → Fast plus guidance command from plan 102;
- localization/resource-only → Fast/no product build unless an existing
  specialized check says otherwise;
- `scripts/*`, Audio, Data, and cross-module cases remain Full;
- `--force-full` remains Full.

Use temporary fixture repos. Do not edit real product files in tests.

**Verify**: `make workflow-test` → `WORKFLOW_TEST_STATUS=PASS`.

### Step 4: Align aggregate reporting if requested Fast can internally escalate

Inspect the live plan-102 result before editing `validate-agent.sh`. If a
requested/selected Fast aggregate can contain a child `scope-check` decision of
Full, make the outer result fail closed or report Full consistently. Preferred
behavior: final `decision.selectedLane` must equal the strongest executed child
lane.

Do not add a second risk classifier to `validate-agent.sh`; consume the existing
scope decision. If plan 102 already guarantees consistency, leave this file
unchanged and record that fact in the handoff.

**Verify**: fixture JSON never says outer Fast when `build-test` ran as Full.

### Step 5: Update policy wording without duplicating implementation details

Add one concise rule to `AGENTS.md`/`delivery-workflow`:

> Automatic committed-range classification is conservative: production Swift
> is Full because scripts cannot prove a semantic Low/non-functional change.

Keep exact path lists and troubleshooting in `build-and-test.md` or the routed
delivery reference, not in all three documents. Remove any claim that `auto`
detects UI state, public API, bugfix, or non-functional semantics.

**Verify**: `make guidance-check` → pass.

### Step 6: Run final validation once

```bash
bash -n scripts/scope-check.sh scripts/validate-agent.sh scripts/tests/workflow-test.sh
make workflow-test
make guidance-check
git diff --check
make validate-agent ARGS="--lane full --no-reuse --agent"
```

Expected: all exit 0; final aggregate reports `AGENT_STATUS=PASS`.

## Test plan

- Keep all classification tests in `scripts/tests/workflow-test.sh` unless the
  file becomes materially less readable; only then extract
  `scripts/tests/scope-classification-test.sh` and invoke it from workflow-test.
- Use exact JSON assertions for `decision.selectedLane`, `strategy`, and reasons.
- Assert both positive and negative boundaries: product source Full, test-only
  Fast, no generic Settings test explosion, High triggers preserved.
- Re-run the historical `c2fc714a` range read-only as an integration smoke.

## Done criteria

- [ ] Every production Swift change selects Full in `--lane auto`.
- [ ] Test-only Swift is not counted as production source.
- [ ] Existing High triggers remain Full.
- [ ] Full decisions skip unnecessary fuzzy test-candidate construction.
- [ ] `c2fc714a` replays as Full with no 33-test expansion.
- [ ] Outer and child result JSON cannot disagree on the strongest executed lane.
- [ ] Guidance accurately describes conservative semantics.
- [ ] Workflow, guidance, diff, and one Full validation pass.
- [ ] Only in-scope files changed and ledger row is updated.

## STOP conditions

Stop and report if:

- The requested behavior would require determining semantic intent from source text.
- Product Swift cannot be distinguished from tests using stable repository paths.
- Keeping test-only Fast would weaken Audio/Data/security/concurrency triggers.
- The only proposed solution adds commit metadata or persistent state.
- Plan 102 has not landed or its exact-range Fast gate is failing.
- A verification fails twice after a focused correction.

## Maintenance notes

- This conservative default may increase Full runs. Measure actual duration and
  cache reuse after landing; do not weaken correctness based on anecdote.
- A future Low-risk Swift exception needs a separate design with auditability
  across local validation and the exact pushed range.
- Reviewers should verify path patterns against the current short module layout.
- The targeted mapper remains an iteration/test-only aid, not a semantic risk classifier.
