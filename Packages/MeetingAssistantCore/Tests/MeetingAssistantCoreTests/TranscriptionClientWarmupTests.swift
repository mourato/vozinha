import Foundation
@testable import MeetingAssistantCoreAI
import MeetingAssistantCoreDomain
@testable import MeetingAssistantCoreInfrastructure
import XCTest

@MainActor
final class TranscriptionClientWarmupTests: XCTestCase {
    private var loadedASRModelIDs: [String] = []
    private var diarizationWarmupCount = 0

    override func setUp() async throws {
        try await super.setUp()
        try AppSettingsTestIsolationLock.acquire()
        loadedASRModelIDs = []
        diarizationWarmupCount = 0
    }

    override func tearDown() async throws {
        AppSettingsTestIsolationLock.release()
        try await super.tearDown()
    }

    func testMeetingWarmupSkippedWhenMeetingCapabilityDisabled() async throws {
        let settings = AppSettingsStore.shared
        let originalMeetingEnabled = settings.isMeetingTranscriptionEnabled
        defer { settings.isMeetingTranscriptionEnabled = originalMeetingEnabled }
        settings.isMeetingTranscriptionEnabled = false

        let client = makeTestClient()

        try await client.warmupModel(for: .meeting, configuration: nil)

        XCTAssertTrue(loadedASRModelIDs.isEmpty)
        XCTAssertEqual(diarizationWarmupCount, 0)
    }

    func testDictationWarmupAllowedWhenMeetingCapabilityDisabled() async throws {
        let settings = AppSettingsStore.shared
        let originalMeetingEnabled = settings.isMeetingTranscriptionEnabled
        defer { settings.isMeetingTranscriptionEnabled = originalMeetingEnabled }
        settings.isMeetingTranscriptionEnabled = false

        let dictationModelID = LocalTranscriptionModel.parakeetTdt06BV3.rawValue
        let configuration = DomainTranscriptionRequestConfiguration(
            providerID: MeetingAssistantCoreInfrastructure.TranscriptionProvider.local.rawValue,
            modelID: dictationModelID,
            inputLanguageCode: nil,
        )

        let client = makeTestClient()
        try await client.warmupModel(for: .dictation, configuration: configuration)

        XCTAssertEqual(loadedASRModelIDs, [dictationModelID])
        XCTAssertEqual(diarizationWarmupCount, 0)
    }

    func testDictationWarmupUsesPassedModelIDNotMeetingSelection() async throws {
        let settings = AppSettingsStore.shared
        let originalMeetingModel = settings.meetingTranscriptionLocalModel
        defer { settings.meetingTranscriptionLocalModel = originalMeetingModel }

        settings.meetingTranscriptionLocalModel = .parakeetTdt06BV3

        let dictationModelID = LocalTranscriptionModel.parakeetTdt06BV3.rawValue
        let configuration = DomainTranscriptionRequestConfiguration(
            providerID: MeetingAssistantCoreInfrastructure.TranscriptionProvider.local.rawValue,
            modelID: dictationModelID,
            inputLanguageCode: nil,
        )

        let client = makeTestClient()
        try await client.warmupModel(for: .dictation, configuration: configuration)

        XCTAssertEqual(loadedASRModelIDs, [dictationModelID])
        XCTAssertEqual(loadedASRModelIDs.first, settings.resolvedTranscriptionSelection(for: .meeting).selectedModel)
    }

    func testDictationWarmupDoesNotLoadDiarizationEvenWhenMeetingDiarizationEnabled() async throws {
        let settings = AppSettingsStore.shared
        let originalDiarizationEnabled = settings.isDiarizationEnabled
        defer { settings.isDiarizationEnabled = originalDiarizationEnabled }
        settings.isDiarizationEnabled = true

        let configuration = DomainTranscriptionRequestConfiguration(
            providerID: MeetingAssistantCoreInfrastructure.TranscriptionProvider.local.rawValue,
            modelID: LocalTranscriptionModel.parakeetTdt06BV3.rawValue,
            inputLanguageCode: nil,
        )

        let client = makeTestClient()
        try await client.warmupModel(for: .dictation, configuration: configuration)

        XCTAssertEqual(loadedASRModelIDs.count, 1)
        XCTAssertEqual(diarizationWarmupCount, 0)
    }

    func testMeetingWarmupLoadsDiarizationWhenEnabled() async throws {
        let settings = AppSettingsStore.shared
        let originalMeetingEnabled = settings.isMeetingTranscriptionEnabled
        let originalDiarizationEnabled = settings.isDiarizationEnabled
        defer {
            settings.isMeetingTranscriptionEnabled = originalMeetingEnabled
            settings.isDiarizationEnabled = originalDiarizationEnabled
        }
        settings.isMeetingTranscriptionEnabled = true
        settings.isDiarizationEnabled = true

        let client = makeTestClient()
        try await client.warmupModel(for: .meeting, configuration: nil)

        XCTAssertEqual(loadedASRModelIDs.count, 1)
        XCTAssertEqual(diarizationWarmupCount, 1)
    }

    private func makeTestClient() -> TranscriptionClient {
        let client = TranscriptionClient(settingsStore: AppSettingsStore.shared)
        client.localASRWarmupLoader = { [weak self] modelID in
            self?.loadedASRModelIDs.append(modelID)
        }
        client.diarizationWarmupLoader = { [weak self] in
            self?.diarizationWarmupCount += 1
        }
        return client
    }
}
