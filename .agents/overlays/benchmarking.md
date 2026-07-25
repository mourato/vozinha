---
kind: project-overlay
extends: benchmarking
project: vozinha
precedence: project
---

# Vozinha / Prisma reference catalog

**Same-domain** here means meeting capture, transcription, voice-to-text, or
audio processing.

Relative clones from this repo: `../References/<CanonicalName>/`.

## Registered references

### VoiceInk

| Attribute | Value |
|-----------|-------|
| **Canonical name** | VoiceInk |
| **Classification** | UI/UX + Same-domain |
| **Local path** | `../References/VoiceInk/` |
| **Cloned?** | Yes |
| **Description** | macOS voice transcription; architecture, audio pipeline, and UI patterns |

### FluidVoice

| Attribute | Value |
|-----------|-------|
| **Canonical name** | FluidVoice |
| **Classification** | Same-domain |
| **Local path** | `../References/FluidVoice/` |
| **Cloned?** | Yes |
| **Remote** | https://github.com/altic-dev/FluidVoice/ |
| **Description** | Fluid voice UI and audio interactions |

### TypeWhisper

| Attribute | Value |
|-----------|-------|
| **Canonical name** | TypeWhisper |
| **Classification** | Same-domain |
| **Local path** | `../References/TypeWhisper/` |
| **Cloned?** | Yes |
| **Remote** | https://github.com/TypeWhisper/typewhisper-mac |
| **Description** | macOS voice-to-text; transcription workflow reference |

## Product routing

After locating reference material:

- Architecture patterns → local `architecture`
- Audio pipeline → local `audio-realtime`
- macOS UI implementation → global `macos-app-engineering` (+ overlay)
- Review of changes inspired by references → global `thermo-nuclear-code-quality-review`

Summary, fixture, provider-drift, and `make benchmark-summary` gates stay with
`intelligence-kernel` and delivery guidance — not this overlay.
