# Skill Routing Guide

When working on Prisma, multiple skills may be relevant to a task. This guide provides routing logic that keeps one canonical owner per domain and avoids instruction overlap.

## General Routing Priority

When uncertain which skill to use, apply this priority order:

1. **`macos-development`** — canonical macOS and Swift implementation guidance
2. **`task-lifecycle`** — source of truth for risk lane and lifecycle phases
3. **`native-app-designer`** — primary UI and UX direction
4. **`swift-concurrency-expert`** — Swift 6.2 concurrency remediation
5. **`debugging-strategies`** — cross-cutting investigation when the failing subsystem is not yet proven

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

**Complementary:** `macos-development`

**Example:** "Refactor meeting post-processing into a separate module" → `architecture`

---

### UI/UX and Interaction Work

**Start here:** `native-app-designer`
- Define visual and motion direction
- Set UX acceptance criteria
- Analyze interface quality

**Then (if needed):** `swiftui-patterns` → `macos-development` → `menubar`

**Example:** "Design the meeting recording UI" → `native-app-designer`

---

### SwiftUI Performance Issues

**Primary:** `swiftui-patterns`
- Janky scrolling
- Layout thrash
- Excessive view updates

**Complementary:** `debugging-strategies` when the root cause is unclear

**Example:** "Scrolling in recording list is janky" → `swiftui-patterns` plus `debugging-strategies` if reproduction/diagnosis is needed

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

Use `code-review` for review output; it always includes `thermo-nuclear-code-quality-review` for structural maintainability analysis.

**Example:** "Extract duplicate audio logic into a reusable service" → `code-quality`

---


### Debugging, Crashes, and Flaky Behavior

**Primary:** `debugging-strategies`
- Unknown root cause investigation
- Crash analysis
- Flaky behavior

**Complementary:** `observability-diagnostics`, plus any subsystem skill that matches the narrowed scope

**Example:** "Crash on app quit when recording is active" → `debugging-strategies`

---

### Logging, Telemetry, and Diagnostics

**Primary:** `observability-diagnostics`
- `AppLogger` and `Logger`
- Structured event naming
- Payload redaction
- Failure signatures and metric correlation

**Example:** "Add diagnostic logging around shortcut capture failures" → `observability-diagnostics`

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

**Complementary:** `data-persistence`, `quality-assurance`

**Example:** "Adjust canonical summary confidence rules" → `intelligence-kernel`

---

### Security and Secret Management

**Primary:** `keychain-security`

**Example:** "Safely store API key for transcription service" → `keychain-security`

---


### Testing and Quality Assurance

**Verification policy and merge gates:** `quality-assurance`

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

**Complementary:** `native-app-designer`, `macos-development`

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
| `code-review` | `.agents/skills/code-review/SKILL.md` | Semáforo review with mandatory thermo-nuclear structural pass |
| `data-persistence` | `.agents/skills/data-persistence/SKILL.md` | Storage design, migrations |
| `debugging-strategies` | `.agents/skills/debugging-strategies/SKILL.md` | Crash and flaky investigation |
| `documentation` | `.agents/skills/documentation/SKILL.md` | DocC and API docs |
| `git-workflow` | `.agents/skills/git-workflow/SKILL.md` | Prisma branch, commit, PR, merge, cleanup, and gh body-file mechanics |
| `intelligence-kernel` | `.agents/skills/intelligence-kernel/SKILL.md` | Kernel modes and summary benchmark gates |
| `macos-development` | `.agents/skills/macos-development/SKILL.md` | Canonical macOS and Swift guidance |
| `menubar` | `.agents/skills/menubar/SKILL.md` | Menu bar, popover, and floating-panel behavior |
| `native-app-designer` | `.agents/skills/native-app-designer/SKILL.md` | UI and UX direction |
| `observability-diagnostics` | `.agents/skills/observability-diagnostics/SKILL.md` | Logs, telemetry, redaction, diagnostic signatures |
| `quality-assurance` | `.agents/skills/quality-assurance/SKILL.md` | Verification gates and command policy |
| `task-lifecycle` | `.agents/skills/task-lifecycle/SKILL.md` | Risk classification and lifecycle policy |
| `testing-xctest` | `.agents/skills/testing-xctest/SKILL.md` | XCTest code structure, mocks, async tests |
| `swift-concurrency-expert` | `.agents/skills/swift-concurrency-expert/SKILL.md` | Swift 6.2 actor isolation and Sendable fixes |
| `swiftui-patterns` | `.agents/skills/swiftui-patterns/SKILL.md` | View composition, state management, motion implementation, and SwiftUI performance hygiene |
