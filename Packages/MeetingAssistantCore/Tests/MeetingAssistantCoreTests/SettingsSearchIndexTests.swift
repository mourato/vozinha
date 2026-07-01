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

    func testResultsIncludeAudioSectionForAudioQuery() {
        let audioTitle = "settings.section.audio".localized
        guard audioTitle != "settings.section.audio" else { return }

        let results = SettingsSearchIndex.results(for: audioTitle)

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains(where: { $0.section == .audio }))
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

    func testSectionMappingRoutesAIProviderSetupToModelsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.enhancements.provider_models.title")

        XCTAssertEqual(section, .models)
    }

    func testSectionMappingKeepsGeneralAudioFormatInGeneralSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.general.audio_format")

        XCTAssertEqual(section, .general)
    }

    func testSectionMappingRoutesAudioDeviceKeyToAudioSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.general.audio_devices")

        XCTAssertEqual(section, .audio)
    }

    func testEverySearchableKeyMapsToASection() {
        for key in SettingsSearchIndex.searchableKeys {
            XCTAssertNotNil(
                SettingsSearchIndex.section(forLocalizationKey: key),
                "Key should map to a section: \(key)"
            )
        }
    }

    func testTextContextDescriptionKeyRoutesToEnhancementsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.text_context.description")
        XCTAssertEqual(section, .enhancements)
    }

    func testProtectedAppsQueryRoutesToEnhancementsSection() {
        assertLocalizedQuery("settings.context_awareness.protect_sensitive_apps", routesTo: .enhancements)
    }

    func testQueryModelsRoutesToModelsSection() {
        assertLocalizedQuery("settings.section.models", routesTo: .models)
    }

    func testQueryTextRoutesToEnhancementsSection() {
        assertLocalizedQuery("settings.section.ai", routesTo: .enhancements)
    }

    func testQueryContextRoutesToEnhancementsSection() {
        assertLocalizedQuery("settings.context_awareness.title", routesTo: .enhancements)
    }

    func testQueryDictionaryRoutesToVocabularySection() {
        assertLocalizedQuery("settings.section.vocabulary", routesTo: .vocabulary)
    }

    func testReplacementRulesKeyRoutesToVocabularySection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.vocabulary.replacement_rules")
        XCTAssertEqual(section, .vocabulary)
    }

    func testQueryReplacementRulesRoutesToVocabularySection() {
        assertLocalizedQuery("settings.vocabulary.replacement_rules", routesTo: .vocabulary)
    }

    func testSectionForKeyModelsLabelRoutesToModels() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.section.models")
        XCTAssertEqual(section, .models)
    }

    func testSectionForKeyAILabelRoutesToEnhancements() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.section.ai")
        XCTAssertEqual(section, .enhancements)
    }

    func testSectionForKeyVocabularyLabelRoutesToVocabulary() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.section.vocabulary")
        XCTAssertEqual(section, .vocabulary)
    }

    func testRecordingIndicatorSectionRoutesToAudio() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.general.recording_indicator")
        XCTAssertEqual(section, .audio)
    }

    func testRecordingIndicatorAnimationSpeedRoutesToAudio() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.general.recording_indicator.animation_speed")
        XCTAssertEqual(section, .audio)
    }

    func testModelHubKeysRouteToModelsSection() {
        let aiSection = SettingsSearchIndex.section(forLocalizationKey: "settings.models.ai_provider_models")
        XCTAssertEqual(aiSection, .models)
        let transcriptionSection = SettingsSearchIndex.section(forLocalizationKey: "settings.models.transcription_models")
        XCTAssertEqual(transcriptionSection, .models)
    }

    func testQueryTranscriptionModelsReturnsModelsSection() {
        assertLocalizedQuery("settings.models.transcription_models", routesTo: .models)
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
