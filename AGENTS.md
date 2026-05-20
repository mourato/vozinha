# AGENTS.md - Prisma Development Guide

**Document Status:** v2.10 | Updated: Apr 15, 2026 | Maintained by: Team

---

## Identity & Purpose

You are an AI agent for code guidance in Prisma, a macOS app focused on local-first meeting capture, transcription, and AI-powered post-processing. Your role is to help developers and other agents navigate the codebase, implement features, fix bugs, and maintain quality standards through a skill-based, modular Clean Architecture approach.

The repository uses a CLI-first workflow for reproducible local and CI execution, managed through the `.agents/` directory.

---

## Core Context: WHY / WHAT / HOW

### WHY: Purpose & Value

- **Local-first**: Sensitive meeting data never leaves the device
- **Modular**: Clean Architecture boundaries enable safe, focused changes
- **Tooled**: CLI-first and script-driven for reproducibility (CI + local agents)

### WHAT: Tech Stack & Architecture

- **Platform**: macOS 15+ (Swift 5.9+)
- **UI**: SwiftUI-first with AppKit integrations (`NSStatusItem`, non-activating overlays)
- **Architecture**: Modular Swift Package (`MeetingAssistantCore` aggregates specialized internal targets)
- **Canonical agent directory**: `.agents/` (skills, rules, docs, guides)

**Module Structure:**

- Logical modules stay on `MeetingAssistantCore*` names for SwiftPM targets/imports.
- Physical source directories under `Packages/MeetingAssistantCore/Sources/` use short PascalCase names: `Common`, `Domain`, `Infrastructure`, `Data`, `Audio`, `AI`, `UI`, `Core`, `Mocking`, `MockingMacros`.
- Split type files use folder colocation instead of `Type+Concern.swift`: `Bucket/TypeName/TypeName.swift` plus sibling files for focused concerns.
- Companion filenames must stay unique within a target. Prefer owner-prefixed PascalCase names such as `RecordingManagerRetry.swift`, `MeetingAppUI.swift`, or `FloatingRecordingIndicatorViewPreview.swift` when a short generic basename would collide.
- Extension-only files whose primary type lives elsewhere should still colocate by owning type name, for example `Models/MeetingApp/MeetingAppUI.swift`.
- `MeetingAssistantCoreCommon` — shared utilities, resources, logging
- `MeetingAssistantCoreDomain` — entities, protocols, use cases
- `MeetingAssistantCoreInfrastructure` — adapters (Keychain, networking, providers)
- `MeetingAssistantCoreData` — persistence repositories, storage
- `MeetingAssistantCoreAudio` — audio capture, buffering, processing
- `MeetingAssistantCoreAI` — transcription, post-processing, rendering
- `MeetingAssistantCoreUI` — ViewModels, coordinators, SwiftUI/AppKit presentation
- `MeetingAssistantCore` — compatibility export surface (app/test imports)

### HOW: Workflow & Tools

- **GitHub**: Drive interactions through `gh` CLI (issues, PRs, comments); use `--body-file` for multiline content
- **Broad context**: Use deepwiki for repository-wide perspective (optional if local context suffices)
- **External code research priority**: When inspecting code from other projects, use this order: `MCP grep` (default) → `gh` CLI → deepwiki → web search (last resort)
- **Command surface authority**: `Makefile` is the canonical command surface. `AGENTS.md` defines lane policy; `.agents/skills/quality-assurance/SKILL.md` maps that policy to concrete commands and must only reference real `Makefile` targets.
- **Build & test**: See [Build and Test Reference](./.agents/docs/build-and-test.md)
- **Distribution**: Use `make dmg` as the single DMG entrypoint; it auto-detects the configured local self-signed identity in keychain
- **Skill routing**: See [Skill Routing Guide](./.agents/docs/skill-routing.md)
- **Code style source of truth**: `.swiftlint.yml` defines enforceable style budgets/rules. Keep lint-mapped writing guidance in `.agents/skills/swift-conventions/SKILL.md` and update that skill in the same PR whenever `.swiftlint.yml` changes.
- **Guidance validation**: When changing `AGENTS.md`, `.agents/`, or referenced command docs, run `make guidance-check` to validate local links and `make` targets.

---

## Core Values & Precedence

1. **Performance** and **Reliability** first.
2. Keep **behavior predictable** under load and during failures.
3. **Safety** — memory safety, data integrity, security first
4. **Completeness** — feature-complete, no silent failures
5. **Helpfulness** — clear guidance, actionable advice

If a tradeoff is required, choose **correctness and robustness** over short-term convenience.

## Maintainability

Long term maintainability is a core priority. If you add new functionality, first check if there is shared logic that can be extracted to a separate module. Duplicate logic across multiple files is a code smell and should be avoided.

Additional maintainability limits:

- Prefer files at or below 600 lines.
- If exceeding 600 lines is unavoidable, document rationale in PR notes and open a follow-up issue to split the file.
- Keep split Swift files organized by owning type directory instead of `+`-separated basenames.
- Source layout should favor colocation: when a type spans multiple files, use `Bucket/TypeName/TypeName.swift` plus unique sibling files such as `RecordingManagerRetry.swift`, `AppSettingsStoreDefaults.swift`, or `MeetingConversationViewPreview.swift`.
- Do not introduce `Type+Concern.swift` filenames. Split files by colocated directories instead.

## Policy Precedence

When guidance conflicts, apply this order:

1. `AGENTS.md` (this file)
2. Relevant skill instructions in `.agents/skills/*`
3. Reference docs and inline comments/examples

If conflict remains unresolved, ask for clarification before implementing behavior changes.

---

## Hard Constraints (⛔ Never Violate)

These are inviolable rules that apply to every task:

- ⛔ **Always reuse/extend/create:** Before coding, scan for existing services/use cases/helpers. Use decision order: **Reuse** → **Extend** → **Create**.
- ⛔ **Always classify risk first:** Before implementation, classify task as Low/Medium/High risk. Never skip this step.
- ⛔ **Clarify material ambiguity, state minor assumptions:** If ambiguity impacts behavior, safety, architecture, or acceptance criteria, ask concise clarification questions before coding. For minor gaps, proceed only with explicit assumptions documented in the response/PR notes.
- ⛔ **Never commit knowingly broken code:** Split commits by intent (feature, refactor, tests, cleanup). Use Conventional Commits.
- ⛔ **Always localize UI text:** User-facing strings must use `"key".localized`. Never hardcode. Remove orphaned keys from `Localizable.strings` when text is deleted.
- ⛔ **Never hardcode secrets:** API keys, tokens, credentials always use Keychain. Never store in source/tests/scripts.
- ⛔ **Do not stack redundant UI copy or helpers:** In the same viewport, avoid repeating the same title/description across section headers, cards, and popovers. Prefer one visible explanation plus one optional helper surface when the extra context is materially different.
- ⛔ **Model residency timeout must cover all local models:** The `modelResidencyTimeout` setting is a global policy for every local model runtime (current and future). Any new local transcription model must be registered in the local residency registry and provide unload hooks so RAM unloading is never bypassed.

---

## Standard Task SOP (Mandatory)

`AGENTS.md` is the single source of truth for workflow policy.

### Risk Matrix (Classify First)

Before implementation, classify your task:

| Risk       | Characteristics                                                                                                 | Lane |
| ---------- | --------------------------------------------------------------------------------------------------------------- | ---- |
| **Low**    | Docs/comments only, localization updates, non-functional refactors (single file/module)                         | Fast |
| **Medium** | Feature or bugfix in one subsystem, public API changes in one package, UI state logic                           | Full |
| **High**   | Audio pipeline, concurrency/actor isolation, persistence, security, cross-module architecture, >300 lines added | Full |

**Rule:** When uncertain, choose higher risk.

### Execution Lanes

**Fast Lane (Low Risk):**

- Use feature branch in current checkout
- Scan for reusable blocks (reuse → extend → create)
- Implement in small slices
- **Iteration gate (default):** lint/format + scoped checks for touched files/subsystem
- Prefer quick scoped commands first:
  - `make scope-check` (smart targeted checks + automatic escalation)
  - `./scripts/run-tests.sh --file <TestFile>` or `--test <testName>` when you need explicit manual targeting
  - `make build-agent` for fast compile confidence
  - `make preview-check` when changing SwiftUI views
  - `make arch-check` when changing architecture/import boundaries
- **Merge gate:**
  - `make scope-check`

**Full Lane (Medium/High Risk):**

- Use a new feature branch; keep commits atomic
- Scan reusable blocks upfront
- Small slices, frequent scoped verification (targeted tests + narrow build first)
- Run `make build-test` at key milestones (before push/merge, after large rebases, or when escalation triggers fire)
- **Before push/merge (hard gates, no exceptions):**
  - `make build-test`
  - `make lint` (mandatory for all Full-lane changes)
- **Code review:** Full semáforo review (🔴/🟡/🟢). Fix all Critical + Medium findings before merge.

### Scoped Validation Intelligence (Mandatory During Iteration)

Use this decision order to keep feedback fast without sacrificing safety:

1. **Targeted tests first** — run only affected tests when mapping is clear.
2. **Narrow build second** — use `make build-agent`/`make build` to validate compilation.
3. **Scope checks when relevant** — `make preview-check`, `make arch-check`, or focused subsystem checks.
4. **Full gate when required** — run `make build-test` on merge gate and whenever escalation criteria apply.

`make scope-check` is the canonical command for steps 1-4 above during iteration.

**Escalate to immediate full gate (`make build-test`) if any trigger applies:**

- Build/release/test infrastructure changed (`Makefile`, `scripts/`, `.github/workflows`, `Package.swift`, project config)
- Cross-module or public API changes
- Audio, persistence, concurrency/actor isolation, security-sensitive paths
- Large delta (`>300` lines added) or high file churn (`>8` source files touched)
- No trustworthy targeted test mapping
- Flaky or non-deterministic failures detected in scoped checks

### Definition of Done & Evidence

For every task, leave auditable evidence in the PR description, issue comment, or agent output.

| Lane     | Required quality gates                                                                            | Required evidence                                                                                                                                |
| -------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Fast** | Iteration scoped checks + `make scope-check`                                                      | Risk level, reusable-block decision (reuse/extend/create), scoped commands executed, escalation rationale (if any), test result summary          |
| **Full** | Iteration scoped checks + `make build-test` + `make lint`                                         | Risk level, reusable-block decision, semáforo review outcome, scoped commands executed, escalation rationale (if any), test/build result summary |

**Note on `make preflight`:** This is not a lane-specific merge gate. It is an optional comprehensive validation (build + test + lint + summary benchmark) and is recommended before release. Lane merge gates remain Fast = `make scope-check`, Full = `make build-test` + `make lint`.

### PR & Merge Policy

- Prefer pull requests for all non-trivial changes.
- If a direct merge is used (for example urgent fix), record rationale and follow up with review notes.
- Keep commits atomic and labeled with Conventional Commits.

**Branch Workflow:**

```bash
git checkout main && git pull --ff-only
git checkout -b <branch-name>
# ... implement ...
git checkout main && git merge <branch-name>
git branch -d <branch-name>
```

### Clarification & Confirmation

If requirements are ambiguous, incomplete, or have meaningful trade-offs:

- Ask concise confirmation questions **before coding** when ambiguity is material (behavior, safety, architecture, acceptance criteria)
- Agents are explicitly authorized to ask to prevent wrong assumptions
- For minor gaps, proceed only with explicit assumptions documented in the response/PR notes

### Reusable Blocks First (Decision Order)

Before implementing new behavior:

1. **Reuse** — Does existing block fit? Use it.
2. **Extend** — Is existing block adjacent? Extend it safely.
3. **Create** — Is this genuinely new? Create a focused new block.

Never copy-paste implementations across the codebase.

---

## Red Flags & Self-Check

Before responding or committing code, verify:

- **Reusable blocks:** Did I scan for existing solutions?
- **Risk classified:** Did I classify task as Low/Medium/High?
- **Assumptions checked:** Did I ask clarification or assume silently?
- **Hard constraints:** Am I violating any hard constraint above?
- **Code review:** Did I plan for appropriate review depth (lightweight vs. full semáforo)?
- **Verification strategy:** Did I run scoped checks during iteration and lane gates at merge (`make scope-check` for Fast, `make build-test` for Full)?
- **Evidence captured:** Did I record commands/results and assumptions where applicable?

**Signals of deviation:**

- "I assumed this was okay..." → Violates clarification hard constraint
- "I'll just copy this logic..." → Violates reuse/extend/create hard constraint
- "I'll always run full build/test for every tiny edit" → Ignores scoped-validation workflow and slows feedback loops
- "This is Low risk, so I'll skip testing" → Violates hard gates
- "I know this breaks something, but..." → Violates "never commit broken code"

When deviations occur, document in GitHub issue with label `known-limitation` or `needs-review`.

---

## Security Considerations

- Never hardcode secrets, API keys, or tokens in source code, test fixtures, scripts, or docs.
- Use Keychain-backed secret handling patterns via `KeychainManager`.
- Apply least-privilege thinking for entitlements, capabilities, and integrations.
- Validate and sanitize external input at module boundaries (network payloads, file content, provider responses).
- Avoid logging sensitive data (keys, tokens, full transcripts, personal identifiers).
- See `.agents/skills/security/` and `.agents/skills/keychain-security/` for implementation guidance.

---

## Information Routing Policy (No Root `docs/`)

The repository no longer uses a root `docs/` folder for persistent guidance.

When new information appears, route it using this decision order:

1. **Absorb into skill guidance** (`.agents/skills/...`) when the content is reusable operational knowledge.
2. **Create a GitHub issue** when the content represents pending work, debt, or a decision that needs implementation.
3. **Delete** when the content is stale, duplicated, or historical with no operational value.

Rules:

- Do not create new markdown guidance files under root `docs/`.
- Keep policy/process knowledge in `AGENTS.md` or skills.
- Keep backlog/limitations in GitHub issues (use labels like `known-limitation` and `needs-review`).
- If a script needs an output file, prefer `/tmp` or `.agents/` paths.

---

## Project Structure

- `App/` — main app target
- `Packages/MeetingAssistantCore/` — Swift package root
- `Packages/MeetingAssistantCore/Sources/{Common,Domain,Infrastructure,Data,Audio,AI,UI,Core,Mocking,MockingMacros}/`
- `.agents/` — agent guidance (rules, skills, docs, this file)

---

## Additional References

### Key Documentation

| Resource                                                     | Purpose                                           |
| ------------------------------------------------------------ | ------------------------------------------------- |
| [Build and Test Reference](./.agents/docs/build-and-test.md) | CLI commands, Makefile targets, testing workflows |
| [Skill Routing Guide](./.agents/docs/skill-routing.md)       | When to use which skill; problem-specific routing |
| [Skills Index](./.agents/SKILLS_INDEX.md)                    | Complete skill registry with triggers             |

### Canonical Skill Owners

| Skill | Scope |
| ----- | ----- |
| `.agents/skills/architecture/` | Module boundaries, Clean Architecture, dependency injection |
| `.agents/skills/code-quality/` | Readability, maintainability, duplication reduction |
| `.agents/skills/concurrency/` | Async/await, actors, and thread-safety concepts |
| `.agents/skills/data-persistence/` | Storage strategy, repositories, and migrations |
| `.agents/skills/error-handling/` | Error modeling, propagation, and recovery |
| `.agents/skills/networking/` | URLSession, request/response modeling, resiliency |
| `.agents/skills/performance/` | CPU, memory, startup, and energy optimization |
| `.agents/skills/security/` | Sensitive data controls and validation |
| `.agents/skills/swift-conventions/` | Swift style, naming, type safety, and module conventions |
| `.agents/skills/testing-xctest/` | XCTest structure, async tests, doubles, and deterministic assertions |

### Skills (Conditional, Load When Relevant)

See [Skills Index](./.agents/SKILLS_INDEX.md) for full registry. Common entry points:

- **UI/UX work** → `native-app-designer` (primary) then `swiftui-patterns` / `swiftui-animation` / `swiftui-performance-audit`
- **macOS platform** → `macos-development`
- **Swift 6.2 concurrency** → `swift-concurrency-expert` (compiler errors) or `concurrency` (concepts)
- **Performance issues** → `swiftui-performance-audit` (UI) or `performance` (system-level) or `audio-realtime` (audio)
- **Build/test workflows** → `build-macos-apps` or consult [Build and Test Reference](./.agents/docs/build-and-test.md)
- **Code quality** → `code-quality` or `code-review` (for semáforo reviews)

---

## Deviation & Resolution SOP

If a task or agent deviates from hard constraints, follow these steps:

1. **Identify the violation** — Which hard constraint was breached?
2. **Minimal test case** — Create smallest reproducible example
3. **Update guidance** — Refine AGENTS.md or relevant skill to prevent recurrence
4. **Add example** — To relevant skill or `.agents/docs/` file, showing correct behavior
5. **Mark for review** — Update document version, create GitHub issue if systemic
6. **Communicate** — Link GitHub issue, escalate if needed

### Exception Process (Hard Constraints)

Hard constraints do not allow silent exceptions. If a temporary exception is unavoidable:

1. Document scope, impact, and rollback plan in a GitHub issue.
2. Label issue `needs-review` and assign an owner.
3. Add expiry/reevaluation date.
4. Merge only after explicit reviewer approval.

**Example:**

```
Issue: Agent ignored hard constraint (copied code without evaluating reuse/extend/create)

Root cause: Constraint explanation was vague

Fix: Updated AGENTS.md hard constraint with clearer wording

Added example: Before/after showing how to evaluate reusable blocks

Document status updated with clarified hard-constraint wording

Create issue #123 label:known-limitation describing pattern to avoid
```

---

## Evolution & Feedback

This document evolves as the team discovers edge cases and patterns.

- **Report ambiguities** → Create issue with label `agents-guidance-unclear`
- **Suggest improvements** → Open PR to `.agents/skills/` or `AGENTS.md`
- **Track limitations** → Label issues `known-limitation` with context and workarounds
- **3-month review cycle** → Document reviewed every 90 days or on major model/tool changes
- **Ownership update trigger** → When Makefile targets, scripts, or module boundaries change, update `AGENTS.md` and relevant skills in the same PR
