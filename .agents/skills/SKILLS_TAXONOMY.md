# Skills Taxonomy Matrix

This matrix defines ownership, overlap, and action for all skills under `.agents/skills`.

| Skill | Theme | Owner | Scope | Overlap With | Action |
|---|---|---|---|---|---|
| accessibility-audit | SwiftUI/UI/UX | Canonical | Accessibility audit, keyboard navigation, focus order, reduced motion, overlay and panel accessibility | localization, macos-design-guidelines, native-app-designer | Keep; accessibility interaction owner |
| architecture | macOS/Swift Core | Canonical | Clean Architecture, module boundaries, DI | macos-development | Keep; clarify architecture-only scope |
| audio-realtime | Runtime/Performance | Canonical | Low-latency audio pipeline and callback constraints | performance, debugging-strategies | Keep; specialized runtime owner |
| code-quality | Quality/Engineering Flow | Canonical (generic) | Readability and maintainability principles | swift-conventions | Keep; non-language-specific quality owner |
| code-review | Quality/Engineering Flow | Canonical | Risk-first review ritual and findings format; always includes thermo-nuclear structural review | task-lifecycle, quality-assurance, thermo-nuclear-code-quality-review | Keep; review specialist |
| data-persistence | Security/Data | Canonical | Repository, storage, migration, and synchronization strategy | architecture, security | Keep |
| debugging-strategies | Runtime/Performance | Canonical (method) | Cross-cutting debugging methodology | observability-diagnostics, performance, swiftui-performance-audit | Keep; investigation owner |
| documentation | Quality/Engineering Flow | Canonical | DocC, docs structure, and research patterns | project-standards | Keep |
| error-handling | Security/Data | Canonical | Error modeling, propagation, recovery, and logging expectations | observability-diagnostics, code-quality | Keep |
| git-advanced-workflows | Git/Collaboration | Canonical (advanced) | Rebase, cherry-pick, bisect, and reflog recovery | git-workflow | Keep |
| git-workflow | Git/Collaboration | Canonical (standard) | Branch, commit, PR, and merge flow | task-lifecycle | Keep |
| grill-me | Meta-skills | Canonical | Adversarial plan review and design stress testing | code-review | Keep |
| improve | Meta-skills | Canonical | Read-only codebase audits, opportunity prioritization, roadmap advice, and handoff plan authoring | project-standards | Keep; advisory only |
| intelligence-kernel | Runtime/Performance | Canonical | Canonical summary schema, trust flags, and summary benchmark gates | quality-assurance, data-persistence | Keep |
| keychain-security | Security/Data | Canonical (credentials) | Keychain credential persistence and APIs | security, networking | Keep; credential owner |
| localization | Security/Data | Canonical | Localization, locale-file hygiene, and accessible copy | accessibility-audit, swiftui-patterns | Keep; not a full accessibility owner |
| macos-design-guidelines | SwiftUI/UI/UX | Canonical | Apple HIG for Mac windows, menus, shortcuts, and platform behavior | macos-development, native-app-designer, menubar | Keep |
| macos-development | macOS/Swift Core | Canonical | Implementation guidance for macOS SwiftUI/AppKit | macos-design-guidelines | Keep; deep implementation owner |
| menubar | SwiftUI/UI/UX | Canonical | NSStatusItem, popover, and floating-panel patterns | macos-development, macos-design-guidelines | Keep |
| native-app-designer | SwiftUI/UI/UX | Primary (UI/UX) | Primary UI/UX direction and experience-quality baseline for macOS/iOS interfaces | macos-design-guidelines, swiftui-animation, swiftui-patterns, macos-development | Keep; consult first for interface tasks |
| networking | Security/Data | Canonical (transport) | URLSession, request modeling, and resiliency | security, keychain-security | Keep |
| observability-diagnostics | Runtime/Performance | Canonical | Logging, telemetry, redaction, failure signatures, and metrics correlation | debugging-strategies, performance, error-handling | Keep; diagnostics data owner |
| performance | Runtime/Performance | Canonical (system) | App-wide CPU, memory, startup, and energy optimization | observability-diagnostics, swiftui-performance-audit, debugging-strategies | Keep |
| preview-coverage | SwiftUI/UI/UX | Canonical | SwiftUI preview requirements and coverage | swiftui-patterns | Keep |
| project-standards | Quality/Engineering Flow | Canonical | AGENTS and project policy maintenance | documentation | Keep |
| quality-assurance | Quality/Engineering Flow | Canonical | Verification commands, scope checks, and merge gates | task-lifecycle, testing-xctest | Keep; command policy owner |
| security | Security/Data | Canonical (baseline) | Threat model baseline, validation, and sensitive data controls | keychain-security, networking | Keep |
| swift-concurrency-expert | Runtime/Performance | Canonical (Swift 6.2) | Concurrency diagnostics and remediation | — | Keep |
| swift-conventions | macOS/Swift Core | Canonical (Swift language) | Swift-specific style, type safety, and module conventions | code-quality | Keep |
| swift-package-manager | macOS/Swift Core | Canonical | Package.swift and SPM dependency management | macos-development | Keep |
| swiftui-animation | SwiftUI/UI/UX | Canonical | Advanced SwiftUI motion, transitions, and shader effects | native-app-designer | Keep |
| swiftui-patterns | SwiftUI/UI/UX | Canonical | View, state, layout, and design-system composition | preview-coverage, native-app-designer | Keep |
| swiftui-performance-audit | SwiftUI/UI/UX | Canonical (runtime perf) | SwiftUI rendering, update, and layout performance diagnostics | performance, debugging-strategies | Keep |
| task-lifecycle | Quality/Engineering Flow | Canonical (macro flow) | Risk classification and lifecycle phase orchestration | git-workflow, quality-assurance, code-review | Keep; macro orchestrator |
| testing-xctest | Quality/Engineering Flow | Canonical | XCTest implementation patterns, async tests, `@MainActor`, mocks, fakes, and spies | quality-assurance | Keep; XCTest owner |
| thermo-nuclear-code-quality-review | Quality/Engineering Flow | Specialist | Mandatory structural maintainability pass for code review; strict abstraction, large-file, and spaghetti-growth analysis | code-quality, code-review | Keep; harsh review mode |

## Grouping Summary

1. macOS/Swift Core: `macos-development`, `architecture`, `swift-conventions`, `swift-package-manager`
2. SwiftUI/UI/UX: `native-app-designer`, `macos-design-guidelines`, `swiftui-patterns`, `swiftui-animation`, `swiftui-performance-audit`, `preview-coverage`, `menubar`, `accessibility-audit`
3. Runtime/Performance: `swift-concurrency-expert`, `performance`, `debugging-strategies`, `audio-realtime`, `observability-diagnostics`, `intelligence-kernel`
4. Quality/Engineering Flow: `quality-assurance`, `testing-xctest`, `code-review`, `code-quality`, `task-lifecycle`, `project-standards`, `documentation`, `thermo-nuclear-code-quality-review`
5. Security/Data: `security`, `keychain-security`, `networking`, `data-persistence`, `error-handling`, `localization`
6. Git/Collaboration: `git-workflow`, `git-advanced-workflows`
7. Meta-skills: `grill-me`, `improve`
