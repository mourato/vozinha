## Phase 2 Prep - Rust C-ABI Skeleton (2026-05-25)

### Scope
- Prepare Phase 2 integration path without changing runtime behavior.
- Keep Swift implementation as effective backend by default.

### Implemented
- Added `AudioKernelProvider` backend routing support:
  - backend enum: `swift` / `rustPilot`
  - feature-flag driven selection (`FeatureFlags.enableRustAudioMathKernels`)
  - rustPilot path currently delegates to Swift implementations via placeholder adapters (safe no-op behavioral change).
- Added feature flag:
  - `Packages/MeetingAssistantCore/Sources/Common/Config/FeatureFlags.swift`
  - `enableRustAudioMathKernels = false` (default OFF)
- Added Rust crate skeleton (manual C-ABI, not yet linked to app build):
  - `Native/AudioKernelsRust/Cargo.toml`
  - `Native/AudioKernelsRust/src/lib.rs`
  - `Native/AudioKernelsRust/include/audio_kernels_rust.h`
  - `Native/AudioKernelsRust/README.md`
  - `Native/AudioKernelsRust/.gitignore`

### ABI Skeleton Details
- Exported symbols:
  - `ak_version`
  - `ak_compute_rms_peak_f32`
- ABI rules used:
  - pointer + length arguments
  - POD output structs
  - explicit integer result codes
  - caller-owned buffers

### Tests Added
- Added provider unit tests:
  - `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AudioKernelProviderTests.swift`
  - covers custom factory wiring and feature-flag backend selection.

### Validation Evidence
- `AudioKernelProviderTests`: pass (`3/3`)
- Audio/DI targeted suite: pass (`19/19`)
  - includes compactor, VAD assembler, incremental coordinators, metering, recording manager.
- `make lint`: pass (warnings only)

### Known Limitations / Notes
- Rust crate is intentionally not linked into Swift build yet (integration comes in a later Phase 2 step).
- `run-tests.sh --test` with very long regex can hit shell path-length limits in generated temp log names; split runs as workaround.
