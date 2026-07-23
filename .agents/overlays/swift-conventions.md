---
kind: project-overlay
extends: swift-conventions
project: vozinha
precedence: project
---

# Vozinha Swift checks

- Swift 6.2 strict concurrency and default actor isolation are active; make isolation and `Sendable` decisions explicit.
- Keep files at or below the repository's 600-line policy and use colocated type directories with unique owner-prefixed sibling filenames.
- Preserve the module layout under `Packages/MeetingAssistantCore/Sources/` and the public `MeetingAssistantCore*` target/import names.
- Prefer Observation for new UI state while preserving existing `ObservableObject` contracts until an intentional migration is verified.
- Route concurrency-specific remediation to the retained local `swift-concurrency-expert` specialist and lint/build delivery to global `delivery-workflow` plus its Vozinha overlay.
