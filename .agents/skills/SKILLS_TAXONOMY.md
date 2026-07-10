# Skills Taxonomy Matrix

This matrix defines ownership, overlap, and action for all skills under `.agents/skills`.

| Skill | Theme | Owner | Scope | Overlap With | Action |
|---|---|---|---|---|---|
| accessibility-audit | SwiftUI/UI/UX | Canonical | Accessibility audit, keyboard navigation, focus order, reduced motion, overlay and panel accessibility | localization, macos-app-engineering, menubar | Keep; accessibility interaction owner |
| benchmarking | Meta-skills | Canonical | Reference project registry, clone policy, and inspiration-driven problem-solving for Prisma | architecture, macos-app-engineering, audio-realtime | Keep; reference project owner |
| architecture | macOS/Swift Core | Canonical | Clean Architecture, module boundaries, DI | macos-app-engineering | Keep; clarify architecture-only scope |
| audio-realtime | Runtime/Performance | Canonical | Low-latency audio pipeline and callback constraints | debugging-diagnostics | Keep; specialized runtime owner |
| code-quality | Quality/Engineering Flow | Canonical (generic) | Readability and maintainability principles | swift-conventions | Keep; non-language-specific quality owner |
| data-persistence | Security/Data | Canonical | Repository, storage, migration, and synchronization strategy | architecture | Keep |
| debugging-diagnostics | Runtime/Performance | Canonical | Cross-cutting investigation methodology, logging structure, telemetry naming, redaction, failure signatures, and metrics correlation | macos-app-engineering, audio-realtime, swift-concurrency-expert | Keep; investigation and diagnostics owner |
| delivery-workflow | Quality/Engineering Flow | Canonical | Risk classification, lifecycle sequencing, validation commands, merge gates, Git mechanics, and delivery evidence | testing-xctest, thermo-nuclear-code-quality-review | Keep; delivery owner |
| documentation | Quality/Engineering Flow | Canonical | DocC, docs structure, and research patterns | project-standards | Keep |
| improve | Meta-skills | Canonical | Read-only codebase audits, opportunity prioritization, roadmap advice, and handoff plan authoring | project-standards | Keep; advisory only |
| intelligence-kernel | Runtime/Performance | Canonical | Canonical summary schema, trust flags, and summary benchmark gates | delivery-workflow, data-persistence | Keep |
| keychain-security | Security/Data | Canonical (credentials) | Keychain credential persistence and APIs | — | Keep; credential owner |
| localization | Security/Data | Canonical | Localization, locale-file hygiene, and accessible copy | accessibility-audit, macos-app-engineering | Keep; not a full accessibility owner |
| macos-app-engineering | macOS/Swift Core, SwiftUI/UI/UX | Primary | macOS UI/app implementation, SwiftUI composition, AppKit bridging, Settings UI, design-system guidance, preview coverage, and lifecycle-sensitive UI behavior | accessibility-audit, localization, menubar, debugging-diagnostics, swift-concurrency-expert, code-quality, swift-conventions | Keep; single primary owner for ordinary macOS UI/app work |
| menubar | SwiftUI/UI/UX | Canonical | NSStatusItem, popover, and floating-panel patterns | macos-app-engineering | Keep |
| project-standards | Quality/Engineering Flow | Canonical | AGENTS and project policy maintenance | documentation | Keep |
| swift-concurrency-expert | Runtime/Performance | Canonical (Swift 6.2) | Concurrency diagnostics and remediation | — | Keep |
| swift-conventions | macOS/Swift Core | Canonical (Swift language) | Swift-specific style, type safety, and module conventions | code-quality | Keep |
| testing-xctest | Quality/Engineering Flow | Canonical | XCTest implementation patterns, async tests, `@MainActor`, mocks, fakes, and spies | delivery-workflow | Keep; XCTest owner |
| thermo-nuclear-code-quality-review | Quality/Engineering Flow | Canonical | Default code review owner; semaforo findings, severity framing, strict abstraction, large-file, and spaghetti-growth analysis | code-quality, delivery-workflow | Keep; default review mode |

## Grouping Summary

1. macOS/Swift Core: `macos-app-engineering`, `architecture`, `swift-conventions`
2. SwiftUI/UI/UX: `macos-app-engineering`, `menubar`, `accessibility-audit`
3. Runtime/Performance: `swift-concurrency-expert`, `debugging-diagnostics`, `audio-realtime`, `intelligence-kernel`
4. Quality/Engineering Flow: `delivery-workflow`, `testing-xctest`, `code-quality`, `project-standards`, `documentation`, `thermo-nuclear-code-quality-review`
5. Security/Data: `keychain-security`, `data-persistence`, `localization`
6. Meta-skills: `improve`
