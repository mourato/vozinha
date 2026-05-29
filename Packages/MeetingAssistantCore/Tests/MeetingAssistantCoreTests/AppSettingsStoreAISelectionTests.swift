import XCTest
@testable import MeetingAssistantCore

@MainActor
final class AppSettingsStoreAISelectionTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        try AppSettingsTestIsolationLock.acquire()
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
        AppSettingsTestIsolationLock.release()
    }

    func testResolvedEnhancementsConfigurationUsesProviderDefaults() {
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .google,
            selectedModel: "gemini-2.0-flash"
        )

        let resolved = settings.resolvedEnhancementsAIConfiguration
        XCTAssertEqual(resolved.provider, .google)
        XCTAssertEqual(resolved.baseURL, AIProvider.google.defaultBaseURL)
        XCTAssertEqual(resolved.selectedModel, "gemini-2.0-flash")
    }

    func testResolvedEnhancementsConfiguration_NormalizesLegacyGoogleModelID() {
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .google,
            selectedModel: "models/gemini-2.0-flash-001"
        )

        let resolved = settings.resolvedEnhancementsAIConfiguration
        XCTAssertEqual(resolved.provider, .google)
        XCTAssertEqual(resolved.selectedModel, "gemini-2.0-flash")
    }

    func testResolvedEnhancementsConfigurationUsesAPIBaseURLForCustomProvider() {
        settings.updateAIConfiguration(provider: .custom, baseURL: "https://proxy.example.com/v1", selectedModel: "base")
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .custom,
            selectedModel: "custom-model"
        )

        let resolved = settings.resolvedEnhancementsAIConfiguration
        XCTAssertEqual(resolved.provider, .custom)
        XCTAssertEqual(resolved.baseURL, "https://proxy.example.com/v1")
        XCTAssertEqual(resolved.selectedModel, "custom-model")
    }

    func testResetDefaultsEnablesMeetingQnA() {
        settings.meetingQnAEnabled = false
        settings.resetToDefaults()

        XCTAssertTrue(settings.meetingQnAEnabled)
    }

    func testResetDefaultsDisablesDictationStructuredPostProcessing() {
        settings.dictationStructuredPostProcessingEnabled = true

        settings.resetToDefaults()

        XCTAssertFalse(settings.dictationStructuredPostProcessingEnabled)
    }

    func testResetDefaultsEnablesSmartSpacingAndCapitalization() {
        settings.smartSpacingAndCapitalizationEnabled = false

        settings.resetToDefaults()

        XCTAssertTrue(settings.smartSpacingAndCapitalizationEnabled)
    }

    func testResetDefaultsRestoresMeetingNotesTypographySettings() {
        settings.meetingNotesFontFamilyKey = "Helvetica"
        settings.meetingNotesFontSize = 24

        settings.resetToDefaults()

        XCTAssertEqual(settings.meetingNotesFontFamilyKey, "__system__")
        XCTAssertEqual(settings.meetingNotesFontSize, 16, accuracy: 0.0001)
    }

    func testMeetingNotesTypographySettingsNormalizeAndPersist() {
        settings.meetingNotesFontFamilyKey = "   "
        settings.meetingNotesFontSize = 15

        XCTAssertEqual(settings.meetingNotesFontFamilyKey, "__system__")
        XCTAssertEqual(settings.meetingNotesFontSize, 14, accuracy: 0.0001)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "meetingNotesFontFamilyKey"),
            "__system__"
        )
        let persistedSize = UserDefaults.standard.object(forKey: "meetingNotesFontSize") as? Double
        XCTAssertNotNil(persistedSize)
        XCTAssertEqual(persistedSize ?? 0, 14, accuracy: 0.0001)
    }

    func testDictationStructuredPostProcessingSettingIsPersisted() {
        settings.dictationStructuredPostProcessingEnabled = true
        XCTAssertEqual(
            UserDefaults.standard.object(forKey: "dictationStructuredPostProcessingEnabled") as? Bool,
            true
        )

        settings.dictationStructuredPostProcessingEnabled = false
        XCTAssertEqual(
            UserDefaults.standard.object(forKey: "dictationStructuredPostProcessingEnabled") as? Bool,
            false
        )
    }

    func testModelResidencyTimeoutDefaultsToThirtyMinutes() {
        XCTAssertEqual(settings.modelResidencyTimeout, .minutes30)
    }

    func testModelResidencyTimeoutResetReturnsToThirtyMinutes() {
        settings.modelResidencyTimeout = .minutes5

        settings.resetToDefaults()

        XCTAssertEqual(settings.modelResidencyTimeout, .minutes30)
    }

    func testModelResidencyTimeoutSettingIsPersisted() {
        settings.modelResidencyTimeout = .minutes60
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "modelResidencyTimeout"),
            AppSettingsStore.ModelResidencyTimeoutOption.minutes60.rawValue
        )

        settings.modelResidencyTimeout = .never
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "modelResidencyTimeout"),
            AppSettingsStore.ModelResidencyTimeoutOption.never.rawValue
        )
    }

    func testTranscriptionInputLanguageHintDefaultsToAutomatic() {
        XCTAssertEqual(settings.transcriptionInputLanguageHint, .automatic)
    }

    func testTranscriptionInputLanguageHintSettingIsPersisted() {
        settings.transcriptionInputLanguageHint = .portuguese

        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "transcriptionInputLanguageHint"),
            TranscriptionInputLanguageHint.portuguese.rawValue
        )
    }

    func testResolvedTranscriptionInputLanguageCode_ResolvesAcrossExecutionModes() {
        settings.transcriptionInputLanguageHint = .portuguese
        settings.updateTranscriptionDictationSelection(
            provider: .groq,
            model: "whisper-large-v3"
        )

        XCTAssertEqual(settings.resolvedTranscriptionInputLanguageCode(for: .meeting), "pt")
        XCTAssertEqual(settings.resolvedTranscriptionInputLanguageCode(for: .dictation), "pt")
        XCTAssertEqual(settings.resolvedTranscriptionInputLanguageCode(for: .assistant), "pt")
    }

    func testResolvedTranscriptionInputLanguageCode_AutomaticReturnsNil() {
        settings.transcriptionInputLanguageHint = .automatic

        XCTAssertNil(settings.resolvedTranscriptionInputLanguageCode(for: .meeting))
        XCTAssertNil(settings.resolvedTranscriptionInputLanguageCode(for: .dictation))
    }

    func testTranscriptionInputLanguageHint_AllCasesMatchSharedProviderSupport() {
        let allCases = TranscriptionInputLanguageHint.allCases
        let expected: [TranscriptionInputLanguageHint] = [
            .automatic,
            .german,
            .english,
            .spanish,
            .french,
            .italian,
            .portuguese,
            .greek,
            .dutch,
            .polish,
        ]

        XCTAssertEqual(allCases, expected)
    }

    func testUpdateEnhancementsProviderClearsSelectedModel() {
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .openai,
            selectedModel: "gpt-4o-mini"
        )

        settings.updateEnhancementsProvider(.anthropic)

        XCTAssertEqual(settings.enhancementsAISelection.provider, .anthropic)
        XCTAssertEqual(settings.enhancementsAISelection.selectedModel, "")
    }

    func testEnhancementsInferenceReadinessIssue_MissingModel() {
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .openai,
            selectedModel: "   "
        )

        let issue = settings.enhancementsInferenceReadinessIssue(apiKeyExists: { _ in true })

        XCTAssertEqual(issue, .missingModel)
    }

    func testEnhancementsInferenceReadinessIssue_ReturnsNilWhenConfigurationIsReady() {
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .openai,
            selectedModel: "gpt-4o-mini"
        )

        let issue = settings.enhancementsInferenceReadinessIssue(apiKeyExists: { _ in true })

        XCTAssertNil(issue)
    }

    func testEnhancementsInferenceReadinessIssue_UsesRegistrationScopedKeyForSelectedEntry() throws {
        let registration = settings.addEnhancementsProviderRegistration(
            provider: .custom,
            displayName: "Proxy",
            baseURLOverride: "https://proxy.example/v1"
        )
        let registrationID = try XCTUnwrap(registration?.id)

        settings.updateEnhancementsSelection(
            registrationID: registrationID,
            model: "custom-model",
            for: .dictation
        )

        let issue = settings.enhancementsInferenceReadinessIssue(
            for: .dictation,
            apiKeyExists: { _ in false },
            registrationAPIKeyExists: { $0 == registrationID }
        )

        XCTAssertNil(issue)
    }

    func testBackfillEnhancementsSelectionModels_FillsMeetingSelectionFromLegacyConfiguration() {
        settings.updateAIConfiguration(
            provider: .openai,
            baseURL: AIProvider.openai.defaultBaseURL,
            selectedModel: "gpt-4o-mini"
        )
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .openai, selectedModel: " ")
        settings.enhancementsProviderSelectedModels = [:]

        settings.backfillEnhancementsSelectionModelsIfNeeded()

        XCTAssertEqual(settings.enhancementsAISelection.selectedModel, "gpt-4o-mini")
        XCTAssertEqual(settings.enhancementsProviderSelectedModels[AIProvider.openai.rawValue], "gpt-4o-mini")
    }

    func testBackfillEnhancementsSelectionModels_FillsDictationSelectionFromProviderStoredModel() {
        settings.enhancementsDictationAISelection = EnhancementsAISelection(provider: .anthropic, selectedModel: "")
        settings.enhancementsProviderSelectedModels = [AIProvider.anthropic.rawValue: "claude-3-7-sonnet"]

        settings.backfillEnhancementsSelectionModelsIfNeeded()

        XCTAssertEqual(settings.enhancementsDictationAISelection.selectedModel, "claude-3-7-sonnet")
    }

    func testBackfillEnhancementsSelectionModels_AssistantUsesBackfilledDictationSelection() {
        settings.enhancementsDictationAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "")
        settings.enhancementsProviderSelectedModels = [AIProvider.openai.rawValue: "gpt-4.1-mini"]

        settings.backfillEnhancementsSelectionModelsIfNeeded()

        let assistantConfiguration = settings.resolvedEnhancementsAIConfiguration(for: .assistant)
        XCTAssertEqual(assistantConfiguration.provider, .openai)
        XCTAssertEqual(assistantConfiguration.selectedModel, "gpt-4.1-mini")
    }

    func testBackfillEnhancementsSelectionModels_DoesNotOverrideExistingSelection() {
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .openai,
            selectedModel: "gpt-4.1-mini"
        )
        settings.enhancementsProviderSelectedModels = [AIProvider.openai.rawValue: "gpt-4o-mini"]

        settings.backfillEnhancementsSelectionModelsIfNeeded()

        XCTAssertEqual(settings.enhancementsAISelection.selectedModel, "gpt-4.1-mini")
        XCTAssertEqual(settings.enhancementsProviderSelectedModels[AIProvider.openai.rawValue], "gpt-4.1-mini")
    }

    func testBackfillEnhancementsSelectionModels_DoesNotFillWhenNoValidLegacySourceExists() {
        settings.updateAIConfiguration(
            provider: .openai,
            baseURL: AIProvider.openai.defaultBaseURL,
            selectedModel: "   "
        )
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .google, selectedModel: " ")
        settings.enhancementsProviderSelectedModels = [:]

        settings.backfillEnhancementsSelectionModelsIfNeeded()

        XCTAssertEqual(settings.enhancementsAISelection.selectedModel, "")
        XCTAssertNil(settings.enhancementsProviderSelectedModels[AIProvider.google.rawValue])
    }

    func testBackfillEnhancementsSelectionModels_NormalizesLegacyGoogleModelID() {
        settings.updateAIConfiguration(
            provider: .google,
            baseURL: AIProvider.google.defaultBaseURL,
            selectedModel: "models/gemini-2.0-flash-001"
        )
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .google, selectedModel: "")
        settings.enhancementsProviderSelectedModels = [:]

        settings.backfillEnhancementsSelectionModelsIfNeeded()

        XCTAssertEqual(settings.enhancementsAISelection.selectedModel, "gemini-2.0-flash")
        XCTAssertEqual(settings.enhancementsProviderSelectedModels[AIProvider.google.rawValue], "gemini-2.0-flash")
    }

    func testUpdateEnhancementsProviderSelectedModel_NormalizesGoogleModelID() {
        settings.updateEnhancementsProviderSelectedModel("models/gemini-2.0-flash-001", for: .google)

        XCTAssertEqual(settings.enhancementsSelectedModel(for: .google), "gemini-2.0-flash")
        XCTAssertEqual(settings.enhancementsProviderSelectedModels[AIProvider.google.rawValue], "gemini-2.0-flash")
    }

    func testCanAddEnhancementsProviderRegistration_EnforcesBuiltInUniqueness() {
        XCTAssertTrue(settings.canAddEnhancementsProviderRegistration(.openai))

        let registration = settings.addEnhancementsProviderRegistration(provider: .openai)

        XCTAssertNotNil(registration)
        XCTAssertFalse(settings.canAddEnhancementsProviderRegistration(.openai))
    }

    func testAddEnhancementsProviderRegistration_AllowsMultipleCustomEntries() {
        let firstCustom = settings.addEnhancementsProviderRegistration(
            provider: .custom,
            displayName: "Gateway A",
            baseURLOverride: "https://gateway-a.example/v1"
        )
        let secondCustom = settings.addEnhancementsProviderRegistration(
            provider: .custom,
            displayName: "Gateway B",
            baseURLOverride: "https://gateway-b.example/v1"
        )

        XCTAssertNotNil(firstCustom)
        XCTAssertNotNil(secondCustom)
        XCTAssertEqual(settings.enhancementsRegistrations(for: .custom).count, 2)
        XCTAssertNotEqual(firstCustom?.id, secondCustom?.id)
    }

    func testAddEnhancementsProviderRegistration_PersistsCustomIconForCustomProvider() {
        let registration = settings.addEnhancementsProviderRegistration(
            provider: .custom,
            displayName: "Gateway A",
            baseURLOverride: "https://gateway-a.example/v1",
            iconSystemName: "terminal"
        )

        XCTAssertEqual(registration?.iconSystemName, "terminal")
        XCTAssertEqual(settings.enhancementsRegistrations(for: .custom).first?.iconSystemName, "terminal")
    }

    func testUpdateEnhancementsProviderRegistration_ClearsCustomIconForBuiltInProvider() {
        let registration = settings.addEnhancementsProviderRegistration(provider: .openai)
        var updated = registration
        updated?.iconSystemName = "terminal"

        if let updated {
            settings.updateEnhancementsProviderRegistration(updated)
        }

        XCTAssertNil(settings.enhancementsRegistrations(for: .openai).first?.iconSystemName)
    }

    func testRemoveEnhancementsProviderRegistration_ClearsSelectedEntryModel() throws {
        let custom = settings.addEnhancementsProviderRegistration(
            provider: .custom,
            displayName: "Custom Proxy",
            baseURLOverride: "https://proxy.example/v1"
        )
        let customID = try XCTUnwrap(custom?.id)

        settings.updateEnhancementsSelection(
            registrationID: customID,
            model: "custom-model",
            for: .meeting
        )

        XCTAssertEqual(settings.enhancementsAISelection.registrationID, customID)
        XCTAssertEqual(settings.enhancementsAISelection.selectedModel, "custom-model")

        settings.removeEnhancementsProviderRegistration(id: customID)

        XCTAssertNil(settings.enhancementsAISelection.registrationID)
        XCTAssertEqual(settings.enhancementsAISelection.selectedModel, "")
        XCTAssertTrue(settings.enhancementsRegistrations(for: .custom).isEmpty)
    }

    func testResolvedTranscriptionSelection_MeetingAlwaysUsesLocalProvider() {
        settings.updateTranscriptionDictationSelection(
            provider: .groq,
            model: "whisper-large-v3"
        )

        let resolved = settings.resolvedTranscriptionSelection(for: .meeting)

        XCTAssertEqual(resolved.provider, .local)
        XCTAssertEqual(resolved.selectedModel, MeetingAssistantCoreInfrastructure.TranscriptionProvider.localModelID)
    }

    func testResolvedTranscriptionSelection_MeetingUsesLastSelectedLocalModel() {
        settings.updateTranscriptionDictationSelection(
            provider: .local,
            model: MeetingAssistantCoreInfrastructure.TranscriptionProvider.cohereLocalModelID
        )
        settings.updateTranscriptionDictationSelection(
            provider: .groq,
            model: "whisper-large-v3"
        )

        let resolved = settings.resolvedTranscriptionSelection(for: .meeting)

        XCTAssertEqual(resolved.provider, .local)
        XCTAssertEqual(
            resolved.selectedModel,
            MeetingAssistantCoreInfrastructure.TranscriptionProvider.cohereLocalModelID
        )
    }

    func testResolvedTranscriptionSelection_DictationFollowsConfiguredProvider() {
        settings.updateTranscriptionDictationSelection(
            provider: .groq,
            model: "whisper-large-v3"
        )

        let resolved = settings.resolvedTranscriptionSelection(for: .dictation)

        XCTAssertEqual(resolved.provider, .groq)
        XCTAssertEqual(resolved.selectedModel, "whisper-large-v3")
    }

    func testResolvedTranscriptionSelection_AssistantFollowsConfiguredProvider() {
        settings.updateTranscriptionDictationSelection(
            provider: .groq,
            model: "whisper-large-v3"
        )

        let resolved = settings.resolvedTranscriptionSelection(for: .assistant)

        XCTAssertEqual(resolved.provider, .groq)
        XCTAssertEqual(resolved.selectedModel, "whisper-large-v3")
    }

    func testSupportsIncrementalTranscription_DisabledForGroqDictationEnabledForMeeting() {
        settings.updateTranscriptionDictationSelection(
            provider: .groq,
            model: "whisper-large-v3-turbo"
        )

        XCTAssertFalse(settings.supportsIncrementalTranscription(for: .dictation))
        XCTAssertTrue(settings.supportsIncrementalTranscription(for: .meeting))
    }

    func testSupportsIncrementalTranscription_DisabledForGroqAssistantEnabledForMeeting() {
        settings.updateTranscriptionDictationSelection(
            provider: .groq,
            model: "whisper-large-v3-turbo"
        )

        XCTAssertFalse(settings.supportsIncrementalTranscription(for: .assistant))
        XCTAssertTrue(settings.supportsIncrementalTranscription(for: .meeting))
    }

    func testSupportsIncrementalTranscription_DisabledWhenMeetingLocalModelDoesNotSupportIt() {
        settings.updateTranscriptionDictationSelection(
            provider: .local,
            model: MeetingAssistantCoreInfrastructure.TranscriptionProvider.cohereLocalModelID
        )
        settings.updateTranscriptionDictationSelection(
            provider: .groq,
            model: "whisper-large-v3-turbo"
        )

        XCTAssertFalse(settings.supportsIncrementalTranscription(for: .meeting))
    }

    func testResolvedTranscriptionSelection_DictationSupportsElevenLabsProvider() {
        settings.updateTranscriptionDictationSelection(
            provider: .elevenLabs,
            model: "scribe_v2"
        )

        let resolved = settings.resolvedTranscriptionSelection(for: .dictation)

        XCTAssertEqual(resolved.provider, .elevenLabs)
        XCTAssertEqual(resolved.selectedModel, "scribe_v2")
    }

    func testSupportsIncrementalTranscription_DisabledForElevenLabsDictationEnabledForMeeting() {
        settings.updateTranscriptionDictationSelection(
            provider: .elevenLabs,
            model: "scribe_v1"
        )

        XCTAssertFalse(settings.supportsIncrementalTranscription(for: .dictation))
        XCTAssertTrue(settings.supportsIncrementalTranscription(for: .meeting))
    }
}
