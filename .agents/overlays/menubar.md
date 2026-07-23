---
kind: project-overlay
extends: menubar
project: vozinha
precedence: project
---

# Vozinha menu-bar checks

- Keep one explicit status-item owner in the app lifecycle; start with `App/AppDelegate/MenuBar.swift` and related `AppDelegate` coordinators.
- The floating recording indicator lives under `Packages/MeetingAssistantCore/Sources/UI/`; visibility follows reactive recording state rather than one trigger path.
- Preserve macOS 15 behavior and guard newer menu-bar or panel APIs for macOS 26.
- Menu-bar actions must respect the local-first privacy boundary: do not place transcript, prompt, credential, or model internals in titles, logs, or diagnostics.
- Route recording lifecycle and capture correctness to the retained local `audio-realtime` specialist.
