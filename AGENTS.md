# AGENTS.md - Prisma Development Guide

## Identity and Purpose

Vozinha is the display brand for this local-first macOS meeting capture, transcription, and AI post-processing app. Technical identifiers remain Prisma-stable by design. Use this repository's CLI-first workflow and Clean Architecture boundaries to make focused, reproducible changes.

## Project Context

- macOS 15+ is the minimum target; macOS 26 APIs need `#available(macOS 26, *)` guards with macOS 15 fallbacks; macOS 27 is preview-only.
- Swift 6.2+ with strict concurrency; default actor isolation is nonisolated — keep actor boundaries and `Sendable` reasoning explicit.
- SwiftUI-first UI with AppKit for status items, panels, lifecycle, and permissions SwiftUI cannot express reliably.
- New SwiftUI state prefers Observation; preserve `ObservableObject` until an intentional migration is verified.
- `Packages/MeetingAssistantCore/Sources/` uses short dirs: `Common`, `Domain`, `Infrastructure`, `Data`, `Audio`, `AI`, `UI`, `Core`, `Mocking`, `MockingMacros`.
- Public SwiftPM targets remain `MeetingAssistantCore*`; physical paths and public imports differ.
- Read [`docs/ui.md`](docs/ui.md) before changing user-facing UI. Update it
  when a reusable visual rule or invariant changes; use an ADR for durable
  rationale when the project has an ADR directory.
- Colocate types (`Services/RecordingManager/RecordingManager.swift`); no `Type+Concern.swift` filenames.

Module ownership: `Common`, `Domain`, `Infrastructure`, `Data`, `Audio`, `AI`, `UI`, `Core` — utilities, entities, adapters, persistence, capture, transcription, presentation, exports respectively.

## Non-Negotiable Rules

- User-facing strings use `"key".localized`; remove orphaned keys when text is deleted.
- Never hardcode secrets; use Keychain and avoid logging tokens, transcripts, or PII.
- `modelResidencyTimeout` applies to every local model; new models need registry entries and unload hooks.
- Prefer files ≤600 lines; split by owning type and concern.
- Prefer structured concurrency and `Task.sleep(for:)`; justify `Task.detached` and `DispatchQueue` use.

## Policy Precedence

When guidance conflicts, apply this order:

1. This `AGENTS.md`.
2. The relevant project skill in `.agents/skills/` or global skill plus the project overlay named here.
3. Reference documents, examples, and inline comments.

Global macOS skills use repository-local companion overlays. Load the global
skill first, then the matching overlay; the overlay supplies Prisma/Vozinha
facts only and never replaces global safety, privacy, or repository-integrity
rules.

| Global skill | Project overlay |
|---|---|
| `swiftui-accessibility-audit` | `.agents/overlays/swiftui-accessibility-audit.md` |
| `apple-design` | `.agents/overlays/apple-design.md` |
| `benchmarking` | `.agents/overlays/benchmarking.md` |
| `code-quality` | `.agents/overlays/code-quality.md` |
| `delivery-workflow` | `.agents/overlays/delivery-workflow.md` |
| `macos-app-engineering` | `.agents/overlays/macos-app-engineering.md` |
| `swift-conventions` | `.agents/overlays/swift-conventions.md` |

Clients without deterministic overlay composition must still read the overlay
as ordinary Markdown after loading its named global skill.

Project facts and hard constraints here override convenience preferences. Use the
global safety and repository-integrity rules for conflicts outside this file.

Use `delivery-workflow` for risk, lanes, validation, Git, and handoff evidence.
Vozinha-specific high-risk surfaces are audio, concurrency, persistence,
security, cross-module architecture, and release infrastructure.

## Delegation

Use global `agent-ops` for delegation and execution profiles. Keep simple or
serial work in the root session; any writing agent needs an isolated worktree.
Reclassify the execution profile against the live scope before implementation.

## Agent Validation Loop

`make validate-agent` is the project validation gate. Run `make lint` for any
Swift delta, then the affected-module validation when behavior changes.
`make guidance-check` covers guidance-only changes; merge review remains
separate. Swift 6.2/toolchain details live in
`.agents/docs/swift-6-2-agent-baseline.md`.

## Commands and Routing

`Makefile` is the command authority. See [Build and Test Reference](./.agents/docs/build-and-test.md) for the command catalog. Route specialists via [Skill Routing Guide](./.agents/docs/skill-routing.md) only. `.swiftlint.yml` is the lint source of truth; keep lint-specific writing rules in `swift-conventions`.

Run `make guidance-check` after changing this file, `.agents/`, or referenced
command documentation.

## Security and Privacy

Apply least privilege to entitlements and integrations. Validate external input at module boundaries. Keep credentials in Keychain. Do not persist or emit full transcripts, prompts, responses, or secrets in diagnostics or agent result artifacts.

## Completion

A task is complete when:

- The changed surface, risk/lane, and `reuse → extend → create` decision are recorded.
- Swift changes pass `make lint` and behavior changes pass `make validate-agent ARGS="--lane auto"`; guidance changes pass `make guidance-check`.
- The change stays within its module boundary and satisfies the relevant security/privacy constraints.
- The handoff records commands and results, assumptions, manual gates, and known baseline failures.
