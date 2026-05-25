## Phase 2 Checkpoint - Rust Staging Pipeline (2026-05-25)

### Risk / Lane
- Risk: **High**
- Lane: **Full**
- Rationale: build pipeline change + runtime dynamic library loading behavior.

### Reuse Decision (reuse -> extend -> create)
- **Reuse**: existing `run-build.sh` canonical build path and existing `RustAudioKernelFFI` symbol lookup path.
- **Extend**: `RustAudioKernelFFI` now extends loading logic to also try bundled `Frameworks` dylib paths.
- **Create**: new staging helper script `scripts/stage-rust-audio-kernels.sh` for controlled Rust artifact build/stage.

### Implemented Changes
- Added fallback dynamic-library loading in:
  - `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioKernels/RustAudioKernelFFI.swift`
  - Lookup order: process symbols (`dlsym`) -> env override path (`MA_RUST_AUDIO_KERNELS_DYLIB_PATH`) -> bundled `Contents/Frameworks/libaudio_kernels_rust.dylib`.
- Added build-time staging helper:
  - `scripts/stage-rust-audio-kernels.sh`
  - Modes via `MA_RUST_AUDIO_KERNELS_BUILD` / `--mode`:
    - `off`: skip staging
    - `auto`: stage when Cargo is available; skip gracefully otherwise
    - `on`: require Cargo and fail when staging cannot run
- Integrated helper into canonical build entrypoint:
  - `scripts/run-build.sh`
  - Post-`xcodebuild` staging now runs automatically and propagates failure exit code when staging fails.

### Validation Evidence
- Script mode checks:
  - `./scripts/stage-rust-audio-kernels.sh --mode off` -> pass (disabled)
  - `./scripts/stage-rust-audio-kernels.sh --mode auto` -> pass (graceful skip without Cargo)
  - `./scripts/stage-rust-audio-kernels.sh --mode on` -> expected fail (Cargo required)
- Build behavior checks:
  - `MA_RUST_AUDIO_KERNELS_BUILD=off ./scripts/run-build.sh --configuration Debug` -> pass
  - `MA_RUST_AUDIO_KERNELS_BUILD=auto ./scripts/run-build.sh --configuration Debug` -> pass
  - `MA_RUST_AUDIO_KERNELS_BUILD=on ./scripts/run-build.sh --configuration Debug` -> fail with non-zero exit (expected, Cargo missing)
- Targeted regression tests:
  - `./scripts/run-tests.sh --suite dev --test 'AudioKernelProviderTests|RustEnergyMeterKernelTests|AudioRecordingWorkerMeteringTests'`
  - Result: `Total: 11 | Passed: 11 | Failed: 0`

### Known Limitations / Notes
- Initial run showed `cargo` missing and validated fail-fast semantics for `mode=on`.
- Rust toolchain was then installed via Homebrew (`cargo 1.95.0`, `rustc 1.95.0`).
- Post-install `mode=on` build now succeeds and stages dylib into both bundles:
  - `.xcode-build/Build/Products/Debug/Prisma.app/Contents/Frameworks/libaudio_kernels_rust.dylib`
  - `.xcode-build/Build/Products/Debug/PrismaAI.xpc/Contents/Frameworks/libaudio_kernels_rust.dylib`
- `codesign -dv` confirms staged dylibs are ad-hoc signed (`Signature=adhoc`).
- Feature flag remains unchanged: `FeatureFlags.enableRustAudioMathKernels = false`.
