# Plan 002: Benchmark-gate the Rust audio kernel pilot

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. When done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 48329a03..HEAD -- Packages/MeetingAssistantCore/Sources/Common/Config/FeatureFlags.swift Packages/MeetingAssistantCore/Sources/Audio/Services/AudioKernels Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecordingWorker.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/RustEnergyMeterKernelTests.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AudioRecordingWorkerMeteringTests.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AudioSystemPerformanceTests.swift Native/AudioKernelsRust`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `48329a03`, 2026-06-25

## Why this matters

The repo has a staged Rust audio-kernel path, but the feature flag is still off. Current Rust metering computes Swift bar levels before FFI and copies the full mono channel into a Swift array before calling Rust. That means the pilot can increase CPU and allocation pressure if enabled without measurement.

The goal is not to rewrite the audio stack. The goal is to make the Rust pilot decision measurable: remove obvious per-buffer overhead, add parity/performance tests, and leave the flag off unless the Rust path is proven faster under the repo's perf gate.

## Current state

- `Packages/MeetingAssistantCore/Sources/Common/Config/FeatureFlags.swift:37` keeps Rust kernels disabled:

```swift
/// Selects Rust-backed audio math kernels for the pilot path.
/// Current behavior keeps Swift math as the effective implementation while
/// preserving backend routing for Phase 2 integration.
public static let enableRustAudioMathKernels: Bool = false
```

- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioKernels/AudioKernelProvider.swift:142` computes bar levels in Swift before the FFI path:

```swift
let barPowerDBLevels = SwiftEnergyMeterKernel.makeBarPowerDBLevels(
    channelData: channelData,
    channelCount: channelCount,
    frameLength: frameLength,
    barCount: max(0, barCount)
)
```

- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioKernels/AudioKernelProvider.swift:169` copies samples into an array:

```swift
let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
guard let ffiResult = ffi.computeRmsPeak(samples: samples) else {
```

- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioKernels/RustAudioKernelFFI.swift:69` only accepts `[Float]`:

```swift
func computeRmsPeak(samples: [Float]) -> RmsPeakResult? {
```

- `Native/AudioKernelsRust/src/lib.rs:23` exposes `ak_compute_rms_peak_f32`, but no bar-level kernel.
- Existing reports under `.agents/reports/phase0-audio-baseline-2026-05-25.md` and `.agents/reports/phase2-checkpoint-rust-staging-2026-05-25.md` show this is an intentional pilot track.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Audio kernel tests | `./scripts/run-tests.sh --suite dev --test 'RustEnergyMeterKernelTests|AudioRecordingWorkerMeteringTests|AudioKernelProviderTests'` | exit 0, all selected tests pass |
| Perf suite | `make test-perf` | exit 0 |
| Build with Rust staging off | `MA_RUST_AUDIO_KERNELS_BUILD=off ./scripts/run-build.sh --configuration Debug` | exit 0 |
| Build with Rust staging auto | `MA_RUST_AUDIO_KERNELS_BUILD=auto ./scripts/run-build.sh --configuration Debug` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Full-lane lint | `make lint` | exit 0 |

## Scope

**In scope**:
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioKernels/RustAudioKernelFFI.swift`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioKernels/AudioKernelProvider.swift`
- `Native/AudioKernelsRust/src/lib.rs`
- `Native/AudioKernelsRust/include/audio_kernels_rust.h`
- Audio kernel and metering tests under `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/`
- `.agents/reports/` only if you need to add a short benchmark report

**Out of scope**:
- Do not enable `FeatureFlags.enableRustAudioMathKernels` by default unless the benchmark is clearly better and a reviewer explicitly accepts the risk.
- Do not move VAD or silence compaction to Rust in this plan.
- Do not change recording behavior or UI.

## Git workflow

- Branch: `advisor/002-rust-audio-benchmark-gate`
- Use Conventional Commits, for example: `perf(audio): benchmark-gate rust metering pilot`
- Do not push or open a PR unless the operator instructs it.

## Steps

### Step 1: Add a no-copy FFI call

Add a `RustAudioKernelFFI.computeRmsPeak(samples: UnsafeBufferPointer<Float>) -> RmsPeakResult?` overload. Keep the existing `[Float]` overload for tests, but implement it by forwarding to the buffer-pointer overload.

Update `RustEnergyMeterKernel` to call the no-copy overload:

```swift
let sampleBuffer = UnsafeBufferPointer(start: channelData[0], count: frameLength)
guard let ffiResult = ffi.computeRmsPeak(samples: sampleBuffer) else { ... }
```

**Verify**: `./scripts/run-tests.sh --suite dev --test 'RustEnergyMeterKernelTests|AudioRecordingWorkerMeteringTests|AudioKernelProviderTests'` -> exit 0.

### Step 2: Avoid duplicate Swift work when Rust owns global meters

Keep Swift bar-level computation for now, because Rust does not expose a bar-level API. Move the bar computation after FFI fallback decisions so the Rust success path does not do any extra Swift global RMS/peak work, and the Swift fallback still returns exactly the current output.

Do not remove bar levels. `AudioRecordingWorkerMeteringTests` expects bucket behavior.

**Verify**: `./scripts/run-tests.sh --suite dev --test 'RustEnergyMeterKernelTests|AudioRecordingWorkerMeteringTests|AudioKernelProviderTests'` -> exit 0.

### Step 3: Add a direct Swift-vs-Rust performance test

Add or extend a performance test that compares:

- `SwiftEnergyMeterKernel.shared.makeMeterSnapshot(from:barCount:)`
- `RustEnergyMeterKernel(ffi: real-or-test ffi).makeMeterSnapshot(from:barCount:)`

Use a realistic mono buffer, for example 2,048 or 4,096 frames at 48 kHz and 16 bars. If the staged dylib is unavailable, use an injected FFI function only for allocation/Swift-side overhead measurement and keep the real dylib test as `XCTSkip` like the existing test.

Record the result in a short comment or `.agents/reports/rust-audio-metering-benchmark-YYYY-MM-DD.md`. Do not claim Rust is faster unless the measured path proves it.

**Verify**: `make test-perf` -> exit 0.

### Step 4: Re-run staging behavior checks

Run both build paths without changing the default feature flag.

**Verify**: `MA_RUST_AUDIO_KERNELS_BUILD=off ./scripts/run-build.sh --configuration Debug` -> exit 0.

**Verify**: `MA_RUST_AUDIO_KERNELS_BUILD=auto ./scripts/run-build.sh --configuration Debug` -> exit 0.

### Step 5: Decide the flag outcome

Leave `FeatureFlags.enableRustAudioMathKernels` as `false` unless all are true:

- Rust success path avoids per-buffer Swift array allocation.
- `make test-perf` shows Rust metering is materially faster or at least neutral on CPU and allocation.
- A reviewer accepts the runtime risk.

If any condition is false, keep the flag off and document the next kernel to move, likely bar-level computation, as follow-up.

**Verify**: `make build-agent` -> exit 0.

**Verify**: `make lint` -> exit 0.

## Test plan

- Existing parity tests: `RustEnergyMeterKernelTests`, `AudioRecordingWorkerMeteringTests`, `AudioKernelProviderTests`.
- New or extended perf test: Swift-vs-Rust metering path.
- Build staging checks with `MA_RUST_AUDIO_KERNELS_BUILD=off` and `auto`.

## Done criteria

- [ ] Rust FFI can compute RMS/peak from an unsafe buffer without first allocating `[Float]`.
- [ ] Rust success path does not duplicate Swift global RMS/peak computation.
- [ ] Bar-level output remains unchanged.
- [ ] `FeatureFlags.enableRustAudioMathKernels` remains false unless benchmark evidence and review justify changing it.
- [ ] `./scripts/run-tests.sh --suite dev --test 'RustEnergyMeterKernelTests|AudioRecordingWorkerMeteringTests|AudioKernelProviderTests'` exits 0.
- [ ] `make test-perf` exits 0.
- [ ] `make build-agent` exits 0.
- [ ] `make lint` exits 0.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report back if:

- The no-copy FFI overload cannot be made memory-safe without broad unsafe changes.
- The Rust path is slower after removing the Swift array copy.
- The fix requires changing live audio recording behavior outside `AudioKernels`.
- Staging the Rust dylib becomes required for normal Debug builds.

## Maintenance notes

The likely next useful Rust kernel is bar-level bucket computation, because the current Rust pilot still relies on Swift for waveform bars. Reviewers should focus on per-buffer allocation, fallback behavior, and whether logging in the hot path remains low overhead.
