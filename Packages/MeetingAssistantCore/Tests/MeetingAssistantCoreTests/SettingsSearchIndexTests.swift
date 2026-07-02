@testable import MeetingAssistantCoreUI
import XCTest

final class SettingsSearchIndexTests: XCTestCase {
    func testNormalizedRemovesDiacriticsAndCase() {
        let normalized = SettingsSearchIndex.normalized("Transcrição")

        XCTAssertEqual(normalized, "transcricao")
    }

    func testSectionMappingRoutesMeetingsKeysToMeetingsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.meetings.template")

        XCTAssertEqual(section, .meetings)
    }

    func testResultsIncludeSystemSectionForAudioQuery() {
        let audioTitle = "settings.section.audio".localized
        guard audioTitle != "settings.section.audio" else { return }

        let results = SettingsSearchIndex.results(for: audioTitle)

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains(where: { $0.section == .system }))
        XCTAssertTrue(results.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
    }

    func testSectionMappingRoutesIntegrationKeysToIntegrationsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.integrations.header_desc")

        XCTAssertEqual(section, .integrations)
    }

    func testSectionMappingRoutesMeetingCapabilityKeyToMeetingsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.capabilities.meeting_transcription")

        XCTAssertEqual(section, .meetings)
    }

    func testSectionMappingRoutesIntegrationCapabilityKeyToIntegrationsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.capabilities.assistant_integrations")

        XCTAssertEqual(section, .integrations)
    }

    func testSectionMappingRoutesStylesKeysToDictationSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.styles.title")

        XCTAssertEqual(section, .dictation)
    }

    func testSectionMappingRoutesDictationModelSelectorToDictationSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.enhancements.selector.dictation.title")

        XCTAssertEqual(section, .dictation)
    }

    func testSectionMappingRoutesMeetingModelSelectorToMeetingsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.enhancements.selector.meeting.title")

        XCTAssertEqual(section, .meetings)
    }

    func testSectionMappingRoutesAIProviderSetupToIntelligenceSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.enhancements.provider_models.title")

        XCTAssertEqual(section, .intelligence)
    }

    func testSectionMappingRoutesGeneralAudioFormatToSystemSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.general.audio_format")

        XCTAssertEqual(section, .system)
    }

    func testSectionMappingRoutesAudioDeviceKeyToSystemSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.general.audio_devices")

        XCTAssertEqual(section, .system)
    }

    func testEverySearchableKeyMapsToASection() {
        for key in SettingsSearchIndex.searchableKeys {
            XCTAssertNotNil(
                SettingsSearchIndex.section(forLocalizationKey: key),
                "Key should map to a section: \(key)"
            )
        }
    }

    func testTextContextDescriptionKeyRoutesToIntelligenceSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.text_context.description")
        XCTAssertEqual(section, .intelligence)
    }

    func testProtectedAppsQueryRoutesToIntelligenceSection() {
        assertLocalizedQuery("settings.context_awareness.protect_sensitive_apps", routesTo: .intelligence)
    }

    func testQueryModelsRoutesToIntelligenceSection() {
        assertLocalizedQuery("settings.section.models", routesTo: .intelligence)
    }

    func testQueryTextRoutesToIntelligenceSection() {
        assertLocalizedQuery("settings.section.ai", routesTo: .intelligence)
    }

    func testQueryContextRoutesToIntelligenceSection() {
        assertLocalizedQuery("settings.context_awareness.title", routesTo: .intelligence)
    }

    func testQueryDictionaryRoutesToIntelligenceSection() {
        assertLocalizedQuery("settings.section.vocabulary", routesTo: .intelligence)
    }

    func testReplacementRulesKeyRoutesToIntelligenceSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.vocabulary.replacement_rules")
        XCTAssertEqual(section, .intelligence)
    }

    func testQueryReplacementRulesRoutesToIntelligenceSection() {
        assertLocalizedQuery("settings.vocabulary.replacement_rules", routesTo: .intelligence)
    }

    func testSectionForKeyModelsLabelRoutesToIntelligence() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.section.models")
        XCTAssertEqual(section, .intelligence)
    }

    func testSectionForKeyAILabelRoutesToIntelligence() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.section.ai")
        XCTAssertEqual(section, .intelligence)
    }

    func testSectionForKeyVocabularyLabelRoutesToIntelligence() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.section.vocabulary")
        XCTAssertEqual(section, .intelligence)
    }

    func testRecordingIndicatorSectionRoutesToSystem() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.general.recording_indicator")
        XCTAssertEqual(section, .system)
    }

    func testRecordingIndicatorAnimationSpeedRoutesToSystem() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.general.recording_indicator.animation_speed")
        XCTAssertEqual(section, .system)
    }

    func testModelHubKeysRouteToIntelligenceSection() {
        let aiSection = SettingsSearchIndex.section(forLocalizationKey: "settings.models.ai_provider_models")
        XCTAssertEqual(aiSection, .intelligence)
        let transcriptionSection = SettingsSearchIndex.section(forLocalizationKey: "settings.models.transcription_models")
        XCTAssertEqual(transcriptionSection, .intelligence)
    }

    func testHistoryKeysPreserveActivityHistoryDestination() {
        let destination = SettingsSearchIndex.destination(forLocalizationKey: "settings.section.history")

        XCTAssertEqual(destination, SettingsDestination(section: .activity, activityRoute: .history))
    }

    func testMetricsKeysPreserveActivityModelPerformanceDestination() {
        let destination = SettingsSearchIndex.destination(forLocalizationKey: "settings.section.metrics")

        XCTAssertEqual(destination, SettingsDestination(section: .activity, activityRoute: .modelPerformance))
    }

    func testQueryTranscriptionModelsReturnsIntelligenceSection() {
        assertLocalizedQuery("settings.models.transcription_models", routesTo: .intelligence)
    }

    func testEmptyQueryReturnsNoResults() {
        XCTAssertTrue(SettingsSearchIndex.results(for: "   ").isEmpty)
    }

    private func assertLocalizedQuery(
        _ localizationKey: String,
        routesTo expectedSection: SettingsSection,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let localized = localizationKey.localized
        guard localized != localizationKey else { return }

        let results = SettingsSearchIndex.results(for: localized)
        XCTAssertFalse(results.isEmpty, file: file, line: line)
        XCTAssertTrue(results.contains(where: { $0.section == expectedSection }), file: file, line: line)
    }
}
