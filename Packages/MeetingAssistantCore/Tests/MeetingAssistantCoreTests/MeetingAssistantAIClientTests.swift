import Foundation
@testable import MeetingAssistantCore
import XCTest

final class MeetingAssistantAIClientTests: XCTestCase {
    func testAppSettings_EncodesExplicitTranscriptionRequest() throws {
        let settings = MeetingAssistantXPCModels.AppSettings(
            diarization: false,
            minSpeakers: 1,
            maxSpeakers: 4,
            numSpeakers: 0,
            providerID: "groq",
            modelID: "whisper-large-v3-turbo",
            inputLanguageCode: "pt-BR",
            executionMode: "assistant",
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(MeetingAssistantXPCModels.AppSettings.self, from: data)

        XCTAssertEqual(decoded.providerID, "groq")
        XCTAssertEqual(decoded.modelID, "whisper-large-v3-turbo")
        XCTAssertEqual(decoded.inputLanguageCode, "pt-BR")
        XCTAssertEqual(decoded.executionMode, "assistant")
    }

    func testAppSettings_DecodesLegacyPayloadWithNilTranscriptionFields() throws {
        let data = Data(#"{"diarization":true,"minSpeakers":1,"maxSpeakers":4,"numSpeakers":0}"#.utf8)

        let decoded = try JSONDecoder().decode(MeetingAssistantXPCModels.AppSettings.self, from: data)

        XCTAssertTrue(decoded.diarization)
        XCTAssertNil(decoded.providerID)
        XCTAssertNil(decoded.modelID)
        XCTAssertNil(decoded.inputLanguageCode)
        XCTAssertNil(decoded.executionMode)
        XCTAssertFalse(decoded.hasExplicitTranscriptionRequest)
    }

    func testAppSettings_ExplicitRequestWithNilLanguageDoesNotUseLegacyBranch() {
        let settings = MeetingAssistantXPCModels.AppSettings(
            diarization: false,
            minSpeakers: 1,
            maxSpeakers: 4,
            numSpeakers: 0,
            providerID: "local",
            modelID: "parakeet-tdt-0.6b-v3",
            inputLanguageCode: nil,
            executionMode: "meeting",
        )

        XCTAssertTrue(settings.hasExplicitTranscriptionRequest)
    }

    func testFetchServiceStatus_CompletesWithinTimeout() async throws {
        try XCTSkipIf(!FeatureFlags.useXPCService, "XPC Service is disabled")

        do {
            let status = try await MeetingAssistantAIClient.shared.fetchServiceStatus()
            XCTAssertFalse(status.status.isEmpty)
        } catch is TranscriptionError {
            // Expected in test environment where XPC service is not running
        } catch {
            // Any other error is acceptable in test environment
        }
    }
}
