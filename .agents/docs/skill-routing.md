# Skill Routing Guide

When working on Prisma, multiple skills may be relevant to a task. This guide provides routing logic that keeps one canonical owner per domain and avoids instruction overlap.

## General Routing Priority

When uncertain which skill to use, apply this priority order:

1. **`macos-app-engineering`** — canonical macOS UI/app implementation guidance
2. **`delivery-workflow`** — source of truth for risk lane, validation, Git, and delivery evidence
3. **`accessibility-audit` / `localization` / `menubar`** — specialist UI escalation when their scope is primary
4. **`swift-concurrency-expert`** — Swift 6.2 concurrency remediation
5. **`debugging-diagnostics`** — cross-cutting investigation and diagnostic signal design when the failing subsystem is not yet proven

## External Project Code Lookup Priority

When inspecting code outside this repository, use this source order:

1. `MCP grep`
2. `gh` CLI
3. `deepwiki`
4. Web search

---

## Problem-Specific Routing

### Architecture and Boundaries

**Primary:** `architecture`
- Clean Architecture boundaries
- Dependency injection
- Cross-module ownership

**Complementary:** `macos-app-engineering` when architecture changes affect UI/app implementation details

**Example:** "Refactor meeting post-processing into a separate module" → `architecture`

---

### UI/UX and Interaction Work

**Start here:** `macos-app-engineering`
- Define UX acceptance criteria
- Implement SwiftUI/AppKit structure
- Apply Settings/design-system patterns
- Add or update previews

**Then (if needed):** `accessibility-audit`, `localization`, `menubar`, `debugging-diagnostics`, or `swift-concurrency-expert`

**Example:** "Design the meeting recording UI" → `macos-app-engineering`

---

### SwiftUI Performance Issues

**Primary:** `macos-app-engineering`
- Janky scrolling
- Layout thrash
- Excessive view updates

**Complementary:** `debugging-diagnostics` when the root cause is unclear

**Example:** "Scrolling in recording list is janky" → `macos-app-engineering` plus `debugging-diagnostics` if reproduction/diagnosis is needed

---

### Audio Capture and Processing

**Primary:** `audio-realtime`
- Audio glitches, underruns, dropout
- Low-latency callback optimization
- ProcessTap or AVAudioSourceNode work

**Example:** "Audio recording has glitches on M2" → `audio-realtime`

---

### Concurrency and Actor Isolation

**Primary:** `swift-concurrency-expert`

**Example:** "Actor-isolated property accessed from non-isolated context" → `swift-concurrency-expert`

---

### Code Quality and Refactoring

**Primary:** `code-quality`
- Readability and maintainability improvements
- Refactoring duplicated logic

**Complementary:** `swift-conventions`

Use `thermo-nuclear-code-quality-review` for review output, semaforo severity, and strict structural maintainability analysis.

**Example:** "Extract duplicate audio logic into a reusable service" → `code-quality`

---


### Debugging, Crashes, Flaky Behavior, and Diagnostics

**Primary:** `debugging-diagnostics`
- Unknown root cause investigation
- Crash analysis
- Flaky behavior
- `AppLogger` and `Logger`
- Structured event naming
- Payload redaction
- Failure signatures and metric correlation

**Complementary:** any subsystem skill that matches the narrowed scope

**Example:** "Crash on app quit when recording is active" → `debugging-diagnostics`
**Example:** "Add diagnostic logging around shortcut capture failures" → `debugging-diagnostics`

---

### Data Persistence, Storage, and Migrations

**Primary:** `data-persistence`
- Repositories
- Storage strategy
- Migrations and synchronization

**Example:** "Design storage strategy for meeting transcripts" → `data-persistence`

---

### Intelligence Kernel and Summary Quality

**Primary:** `intelligence-kernel`
- Kernel mode routing and feature flags
- Canonical summary schema and trust flags
- Summary benchmark thresholds and enforcement

**Complementary:** `data-persistence`, `delivery-workflow`

**Example:** "Adjust canonical summary confidence rules" → `intelligence-kernel`

---

### Security and Secret Management

**Primary:** `keychain-security`

**Example:** "Safely store API key for transcription service" → `keychain-security`

---


### Testing, Delivery, and Quality Gates

**Delivery workflow, verification policy, merge gates, and Git mechanics:** `delivery-workflow`

**XCTest implementation details:** `testing-xctest`

**Example:** "Add unit tests for TranscriptionService" → `testing-xctest`

---

### Localization and Accessibility

**Primary:** `localization`
- Localize UI text
- Manage locale-file hygiene
- Keep accessibility copy localizable

**Audit and interaction accessibility:** `accessibility-audit`

**Example:** "Add Portuguese (Brazil) localization" → `localization`

---

### Menu Bar and macOS Native UI

**Primary:** `menubar`
- NSStatusItem configuration
- NSMenu and NSPopover behavior
- Non-activating overlays

**Complementary:** `macos-app-engineering`

**Example:** "Implement menu-bar popover for recording controls" → `menubar`

---


### Repository Standards and Project Maintenance

**Primary:** `project-standards`
- Update `AGENTS.md`
- Document project policy
- Align repository standards

**Example:** "Update AGENTS.md to reflect new skill" → `project-standards`

---



## Skill Files and Direct Access

| Skill | File | When to use |
|-------|------|-------------|
| `accessibility-audit` | `.agents/skills/accessibility-audit/SKILL.md` | VoiceOver, focus order, keyboard navigation, reduced motion |
| `architecture` | `.agents/skills/architecture/SKILL.md` | Module boundaries, Clean Architecture, DI |
| `audio-realtime` | `.agents/skills/audio-realtime/SKILL.md` | AVAudioSourceNode, ProcessTap, underruns |
| `code-quality` | `.agents/skills/code-quality/SKILL.md` | Readability, refactoring |
| `data-persistence` | `.agents/skills/data-persistence/SKILL.md` | Storage design, migrations |
| `debugging-diagnostics` | `.agents/skills/debugging-diagnostics/SKILL.md` | Crash/flaky investigation, logs, telemetry, redaction, diagnostic signatures |
| `delivery-workflow` | `.agents/skills/delivery-workflow/SKILL.md` | Risk lanes, validation gates, Git workflow, PR/merge mechanics |
| `documentation` | `.agents/skills/documentation/SKILL.md` | DocC and API docs |
| `intelligence-kernel` | `.agents/skills/intelligence-kernel/SKILL.md` | Kernel modes and summary benchmark gates |
| `macos-app-engineering` | `.agents/skills/macos-app-engineering/SKILL.md` | macOS UI/app implementation, SwiftUI, AppKit bridging, Settings UI, previews |
| `menubar` | `.agents/skills/menubar/SKILL.md` | Menu bar, popover, and floating-panel behavior |
| `testing-xctest` | `.agents/skills/testing-xctest/SKILL.md` | XCTest code structure, mocks, async tests |
| `swift-concurrency-expert` | `.agents/skills/swift-concurrency-expert/SKILL.md` | Swift 6.2 actor isolation and Sendable fixes |
| `thermo-nuclear-code-quality-review` | `.agents/skills/thermo-nuclear-code-quality-review/SKILL.md` | Default code review, PR audits, semaforo output, and strict maintainability analysis |
