# Skills Taxonomy Matrix

This matrix defines ownership, overlap, and action for all skills under `.agents/skills`.

| Skill | Theme | Owner | Scope | Overlap With | Action |
|---|---|---|---|---|---|
| accessibility-audit | SwiftUI/UI/UX | Canonical | Accessibility audit, keyboard navigation, focus order, reduced motion, overlay and panel accessibility | localization, native-app-designer, menubar | Keep; accessibility interaction owner |
| architecture | macOS/Swift Core | Canonical | Clean Architecture, module boundaries, DI | macos-development | Keep; clarify architecture-only scope |
| audio-realtime | Runtime/Performance | Canonical | Low-latency audio pipeline and callback constraints | debugging-strategies | Keep; specialized runtime owner |
| code-quality | Quality/Engineering Flow | Canonical (generic) | Readability and maintainability principles | swift-conventions | Keep; non-language-specific quality owner |
| code-review | Quality/Engineering Flow | Canonical | Risk-first review ritual and findings format; always includes thermo-nuclear structural review | task-lifecycle, quality-assurance, thermo-nuclear-code-quality-review | Keep; review specialist |
| data-persistence | Security/Data | Canonical | Repository, storage, migration, and synchronization strategy | architecture | Keep |
| debugging-strategies | Runtime/Performance | Canonical (method) | Cross-cutting debugging methodology, including SwiftUI runtime symptoms when root cause is unknown | observability-diagnostics, swiftui-patterns | Keep; investigation owner |
| documentation | Quality/Engineering Flow | Canonical | DocC, docs structure, and research patterns | project-standards | Keep |
| git-workflow | Git/Collaboration | Canonical | Prisma branch, commit, PR, merge, cleanup, and gh body-file mechanics | task-lifecycle | Keep; generic advanced Git guidance removed |
| improve | Meta-skills | Canonical | Read-only codebase audits, opportunity prioritization, roadmap advice, and handoff plan authoring | project-standards | Keep; advisory only |
| intelligence-kernel | Runtime/Performance | Canonical | Canonical summary schema, trust flags, and summary benchmark gates | quality-assurance, data-persistence | Keep |
| keychain-security | Security/Data | Canonical (credentials) | Keychain credential persistence and APIs | — | Keep; credential owner |
| localization | Security/Data | Canonical | Localization, locale-file hygiene, and accessible copy | accessibility-audit, swiftui-patterns | Keep; not a full accessibility owner |
| macos-development | macOS/Swift Core | Canonical | Implementation guidance for macOS SwiftUI/AppKit lifecycle and platform integration | native-app-designer, menubar | Keep; deep implementation owner |
| menubar | SwiftUI/UI/UX | Canonical | NSStatusItem, popover, and floating-panel patterns | macos-development, native-app-designer | Keep |
| native-app-designer | SwiftUI/UI/UX | Primary (UI/UX) | Primary UI/UX direction, native interaction quality, motion direction, and experience baseline for macOS/iOS interfaces | swiftui-patterns, macos-development, menubar | Keep; consult first for interface tasks |
| observability-diagnostics | Runtime/Performance | Canonical | Logging, telemetry, redaction, failure signatures, and metrics correlation | debugging-strategies | Keep; diagnostics data owner |
| preview-coverage | SwiftUI/UI/UX | Canonical | SwiftUI preview requirements and coverage | swiftui-patterns | Keep |
| project-standards | Quality/Engineering Flow | Canonical | AGENTS and project policy maintenance | documentation | Keep |
| quality-assurance | Quality/Engineering Flow | Canonical | Verification commands, scope checks, and merge gates | task-lifecycle, testing-xctest | Keep; command policy owner |
| swift-concurrency-expert | Runtime/Performance | Canonical (Swift 6.2) | Concurrency diagnostics and remediation | — | Keep |
| swift-conventions | macOS/Swift Core | Canonical (Swift language) | Swift-specific style, type safety, and module conventions | code-quality | Keep |
| swiftui-patterns | SwiftUI/UI/UX | Canonical | View, state, layout, design-system composition, motion implementation, and SwiftUI performance hygiene | preview-coverage, native-app-designer, debugging-strategies | Keep; absorbed generic animation/performance skills |
| task-lifecycle | Quality/Engineering Flow | Canonical (macro flow) | Risk classification and lifecycle phase orchestration | git-workflow, quality-assurance, code-review | Keep; macro orchestrator |
| testing-xctest | Quality/Engineering Flow | Canonical | XCTest implementation patterns, async tests, `@MainActor`, mocks, fakes, and spies | quality-assurance | Keep; XCTest owner |
| thermo-nuclear-code-quality-review | Quality/Engineering Flow | Specialist | Mandatory structural maintainability pass for code review; strict abstraction, large-file, and spaghetti-growth analysis | code-quality, code-review | Keep; harsh review mode |

## Grouping Summary

1. macOS/Swift Core: `macos-development`, `architecture`, `swift-conventions`
2. SwiftUI/UI/UX: `native-app-designer`, `swiftui-patterns`, `preview-coverage`, `menubar`, `accessibility-audit`
3. Runtime/Performance: `swift-concurrency-expert`, `debugging-strategies`, `audio-realtime`, `observability-diagnostics`, `intelligence-kernel`
4. Quality/Engineering Flow: `quality-assurance`, `testing-xctest`, `code-review`, `code-quality`, `task-lifecycle`, `project-standards`, `documentation`, `thermo-nuclear-code-quality-review`
5. Security/Data: `keychain-security`, `data-persistence`, `localization`
6. Git/Collaboration: `git-workflow`
7. Meta-skills: `improve`
