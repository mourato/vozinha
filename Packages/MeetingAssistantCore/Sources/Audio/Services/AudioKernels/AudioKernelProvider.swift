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
        }
    ) {
        self.init(
            backend: .swift,
            voiceActivityFactory: voiceActivityFactory,
            energyMeterFactory: { SwiftEnergyMeterKernel.shared },
            silenceAnalysisFactory: { SwiftSilenceAnalysisKernel() }
        )
    }

    init(
        backend: AudioKernelBackend,
        voiceActivityFactory: @escaping @Sendable () -> any VoiceActivityKernel,
        energyMeterFactory: @escaping @Sendable () -> any EnergyMeterKernel,
        silenceAnalysisFactory: @escaping @Sendable () -> any SilenceAnalysisKernel
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
        enableRustAudioMathKernels ? rustPilot : swift
    }

    private static let swift = AudioKernelProvider(
        backend: .swift,
        voiceActivityFactory: { RealtimeVoiceActivityWindowAssembler() },
        energyMeterFactory: { SwiftEnergyMeterKernel.shared },
        silenceAnalysisFactory: { SwiftSilenceAnalysisKernel() }
    )

    private static let rustPilot = AudioKernelProvider(
        backend: .rustPilot,
        voiceActivityFactory: { RustVoiceActivityKernel() },
        energyMeterFactory: { RustEnergyMeterKernel() },
        silenceAnalysisFactory: { RustSilenceAnalysisKernel() }
    )

    public static let live = forFeatureFlags(
        enableRustAudioMathKernels: FeatureFlags.enableRustAudioMathKernels
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

    init(ffi: RustAudioKernelFFI? = RustAudioKernelFFI.loadFromProcessSymbols()) {
        self.ffi = ffi
    }

    func makeMeterSnapshot(
        from buffer: AVAudioPCMBuffer,
        barCount: Int
    ) -> AudioRecordingWorker.MeterSnapshot? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        guard channelCount > 0, frameLength > 0, sampleRate > 0 else { return nil }

        let barPowerDBLevels = SwiftEnergyMeterKernel.makeBarPowerDBLevels(
            channelData: channelData,
            channelCount: channelCount,
            frameLength: frameLength,
            barCount: max(0, barCount)
        )

        guard channelCount == 1, let ffi else {
            return SwiftEnergyMeterKernel.shared.makeMeterSnapshot(from: buffer, barCount: barCount)
        }

        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        guard let ffiResult = ffi.computeRmsPeak(samples: samples) else {
            return SwiftEnergyMeterKernel.shared.makeMeterSnapshot(from: buffer, barCount: barCount)
        }

        let averagePowerDB = SwiftEnergyMeterKernel.powerDB(fromLinear: ffiResult.rmsLinear)
        let peakPowerDB = SwiftEnergyMeterKernel.powerDB(fromLinear: ffiResult.peakLinear)

        return AudioRecordingWorker.MeterSnapshot(
            averagePowerDB: averagePowerDB,
            peakPowerDB: peakPowerDB,
            barPowerDBLevels: barPowerDBLevels,
            deltaTime: Double(frameLength) / sampleRate
        )
    }
}

private struct RustSilenceAnalysisKernel: SilenceAnalysisKernel {
    func analyze(inputURL: URL) throws -> AudioSilenceAnalysis {
        try SwiftSilenceAnalysisKernel().analyze(inputURL: inputURL)
    }
}
