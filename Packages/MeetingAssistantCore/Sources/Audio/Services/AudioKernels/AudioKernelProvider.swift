@preconcurrency import AVFoundation
import Foundation
import MeetingAssistantCoreCommon

public enum AudioKernelBackend: Sendable, Equatable {
    case swift
    case rustPilot
}

public struct AudioKernelProvider: Sendable {
    public let backend: AudioKernelBackend

    private let voiceActivityFactory: @Sendable () -> any VoiceActivityKernel
    private let energyMeterFactory: @Sendable () -> any EnergyMeterKernel
    private let silenceAnalysisFactory: @Sendable () -> any SilenceAnalysisKernel

    public init(
        voiceActivityFactory: @escaping @Sendable () -> any VoiceActivityKernel = {
            RealtimeVoiceActivityWindowAssembler()
        },
    ) {
        self.init(
            backend: .swift,
            voiceActivityFactory: voiceActivityFactory,
            energyMeterFactory: { SwiftEnergyMeterKernel.shared },
            silenceAnalysisFactory: { SwiftSilenceAnalysisKernel() },
        )
    }

    init(
        backend: AudioKernelBackend,
        voiceActivityFactory: @escaping @Sendable () -> any VoiceActivityKernel,
        energyMeterFactory: @escaping @Sendable () -> any EnergyMeterKernel,
        silenceAnalysisFactory: @escaping @Sendable () -> any SilenceAnalysisKernel,
    ) {
        self.backend = backend
        self.voiceActivityFactory = voiceActivityFactory
        self.energyMeterFactory = energyMeterFactory
        self.silenceAnalysisFactory = silenceAnalysisFactory
    }

    public func makeVoiceActivityKernel() -> any VoiceActivityKernel {
        voiceActivityFactory()
    }

    func makeEnergyMeterKernel() -> any EnergyMeterKernel {
        energyMeterFactory()
    }

    func makeSilenceAnalysisKernel() -> any SilenceAnalysisKernel {
        silenceAnalysisFactory()
    }

    static func forFeatureFlags(enableRustAudioMathKernels: Bool) -> AudioKernelProvider {
        let provider = enableRustAudioMathKernels ? rustPilot : swift
        AppLogger.info(
            "Audio kernel backend selected",
            category: .audio,
            extra: [
                "backend": provider.backend.diagnosticsValue,
                "enableRustAudioMathKernels": enableRustAudioMathKernels,
            ],
        )
        return provider
    }

    private static let swift = AudioKernelProvider(
        backend: .swift,
        voiceActivityFactory: { RealtimeVoiceActivityWindowAssembler() },
        energyMeterFactory: { SwiftEnergyMeterKernel.shared },
        silenceAnalysisFactory: { SwiftSilenceAnalysisKernel() },
    )

    private static let rustPilot = AudioKernelProvider(
        backend: .rustPilot,
        voiceActivityFactory: { RustVoiceActivityKernel() },
        energyMeterFactory: { RustEnergyMeterKernel() },
        silenceAnalysisFactory: { RustSilenceAnalysisKernel() },
    )

    public static let live = forFeatureFlags(
        enableRustAudioMathKernels: FeatureFlags.enableRustAudioMathKernels,
    )
}

private actor RustVoiceActivityKernel: VoiceActivityKernel {
    private let swiftKernel = RealtimeVoiceActivityWindowAssembler()

    func setAdaptiveQualityMode(_ mode: RealtimeVoiceActivityWindowAssembler.AdaptiveQualityMode) async {
        await swiftKernel.setAdaptiveQualityMode(mode)
    }

    func append(buffer: AVAudioPCMBuffer) async throws -> [RealtimeVoiceActivityWindowAssembler.Window] {
        try await swiftKernel.append(buffer: buffer)
    }

    func finish() async throws -> [RealtimeVoiceActivityWindowAssembler.Window] {
        try await swiftKernel.finish()
    }
}

struct RustEnergyMeterKernel: EnergyMeterKernel {
    private let ffi: RustAudioKernelFFI?
    private let loadSource: RustAudioKernelFFI.LoadSource
    private let loadedLibraryPath: String?

    private enum RuntimePath: String {
        case swiftFallback = "swift_fallback"
        case rustFFI = "rust_ffi"
    }

    private enum FallbackReason: String {
        case nonMonoInput = "non_mono_input"
        case ffiUnavailable = "ffi_unavailable"
        case ffiComputationFailed = "ffi_computation_failed"
    }

    init(ffi: RustAudioKernelFFI? = nil) {
        if let ffi {
            self.ffi = ffi
            loadSource = .processSymbols
            loadedLibraryPath = nil
        } else {
            let loadResult = RustAudioKernelFFI.loadForRuntime()
            self.ffi = loadResult.ffi
            loadSource = loadResult.source
            loadedLibraryPath = loadResult.libraryPath
            logLoaderDiagnostics(loadResult: loadResult)
        }
    }

    func makeMeterSnapshot(
        from buffer: AVAudioPCMBuffer,
        barCount: Int,
    ) -> AudioRecordingWorker.MeterSnapshot? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        guard channelCount > 0, frameLength > 0, sampleRate > 0 else { return nil }

        guard channelCount == 1 else {
            logRuntimePath(
                .swiftFallback,
                frameLength: frameLength,
                barCount: barCount,
                fallbackReason: .nonMonoInput,
            )
            return SwiftEnergyMeterKernel.shared.makeMeterSnapshot(from: buffer, barCount: barCount)
        }

        guard let ffi else {
            logRuntimePath(
                .swiftFallback,
                frameLength: frameLength,
                barCount: barCount,
                fallbackReason: .ffiUnavailable,
            )
            return SwiftEnergyMeterKernel.shared.makeMeterSnapshot(from: buffer, barCount: barCount)
        }

        let sampleBuffer = UnsafeBufferPointer(start: channelData[0], count: frameLength)
        guard let ffiResult = ffi.computeRmsPeak(samples: sampleBuffer) else {
            logRuntimePath(
                .swiftFallback,
                frameLength: frameLength,
                barCount: barCount,
                fallbackReason: .ffiComputationFailed,
            )
            return SwiftEnergyMeterKernel.shared.makeMeterSnapshot(from: buffer, barCount: barCount)
        }

        logRuntimePath(
            .rustFFI,
            frameLength: frameLength,
            barCount: barCount,
            fallbackReason: nil,
        )

        let averagePowerDB = SwiftEnergyMeterKernel.powerDB(fromLinear: ffiResult.rmsLinear)
        let peakPowerDB = SwiftEnergyMeterKernel.powerDB(fromLinear: ffiResult.peakLinear)
        let barPowerDBLevels = SwiftEnergyMeterKernel.makeBarPowerDBLevels(
            channelData: channelData,
            channelCount: channelCount,
            frameLength: frameLength,
            barCount: max(0, barCount),
        )

        return AudioRecordingWorker.MeterSnapshot(
            averagePowerDB: averagePowerDB,
            peakPowerDB: peakPowerDB,
            barPowerDBLevels: barPowerDBLevels,
            deltaTime: Double(frameLength) / sampleRate,
        )
    }

    private func logLoaderDiagnostics(loadResult: RustAudioKernelFFI.LoadResult) {
        var extra: [String: Any] = [
            "backend": AudioKernelBackend.rustPilot.diagnosticsValue,
            "loadSource": loadResult.source.diagnosticsValue,
            "ffiAvailable": loadResult.ffi != nil,
        ]
        if let path = loadResult.libraryPath {
            extra["libraryPath"] = path
        }

        AppLogger.info(
            "Rust audio kernel loader result",
            category: .audio,
            extra: extra,
        )
    }

    private func logRuntimePath(
        _ runtimePath: RuntimePath,
        frameLength: Int,
        barCount: Int,
        fallbackReason: FallbackReason?,
    ) {
        var extra: [String: Any] = [
            "backend": AudioKernelBackend.rustPilot.diagnosticsValue,
            "runtimePath": runtimePath.rawValue,
            "loadSource": loadSource.diagnosticsValue,
            "frameLength": frameLength,
            "barCount": barCount,
            "ffiAvailable": ffi != nil,
        ]

        if let loadedLibraryPath {
            extra["libraryPath"] = loadedLibraryPath
        }

        if let fallbackReason {
            extra["fallbackReason"] = fallbackReason.rawValue
        }

        AppLogger.debug(
            "Rust audio kernel runtime path",
            category: .audio,
            extra: extra,
        )
    }
}

private extension AudioKernelBackend {
    var diagnosticsValue: String {
        switch self {
        case .swift:
            "swift"
        case .rustPilot:
            "rust_pilot"
        }
    }
}

private struct RustSilenceAnalysisKernel: SilenceAnalysisKernel {
    func analyze(inputURL: URL) throws -> AudioSilenceAnalysis {
        try SwiftSilenceAnalysisKernel().analyze(inputURL: inputURL)
    }
}
