@preconcurrency import AVFoundation
@testable import MeetingAssistantCoreAudio
import XCTest

final class AudioKernelProviderTests: XCTestCase {
    func testInitWithCustomFactories_UsesProvidedVoiceKernel() {
        let voiceKernel = StubVoiceActivityKernel()
        let provider = AudioKernelProvider(voiceActivityFactory: { voiceKernel })

        let produced = provider.makeVoiceActivityKernel()

        XCTAssertTrue((produced as AnyObject) === (voiceKernel as AnyObject))
    }

    func testForFeatureFlags_WhenDisabled_UsesSwiftBackend() {
        let provider = AudioKernelProvider.forFeatureFlags(enableRustAudioMathKernels: false)

        XCTAssertEqual(provider.backend, .swift)
    }

    func testForFeatureFlags_WhenEnabled_UsesRustPilotBackend() {
        let provider = AudioKernelProvider.forFeatureFlags(enableRustAudioMathKernels: true)

        XCTAssertEqual(provider.backend, .rustPilot)
    }
}

private actor StubVoiceActivityKernel: VoiceActivityKernel {
    func setAdaptiveQualityMode(_ mode: RealtimeVoiceActivityWindowAssembler.AdaptiveQualityMode) async {}

    func append(buffer _: AVAudioPCMBuffer) async throws -> [RealtimeVoiceActivityWindowAssembler.Window] {
        []
    }

    func finish() async throws -> [RealtimeVoiceActivityWindowAssembler.Window] {
        []
    }
}
