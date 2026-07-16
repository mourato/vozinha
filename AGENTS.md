# AGENTS.md - Prisma Development Guide

## Identity and Purpose

Prisma is a local-first macOS meeting capture, transcription, and AI post-processing app. Use this repository's CLI-first workflow and Clean Architecture boundaries to make focused, reproducible changes.

## Project Context

- macOS 15+ is the minimum target; macOS 26 APIs need `#available(macOS 26, *)` guards with macOS 15 fallbacks; macOS 27 is preview-only.
- Swift 6.2+ with strict concurrency; default actor isolation is nonisolated — keep actor boundaries and `Sendable` reasoning explicit.
- SwiftUI-first UI with AppKit for status items, panels, lifecycle, and permissions SwiftUI cannot express reliably.
- New SwiftUI state prefers Observation; preserve `ObservableObject` until an intentional migration is verified.
- `Packages/MeetingAssistantCore/Sources/` uses short dirs: `Common`, `Domain`, `Infrastructure`, `Data`, `Audio`, `AI`, `UI`, `Core`, `Mocking`, `MockingMacros`.
- Public SwiftPM targets remain `MeetingAssistantCore*`; physical paths and public imports differ.
- Colocate types (`Services/RecordingManager/RecordingManager.swift`); no `Type+Concern.swift` filenames.

Module ownership: `Common`, `Domain`, `Infrastructure`, `Data`, `Audio`, `AI`, `UI`, `Core` — utilities, entities, adapters, persistence, capture, transcription, presentation, exports respectively.

## Non-Negotiable Rules

- Prefer correctness and safety over convenience; remove avoidable complexity.
- Before coding, follow `reuse → extend → create`; no copied implementations or speculative abstractions.
- Classify risk using the matrix below; when uncertain, choose the higher level.
- Clarify ambiguity that changes behavior, safety, architecture, or acceptance criteria.
- Never commit knowingly broken code. Use Conventional Commits: `<type>(<scope>): <summary>`.
- User-facing strings use `"key".localized`; remove orphaned keys when text is deleted.
- Never hardcode secrets; use Keychain and avoid logging tokens, transcripts, or PII.
- Do not stack redundant UI copy in one viewport.
- `modelResidencyTimeout` applies to every local model; new models need registry entries and unload hooks.
- Prefer files ≤600 lines; split by owning type and concern.
- Prefer structured concurrency and `Task.sleep(for:)`; justify `Task.detached` and `DispatchQueue` use.

## Git Safety

- Preserve unrelated worktree changes.
- Do not use destructive commands such as `git reset --hard` or `git checkout --` without explicit authorization.
- Do not rewrite shared history without explicit authorization.

## Policy Precedence

When guidance conflicts, apply this order:

1. This `AGENTS.md`.
2. The relevant project skill in `.agents/skills/` or global skill plus the project overlay named here.
3. Reference documents, examples, and inline comments.

Hard constraints in this file always override convenience or performance preferences. If a conflict remains material, stop and ask before implementing behavior.

## Deviations and Exceptions

If a task would violate a hard constraint or needs an exceptional workflow: stop, capture a minimal repro, record constraint/reason/scope/impact/rollback/expiry, track in GitHub (`known-limitation` or `needs-review`), update this file or the owning skill, and obtain reviewer sign-off before merge. Do not silently bypass gates, security rules, architectural boundaries, or data-integrity protections.

## Risk and Delivery Lanes

| Risk | Triggers | Lane |
|---|---|---|
| Low | Docs/comments, localization, or non-functional refactor in one module | Fast |
| Medium | One-subsystem feature/bugfix, one-package public API, or UI state logic without High triggers | Full |
| High | Audio, concurrency, persistence, security, cross-module architecture, build/release infrastructure, 300+ added lines, or more than 8 source files | Full |

Lane recipes, technical validation gates, and evidence contracts live in `delivery-workflow`. Full-lane review uses the thermo-nuclear semaforo: fix all Critical and Medium findings before merge.

## Delegation

Keep simple search, explanation, bounded diff review, and small deterministic changes in the root session. Delegate only broad work with independent questions; start with one explorer and add children only for distinct parallel tracks. At most one writing agent in an isolated worktree. Allowlisted Low/Fast deterministic work defaults to `implementer-fast`; all other routing, lean-code policy, and model identifiers are owned by `delivery-workflow` and global Codex config — not this file.

Every implementation plan must include an `Execution profile`; reclassify against live scope before implementation.

## Agent Validation Loop

`make validate-agent` is the remembered technical validation gate; it proves
checks, not merge approval. End-of-task: strict lint on any Swift delta, then
affected-module `validate-agent --lane auto` when behavior changes. Commit
(pre-commit applies staged format/lint-fix); pre-push then validates or reuses
the exact committed range. Guidance-only ranges run `guidance-check` without
product tests. Do not stack manual working-tree, staged, and committed gates;
required review remains separate. Details live in `delivery-workflow`.

## Commands and Routing

`Makefile` is the command authority. See [Build and Test Reference](./.agents/docs/build-and-test.md) for the command catalog. Route specialists via [Skill Routing Guide](./.agents/docs/skill-routing.md) only. `.swiftlint.yml` is the lint source of truth; keep lint-specific writing rules in `swift-conventions`.

For external project code or documentation, prefer `MCP grep`, then `gh`, then DeepWiki, and use web search last. Route new knowledge into `.agents/skills/`, GitHub issues, or delete stale material. Do not create a root-level `docs/` directory. Run `make guidance-check` after changing this file, `.agents/`, or referenced command documentation.

## Security and Privacy

Apply least privilege to entitlements and integrations. Validate external input at module boundaries. Keep credentials in Keychain. Do not persist or emit full transcripts, prompts, responses, or secrets in diagnostics or agent result artifacts.

## Self-Check Before Handoff

- Reuse/extend/create was considered; risk and lane are recorded.
- Relevant scoped checks and required lane gates were run via `validate-agent`.
- No hard constraint was violated; change is in the correct module boundary.
- Evidence includes commands, results, assumptions, and known baseline failures.
