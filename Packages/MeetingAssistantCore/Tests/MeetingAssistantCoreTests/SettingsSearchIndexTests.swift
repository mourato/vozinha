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
        XCTAssertTrue(results.contains(where: { $0.section == .system }))
        XCTAssertTrue(results.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
    }

    func testSectionMappingRoutesIntegrationKeysToIntegrationsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.integrations.header_desc")

        XCTAssertEqual(section, .modes)
    }

    func testSectionMappingRoutesMeetingCapabilityKeyToMeetingsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.capabilities.meeting_transcription")

        XCTAssertEqual(section, .meetings)
    }

    func testSectionMappingRoutesIntegrationCapabilityKeyToIntegrationsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.capabilities.assistant_integrations")

        XCTAssertEqual(section, .modes)
    }

    func testSectionMappingRoutesStylesKeysToModesSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.styles.title")

        XCTAssertEqual(section, .modes)
    }

    func testSectionMappingRoutesDictationModelSelectorToDictationSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.enhancements.selector.dictation.title")

        XCTAssertEqual(section, .modes)
    }

    func testSectionMappingRoutesMeetingModelSelectorToMeetingsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.enhancements.selector.meeting.title")

        XCTAssertEqual(section, .meetings)
    }

    func testSectionMappingRoutesAIProviderSetupToSettingsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.enhancements.provider_models.title")

        XCTAssertEqual(section, .system)
    }

    func testSectionMappingRoutesGeneralAudioFormatToAudioSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.general.audio_format")

        XCTAssertEqual(section, .system)
    }

    func testSectionMappingRoutesAudioDeviceKeyToAudioSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.general.audio_devices")

        XCTAssertEqual(section, .system)
    }

    func testEverySearchableKeyMapsToASection() {
        for key in SettingsSearchIndex.searchableKeys {
            XCTAssertNotNil(
                SettingsSearchIndex.section(forLocalizationKey: key),
                "Key should map to a section: \(key)",
            )
        }
    }

    func testEverySearchableKeyIsRoutedOrExplicitlyUnrouted() {
        let searchableKeys = Set(SettingsSearchIndex.searchableKeys)
        let explicitlyUnroutedKeys = SettingsSearchIndex.explicitlyUnroutedKeys
        let missingRoutes = searchableKeys
            .subtracting(explicitlyUnroutedKeys)
            .filter { SettingsSearchIndex.destination(forLocalizationKey: $0) == nil }

        XCTAssertTrue(
            explicitlyUnroutedKeys.isSubset(of: searchableKeys),
            "Explicitly unrouted keys must remain searchable: \(explicitlyUnroutedKeys.subtracting(searchableKeys))",
        )
        XCTAssertTrue(missingRoutes.isEmpty, "Searchable keys need a route or explicit classification: \(missingRoutes)")
    }

    func testPrefixManifestRoutesEveryDeclaredFamily() {
        for route in SettingsSearchRouteManifest.prefixRoutes {
            let fixtureKey = route.prefix + "fixture"
            XCTAssertEqual(
                SettingsSearchIndex.destination(forLocalizationKey: fixtureKey),
                route.destination,
                "Prefix should route deterministically: \(route.prefix)",
            )
        }
    }

    func testOverlappingPrefixRoutesPreferTheLongestMatch() {
        XCTAssertEqual(
            SettingsSearchIndex.destination(forLocalizationKey: "settings.enhancements.selector.meeting.title"),
            SettingsSection.meetings.destination,
        )
        XCTAssertEqual(
            SettingsSearchIndex.destination(forLocalizationKey: "settings.models.routing.active_model"),
            SettingsDestination(section: .modes),
        )
        XCTAssertEqual(
            SettingsSearchIndex.destination(forLocalizationKey: "settings.service.transcription_provider.provider.title"),
            SettingsDestination(section: .modes),
        )
    }

    func testExplicitExceptionsPreserveLegacyDestinations() {
        XCTAssertEqual(
            SettingsSearchIndex.destination(forLocalizationKey: "settings.section.metrics"),
            SettingsSection.metrics.destination,
        )
        XCTAssertEqual(
            SettingsSearchIndex.destination(forLocalizationKey: "settings.permissions.description"),
            SettingsDestination(section: .system),
        )
        XCTAssertEqual(
            SettingsSearchIndex.destination(forLocalizationKey: "settings.general.audio_format"),
            SettingsSection.audio.destination,
        )
        XCTAssertEqual(
            SettingsSearchIndex.destination(forLocalizationKey: "settings.context_awareness.accessibility_text"),
            SettingsSection.modes.destination,
        )
    }

    func testTextContextDescriptionKeyRoutesToSettingsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.text_context.description")
        XCTAssertEqual(section, .system)
    }

    func testProtectedAppsQueryRoutesToSettingsSection() {
        assertLocalizedQuery("settings.context_awareness.protect_sensitive_apps", routesTo: .system)
    }

    func testQueryModelsRoutesToSettingsSection() {
        assertLocalizedQuery("settings.section.models", routesTo: .system)
    }

    func testQueryTextRoutesToModesSection() {
        assertLocalizedQuery("settings.section.ai", routesTo: .modes)
    }

    func testQueryContextSourcesRoutesToModesSection() {
        assertLocalizedQuery("settings.styles.editor.context_sources", routesTo: .modes)
        assertLocalizedQuery("settings.context_awareness.accessibility_text", routesTo: .modes)
        assertLocalizedQuery("settings.context_awareness.clipboard", routesTo: .modes)
    }

    func testQueryDictionaryRoutesToSettingsSection() {
        assertLocalizedQuery("settings.section.vocabulary", routesTo: .system)
    }

    func testReplacementRulesKeyRoutesToSettingsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.vocabulary.replacement_rules")
        XCTAssertEqual(section, .system)
    }

    func testQueryReplacementRulesRoutesToSettingsSection() {
        assertLocalizedQuery("settings.vocabulary.replacement_rules", routesTo: .system)
    }

    func testSectionForKeyModelsLabelRoutesToSettings() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.section.models")
        XCTAssertEqual(section, .system)
    }

    func testSectionForKeyAILabelRoutesToModes() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.section.ai")
        XCTAssertEqual(section, .modes)
    }

    func testSectionForKeyVocabularyLabelRoutesToSettings() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.section.vocabulary")
        XCTAssertEqual(section, .system)
    }

    func testRecordingIndicatorSectionRoutesToSystem() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.general.recording_indicator")
        XCTAssertEqual(section, .system)
    }

    func testRecordingIndicatorAnimationSpeedRoutesToSystem() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.general.recording_indicator.animation_speed")
        XCTAssertEqual(section, .system)
    }

    func testPermissionsQueryRoutesToSystemPermissionsDestination() {
        let destination = SettingsSearchIndex.destination(forLocalizationKey: "settings.permissions.description")
        XCTAssertEqual(destination, SettingsDestination(section: .system))
    }

    func testModelHubKeysRouteToSettingsSection() {
        let aiSection = SettingsSearchIndex.section(forLocalizationKey: "settings.models.ai_provider_models")
        XCTAssertEqual(aiSection, .system)
        let transcriptionSection = SettingsSearchIndex.section(forLocalizationKey: "settings.models.transcription_models")
        XCTAssertEqual(transcriptionSection, .system)
    }

    func testHistoryKeysPreserveActivityHistoryDestination() {
        let destination = SettingsSearchIndex.destination(forLocalizationKey: "settings.section.history")

        XCTAssertEqual(destination, SettingsDestination(section: .activity, activityRoute: .history))
    }

    func testMetricsKeysPreserveActivityModelPerformanceDestination() {
        let destination = SettingsSearchIndex.destination(forLocalizationKey: "settings.section.metrics")

        XCTAssertEqual(
            destination,
            SettingsDestination(
                section: .activity,
                activityRoute: .root,
                activityPendingSheet: .performance,
            ),
        )
    }

    func testProtectedAppsDestinationExpandsProtectedAppsSection() {
        let destination = SettingsSearchIndex.destination(
            forLocalizationKey: "settings.context_awareness.protect_sensitive_apps",
        )

        XCTAssertEqual(
            destination,
            SettingsDestination(section: .system, expandProtectedApps: true),
        )
    }

    func testQueryTranscriptionModelsReturnsSettingsSection() {
        assertLocalizedQuery("settings.models.transcription_models", routesTo: .system)
    }

    func testEmptyQueryReturnsNoResults() {
        XCTAssertTrue(SettingsSearchIndex.results(for: "   ").isEmpty)
    }

    private func assertLocalizedQuery(
        _ localizationKey: String,
        routesTo expectedSection: SettingsSection,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) {
        let localized = localizationKey.localized
        guard localized != localizationKey else { return }

        let results = SettingsSearchIndex.results(for: localized)
        XCTAssertFalse(results.isEmpty, file: file, line: line)
        XCTAssertTrue(results.contains(where: { $0.section == expectedSection }), file: file, line: line)
    }
}
