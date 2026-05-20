import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain

// MARK: - Initialization Helpers

extension AppSettingsStore {
    private static let meetingNotesMarkdownReadEnabledKey = "storage.meeting_notes.markdown.read_enabled.v1"

    /// Holds temporarily loaded values during initialization to avoid multiple UserDefaults reads.
    struct InitializationContext {
        var loadedAIConfiguration: AIConfiguration
        var loadedEnhancementsSelection: EnhancementsAISelection
        var loadedDictationSelection: EnhancementsAISelection
        var loadedAssistantShortcutDefinition: ShortcutDefinition?
        var loadedDictationShortcutDefinition: ShortcutDefinition?
        var loadedMeetingShortcutDefinition: ShortcutDefinition?
        var loadedIntegrations: [AssistantIntegrationConfig]?
        var loadedContextAwarenessEnabled: Bool
        var hasPersistedLegacyPerTargetBrowsers: Bool
        var hasGlobalBrowserSetting: Bool
    }

    /// Creates the initialization context by loading all required values from UserDefaults.
    static func createInitializationContext() -> InitializationContext {
        migrateLegacyUserDefaultsDomainIfNeeded()

        let loadedAIConfiguration = loadAIConfiguration()
        let loadedEnhancementsSelection = loadEnhancementsAISelection(defaultingTo: loadedAIConfiguration)
        let loadedDictationSelection = loadEnhancementsDictationAISelection(defaultingTo: loadedEnhancementsSelection)

        let loadedAssistantShortcutDefinition = loadDecoded(
            ShortcutDefinition.self,
            forKey: Keys.assistantShortcutDefinition
        )
        let loadedDictationShortcutDefinition = loadDecoded(
            ShortcutDefinition.self,
            forKey: Keys.dictationShortcutDefinition
        )
        let loadedMeetingShortcutDefinition = loadDecoded(
            ShortcutDefinition.self,
            forKey: Keys.meetingShortcutDefinition
        )

        let loadedIntegrations = loadDecoded([AssistantIntegrationConfig].self, forKey: Keys.assistantIntegrations)
        let loadedContextAwarenessEnabled = UserDefaults.standard.bool(forKey: Keys.contextAwarenessEnabled)

        let hasPersistedMarkdownWebTargets = UserDefaults.standard.object(forKey: Keys.markdownWebTargets) != nil
        let hasPersistedWebMeetingTargets = UserDefaults.standard.object(forKey: Keys.webMeetingTargets) != nil
        let hasPersistedLegacyPerTargetBrowsers = hasPersistedMarkdownWebTargets || hasPersistedWebMeetingTargets
        let hasGlobalBrowserSetting = UserDefaults.standard.object(forKey: Keys.webTargetBrowserBundleIdentifiers) != nil

        return InitializationContext(
            loadedAIConfiguration: loadedAIConfiguration,
            loadedEnhancementsSelection: loadedEnhancementsSelection,
            loadedDictationSelection: loadedDictationSelection,
            loadedAssistantShortcutDefinition: loadedAssistantShortcutDefinition,
            loadedDictationShortcutDefinition: loadedDictationShortcutDefinition,
            loadedMeetingShortcutDefinition: loadedMeetingShortcutDefinition,
            loadedIntegrations: loadedIntegrations,
            loadedContextAwarenessEnabled: loadedContextAwarenessEnabled,
            hasPersistedLegacyPerTargetBrowsers: hasPersistedLegacyPerTargetBrowsers,
            hasGlobalBrowserSetting: hasGlobalBrowserSetting
        )
    }

    private static func migrateLegacyUserDefaultsDomainIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppIdentity.userDefaultsDomainMigrationFlag) else {
            return
        }

        let currentDomainName = Bundle.main.bundleIdentifier ?? AppIdentity.bundleIdentifier
        guard let legacyDomain = defaults.persistentDomain(forName: AppIdentity.legacyUserDefaultsDomain),
              !legacyDomain.isEmpty
        else {
            defaults.set(true, forKey: AppIdentity.userDefaultsDomainMigrationFlag)
            return
        }

        var currentDomain = defaults.persistentDomain(forName: currentDomainName) ?? [:]
        for (key, value) in legacyDomain where currentDomain[key] == nil {
            currentDomain[key] = value
        }

        defaults.setPersistentDomain(currentDomain, forName: currentDomainName)
        defaults.set(true, forKey: AppIdentity.userDefaultsDomainMigrationFlag)
    }

    // MARK: - Static Initialization Helpers

    /// Struct for AI configuration values to avoid large tuple.
    struct AIConfigurationValues {
        let aiConfiguration: AIConfiguration
        let enhancementsAISelection: EnhancementsAISelection
        let enhancementsDictationAISelection: EnhancementsAISelection
        let enhancementsProviderSelectedModels: [String: String]
        let enhancementsProviderRegistrations: [EnhancementsProviderRegistration]
        let enhancementsProviderSelectedModelsByRegistration: [String: String]
        let transcriptionDictationSelection: TranscriptionProviderSelection
        let transcriptionProviderSelectedModels: [String: String]
    }

    /// Loads AI configuration properties from the context.
    static func loadAIConfigurationValues(from context: InitializationContext) -> AIConfigurationValues {
        let legacyEnhancementsProviderSelectedModels = loadEnhancementsProviderSelectedModels(
            defaultMeetingSelection: context.loadedEnhancementsSelection,
            defaultDictationSelection: context.loadedDictationSelection
        )

        let enhancementsProviderRegistrations = loadEnhancementsProviderRegistrations(
            aiConfiguration: context.loadedAIConfiguration,
            meetingSelection: context.loadedEnhancementsSelection,
            dictationSelection: context.loadedDictationSelection,
            legacyProviderSelectedModels: legacyEnhancementsProviderSelectedModels
        )

        let normalizedMeetingSelection = normalizedEnhancementsSelection(
            context.loadedEnhancementsSelection,
            registrations: enhancementsProviderRegistrations
        )
        let normalizedDictationSelection = normalizedEnhancementsSelection(
            context.loadedDictationSelection,
            registrations: enhancementsProviderRegistrations
        )

        let enhancementsProviderSelectedModelsByRegistration = loadEnhancementsProviderSelectedModelsByRegistration(
            registrations: enhancementsProviderRegistrations,
            legacyProviderSelectedModels: legacyEnhancementsProviderSelectedModels,
            meetingSelection: normalizedMeetingSelection,
            dictationSelection: normalizedDictationSelection
        )

        let transcriptionDictationSelection = loadTranscriptionDictationSelection()
        let transcriptionProviderSelectedModels = loadTranscriptionProviderSelectedModels(
            defaultDictationSelection: transcriptionDictationSelection
        )

        return AIConfigurationValues(
            aiConfiguration: context.loadedAIConfiguration,
            enhancementsAISelection: normalizedMeetingSelection,
            enhancementsDictationAISelection: normalizedDictationSelection,
            enhancementsProviderSelectedModels: legacyEnhancementsProviderSelectedModels,
            enhancementsProviderRegistrations: enhancementsProviderRegistrations,
            enhancementsProviderSelectedModelsByRegistration: enhancementsProviderSelectedModelsByRegistration,
            transcriptionDictationSelection: transcriptionDictationSelection,
            transcriptionProviderSelectedModels: transcriptionProviderSelectedModels
        )
    }

    /// Struct for post-processing settings to avoid large tuple.
    struct PostProcessingSettingsValues {
        let systemPrompt: String
        let userPrompts: [PostProcessingPrompt]
        let dictationPrompts: [PostProcessingPrompt]
        let deletedPromptIds: Set<UUID>
        let postProcessingEnabled: Bool
        let dictationStructuredPostProcessingEnabled: Bool
        let isDiarizationEnabled: Bool
        let modelResidencyTimeout: ModelResidencyTimeoutOption
        let transcriptionInputLanguageHint: TranscriptionInputLanguageHint
        let minSpeakers: Int?
        let maxSpeakers: Int?
        let numSpeakers: Int?
        let audioFormat: AudioFormat
        let selectedPromptId: UUID?
        let dictationSelectedPromptId: UUID?
        let shouldMergeAudioFiles: Bool
    }

    /// Loads post-processing related properties.
    static func loadPostProcessingSettings() -> PostProcessingSettingsValues {
        PostProcessingSettingsValues(
            systemPrompt: UserDefaults.standard.string(forKey: Keys.systemPrompt) ?? AIPromptTemplates.defaultSystemPrompt,
            userPrompts: loadDecoded([PostProcessingPrompt].self, forKey: Keys.userPrompts) ?? [],
            dictationPrompts: loadDecoded([PostProcessingPrompt].self, forKey: Keys.dictationPrompts) ?? [],
            deletedPromptIds: loadDecoded(Set<UUID>.self, forKey: Keys.deletedPromptIds) ?? [],
            postProcessingEnabled: UserDefaults.standard.bool(forKey: Keys.postProcessingEnabled),
            dictationStructuredPostProcessingEnabled: loadBoolDefaultIfUnset(forKey: Keys.dictationStructuredPostProcessingEnabled, defaultValue: false),
            isDiarizationEnabled: UserDefaults.standard.bool(forKey: Keys.isDiarizationEnabled),
            modelResidencyTimeout: loadEnum(forKey: Keys.modelResidencyTimeout, defaultValue: .minutes30),
            transcriptionInputLanguageHint: loadEnum(
                forKey: Keys.transcriptionInputLanguageHint,
                defaultValue: .automatic
            ),
            minSpeakers: loadOptionalInt(forKey: Keys.minSpeakers),
            maxSpeakers: loadOptionalInt(forKey: Keys.maxSpeakers),
            numSpeakers: loadOptionalInt(forKey: Keys.numSpeakers),
            audioFormat: loadEnum(forKey: PostProcessingKeys.audioFormat, defaultValue: .m4a),
            selectedPromptId: loadUUID(forKey: Keys.selectedPromptId),
            dictationSelectedPromptId: loadUUID(forKey: Keys.dictationSelectedPromptId),
            shouldMergeAudioFiles: loadBoolDefaultIfUnset(forKey: PostProcessingKeys.shouldMergeAudioFiles, defaultValue: true)
        )
    }

    struct CapabilitySettingsValues {
        let isMeetingTranscriptionEnabled: Bool
        let isAssistantIntegrationsEnabled: Bool
    }

    static func loadCapabilitySettings() -> CapabilitySettingsValues {
        CapabilitySettingsValues(
            isMeetingTranscriptionEnabled: loadCapabilityToggle(
                forKey: Keys.isMeetingTranscriptionEnabled,
                defaultForNewInstall: false,
                defaultForExistingInstall: true
            ),
            isAssistantIntegrationsEnabled: loadCapabilityToggle(
                forKey: Keys.isAssistantIntegrationsEnabled,
                defaultForNewInstall: false,
                defaultForExistingInstall: true
            )
        )
    }

    /// Struct for audio and language settings to avoid large tuple.
    struct AudioAndLanguageSettingsValues {
        let selectedLanguage: AppLanguage
        let audioDevicePriority: [String]
        let useSystemDefaultInput: Bool
        let microphoneWhenChargingUID: String?
        let microphoneOnBatteryUID: String?
        let recordingMediaHandlingMode: RecordingMediaHandlingMode
        let audioDuckingLevelPercent: Int
        let autoIncreaseMicrophoneVolume: Bool
        let removeSilenceBeforeProcessing: Bool
    }

    /// Loads audio and language settings.
    static func loadAudioAndLanguageSettings() -> AudioAndLanguageSettingsValues {
        let defaults = UserDefaults.standard
        let hasRecordingMediaHandlingMode = defaults.object(forKey: Keys.recordingMediaHandlingMode) != nil
        let hasDuckingEnabled = defaults.object(forKey: Keys.audioDuckingEnabled) != nil
        let hasDuckingLevel = defaults.object(forKey: Keys.audioDuckingLevelPercent) != nil

        let recordingMediaHandlingMode: RecordingMediaHandlingMode
        let audioDuckingLevelPercent: Int

        if hasRecordingMediaHandlingMode {
            recordingMediaHandlingMode = loadEnum(
                forKey: Keys.recordingMediaHandlingMode,
                defaultValue: .none
            )
            audioDuckingLevelPercent = AppSettingsStore.clampedAudioDuckingLevelPercent(
                loadInt(
                    forKey: Keys.audioDuckingLevelPercent,
                    defaultValue: defaultAudioDuckingLevelPercent
                )
            )
            defaults.set(recordingMediaHandlingMode.usesDucking, forKey: Keys.audioDuckingEnabled)
        } else if !hasDuckingEnabled,
                  !hasDuckingLevel,
                  defaults.bool(forKey: Keys.muteOutputDuringRecording)
        {
            // Preserve old behavior for migrated users that had output mute enabled.
            recordingMediaHandlingMode = .duckAudio
            audioDuckingLevelPercent = 0
            defaults.set(recordingMediaHandlingMode.rawValue, forKey: Keys.recordingMediaHandlingMode)
            defaults.set(recordingMediaHandlingMode.usesDucking, forKey: Keys.audioDuckingEnabled)
            defaults.set(audioDuckingLevelPercent, forKey: Keys.audioDuckingLevelPercent)
        } else {
            recordingMediaHandlingMode = loadBoolDefaultIfUnset(
                forKey: Keys.audioDuckingEnabled,
                defaultValue: false
            ) ? .duckAudio : .none
            audioDuckingLevelPercent = AppSettingsStore.clampedAudioDuckingLevelPercent(
                loadInt(
                    forKey: Keys.audioDuckingLevelPercent,
                    defaultValue: defaultAudioDuckingLevelPercent
                )
            )
            defaults.set(recordingMediaHandlingMode.rawValue, forKey: Keys.recordingMediaHandlingMode)
        }

        return AudioAndLanguageSettingsValues(
            selectedLanguage: loadEnum(forKey: Keys.selectedLanguage, defaultValue: .system),
            audioDevicePriority: UserDefaults.standard.stringArray(forKey: Keys.audioDevicePriority) ?? [],
            useSystemDefaultInput: loadBoolDefaultIfUnset(forKey: Keys.useSystemDefaultInput, defaultValue: true),
            microphoneWhenChargingUID: UserDefaults.standard.string(forKey: Keys.microphoneWhenChargingUID),
            microphoneOnBatteryUID: UserDefaults.standard.string(forKey: Keys.microphoneOnBatteryUID),
            recordingMediaHandlingMode: recordingMediaHandlingMode,
            audioDuckingLevelPercent: audioDuckingLevelPercent,
            autoIncreaseMicrophoneVolume: UserDefaults.standard.bool(forKey: Keys.autoIncreaseMicrophoneVolume),
            removeSilenceBeforeProcessing: loadBoolDefaultIfUnset(
                forKey: Keys.removeSilenceBeforeProcessing,
                defaultValue: false
            )
        )
    }

    /// Struct for shortcut activation settings to avoid large tuple.
    struct ShortcutActivationSettingsValues {
        let shortcutActivationMode: ShortcutActivationMode
        let dictationShortcutActivationMode: ShortcutActivationMode
        let shortcutDoubleTapIntervalMilliseconds: Double
        let useEscapeToCancelRecording: Bool
        let selectedPresetKey: PresetShortcutKey
        let dictationSelectedPresetKey: PresetShortcutKey
        let meetingSelectedPresetKey: PresetShortcutKey
        let cancelRecordingShortcutDefinition: ShortcutDefinition?
    }

    /// Loads shortcut activation settings.
    static func loadShortcutActivationSettings() -> ShortcutActivationSettingsValues {
        let rawActivationMode = UserDefaults.standard.string(forKey: Keys.shortcutActivationMode)
        let resolvedActivationMode = rawActivationMode.flatMap { ShortcutActivationMode(rawValue: $0) } ?? .holdOrToggle

        let rawDictationActivationMode = UserDefaults.standard.string(forKey: Keys.dictationShortcutActivationMode)
        let dictationActivationMode = rawDictationActivationMode
            .flatMap { ShortcutActivationMode(rawValue: $0) }
            ?? resolvedActivationMode

        let rawPresetKey = UserDefaults.standard.string(forKey: Keys.selectedPresetKey)
        let presetKey = rawPresetKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .custom

        let rawDictationKey = UserDefaults.standard.string(forKey: Keys.dictationSelectedPresetKey)
        let dictationPresetKey = rawDictationKey.flatMap { PresetShortcutKey(rawValue: $0) }
            ?? (rawPresetKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .custom)

        let rawMeetingKey = UserDefaults.standard.string(forKey: Keys.meetingSelectedPresetKey)
        let meetingPresetKey = rawMeetingKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .custom

        return ShortcutActivationSettingsValues(
            shortcutActivationMode: resolvedActivationMode,
            dictationShortcutActivationMode: dictationActivationMode,
            shortcutDoubleTapIntervalMilliseconds: loadDouble(forKey: Keys.shortcutDoubleTapIntervalMilliseconds, defaultValue: defaultShortcutDoubleTapIntervalMilliseconds),
            useEscapeToCancelRecording: UserDefaults.standard.bool(forKey: Keys.useEscapeToCancelRecording),
            selectedPresetKey: presetKey,
            dictationSelectedPresetKey: dictationPresetKey,
            meetingSelectedPresetKey: meetingPresetKey,
            cancelRecordingShortcutDefinition: loadDecoded(
                ShortcutDefinition.self,
                forKey: Keys.cancelRecordingShortcutDefinition
            )
        )
    }

    /// Loads modifier shortcut gestures.
    static func loadModifierShortcutGestures() -> (
        dictation: ModifierShortcutGesture?,
        assistant: ModifierShortcutGesture?,
        meeting: ModifierShortcutGesture?
    ) {
        (
            loadDecoded(ModifierShortcutGesture.self, forKey: Keys.dictationModifierShortcutGesture),
            loadDecoded(ModifierShortcutGesture.self, forKey: Keys.assistantModifierShortcutGesture),
            loadDecoded(ModifierShortcutGesture.self, forKey: Keys.meetingModifierShortcutGesture)
        )
    }

    /// Struct for assistant settings to avoid large tuple.
    struct AssistantSettingsValues {
        let assistantShortcutActivationMode: ShortcutActivationMode
        let assistantUseEscapeToCancelRecording: Bool
        let assistantUseEnterToStopRecording: Bool
        let assistantSelectedPresetKey: PresetShortcutKey
        let assistantIntegrations: [AssistantIntegrationConfig]
        let assistantSelectedIntegrationId: UUID?
        let assistantRaycastEnabled: Bool
        let assistantRaycastDeepLink: String
    }

    /// Loads assistant-specific settings.
    static func loadAssistantSettings(from context: InitializationContext) -> AssistantSettingsValues {
        let rawAssistantActivation = UserDefaults.standard.string(forKey: Keys.assistantShortcutActivationMode)
        let activationMode = rawAssistantActivation
            .flatMap { ShortcutActivationMode(rawValue: $0) } ?? .holdOrToggle

        let rawAssistantPresetKey = UserDefaults.standard.string(forKey: Keys.assistantSelectedPresetKey)
        let presetKey = rawAssistantPresetKey.flatMap { PresetShortcutKey(rawValue: $0) } ?? .custom

        let rawSelectedIntegrationId = UserDefaults.standard.string(forKey: Keys.assistantSelectedIntegrationId)

        return AssistantSettingsValues(
            assistantShortcutActivationMode: activationMode,
            assistantUseEscapeToCancelRecording: UserDefaults.standard.bool(forKey: Keys.assistantUseEscapeToCancelRecording),
            assistantUseEnterToStopRecording: false,
            assistantSelectedPresetKey: presetKey,
            assistantIntegrations: context.loadedIntegrations ?? [AssistantIntegrationConfig.defaultRaycast],
            assistantSelectedIntegrationId: rawSelectedIntegrationId.flatMap(UUID.init(uuidString:)),
            assistantRaycastEnabled: UserDefaults.standard.bool(forKey: Keys.assistantRaycastEnabled),
            assistantRaycastDeepLink: UserDefaults.standard.string(forKey: Keys.assistantRaycastDeepLink) ?? AssistantIntegrationConfig.defaultRaycastDeepLink
        )
    }

    /// Struct for meeting summary settings to avoid large tuple.
    struct MeetingSummarySettingsValues {
        let meetingTypeAutoDetectEnabled: Bool
        let meetingSummaryOutputLanguage: DictationOutputLanguage
        let meetingPrompts: [PostProcessingPrompt]
        let summaryExportFolder: URL?
        let summaryTemplate: String
        let summaryTemplateEnabled: Bool
        let autoExportSummaries: Bool
        let summaryExportSafetyPolicyLevel: SummaryExportSafetyPolicyLevel
        let meetingNotesFontFamilyKey: String
        let meetingNotesFontSize: Double
        let meetingQnAEnabled: Bool
    }

    /// Loads meeting summary settings.
    static func loadMeetingSummarySettings() -> MeetingSummarySettingsValues {
        var prompts: [PostProcessingPrompt] = []
        if let data = UserDefaults.standard.data(forKey: Keys.meetingPrompts),
           let decoded = try? JSONDecoder().decode([PostProcessingPrompt].self, from: data)
        {
            prompts = decoded
        }

        return MeetingSummarySettingsValues(
            meetingTypeAutoDetectEnabled: UserDefaults.standard.bool(forKey: Keys.meetingTypeAutoDetectEnabled),
            meetingSummaryOutputLanguage: loadEnum(forKey: Keys.meetingSummaryOutputLanguage, defaultValue: .original),
            meetingPrompts: prompts,
            summaryExportFolder: loadURLBookmark(forKey: Keys.summaryExportFolder),
            summaryTemplate: UserDefaults.standard.string(forKey: Keys.summaryTemplate) ?? defaultSummaryTemplate,
            summaryTemplateEnabled: loadBoolDefaultIfUnset(forKey: Keys.summaryTemplateEnabled, defaultValue: true),
            autoExportSummaries: UserDefaults.standard.bool(forKey: Keys.autoExportSummaries),
            summaryExportSafetyPolicyLevel: SummaryExportSafetyPolicyLevel(rawValue: UserDefaults.standard.string(forKey: Keys.summaryExportSafetyPolicyLevel) ?? "") ?? .standard,
            meetingNotesFontFamilyKey: MeetingNotesTypographyDefaults.normalizedFontFamilyKey(
                UserDefaults.standard.string(forKey: Keys.meetingNotesFontFamilyKey) ?? MeetingNotesTypographyDefaults.systemFontFamilyKey
            ),
            meetingNotesFontSize: MeetingNotesTypographyDefaults.normalizedFontSize(
                UserDefaults.standard.object(forKey: Keys.meetingNotesFontSize) as? Double ?? MeetingNotesTypographyDefaults.defaultFontSize
            ),
            meetingQnAEnabled: loadBoolDefaultIfUnset(forKey: Keys.meetingQnAEnabled, defaultValue: true)
        )
    }

    /// Struct for context awareness settings to avoid large tuple.
    struct ContextAwarenessSettingsValues {
        let contextAwarenessEnabled: Bool
        let contextAwarenessExplicitActionOnly: Bool
        let contextAwarenessIncludeClipboard: Bool
        let contextAwarenessIncludeWindowOCR: Bool
        let contextAwarenessIncludeAccessibilityText: Bool
        let contextAwarenessProtectSensitiveApps: Bool
        let contextAwarenessRedactSensitiveData: Bool
        let contextAwarenessExcludedBundleIDs: [String]
    }

    /// Loads context awareness settings.
    static func loadContextAwarenessSettings(from context: InitializationContext) -> ContextAwarenessSettingsValues {
        ContextAwarenessSettingsValues(
            contextAwarenessEnabled: context.loadedContextAwarenessEnabled,
            contextAwarenessExplicitActionOnly: loadBoolDefaultIfUnset(forKey: Keys.contextAwarenessExplicitActionOnly, defaultValue: true),
            contextAwarenessIncludeClipboard: UserDefaults.standard.bool(forKey: Keys.contextAwarenessIncludeClipboard),
            contextAwarenessIncludeWindowOCR: UserDefaults.standard.bool(forKey: Keys.contextAwarenessIncludeWindowOCR),
            contextAwarenessIncludeAccessibilityText: loadBoolDefaultIfUnset(forKey: Keys.contextAwarenessIncludeAccessibilityText, defaultValue: true),
            contextAwarenessProtectSensitiveApps: loadBoolDefaultIfUnset(forKey: Keys.contextAwarenessProtectSensitiveApps, defaultValue: true),
            contextAwarenessRedactSensitiveData: loadBoolDefaultIfUnset(forKey: Keys.contextAwarenessRedactSensitiveData, defaultValue: true),
            contextAwarenessExcludedBundleIDs: loadDecoded([String].self, forKey: Keys.contextAwarenessExcludedBundleIDs) ?? []
        )
    }

    /// Struct for dictation rules and web targets to avoid large tuple.
    struct DictationRulesAndWebTargetsValues {
        let markdownTargetBundleIdentifiers: [String]
        let dictationAppRules: [DictationAppRule]
        let dictationStyles: [DictationStyle]
        let vocabularyReplacementRules: [VocabularyReplacementRule]
        let markdownWebTargets: [WebContextTarget]
        let webTargetBrowserBundleIdentifiers: [String]
        let monitoredMeetingBundleIdentifiers: [String]
        let webMeetingTargets: [WebMeetingTarget]
    }

    /// Loads dictation rules and web targets.
    static func loadDictationRulesAndWebTargets() -> DictationRulesAndWebTargetsValues {
        DictationRulesAndWebTargetsValues(
            markdownTargetBundleIdentifiers: loadDecoded([String].self, forKey: Keys.markdownTargetBundleIdentifiers) ?? defaultMarkdownTargetBundleIdentifiers,
            dictationAppRules: normalizedDictationAppRules(loadDecoded([DictationAppRule].self, forKey: Keys.dictationAppRules) ?? defaultDictationAppRules),
            dictationStyles: normalizedDictationStyles(loadDecoded([DictationStyle].self, forKey: Keys.dictationStyles) ?? defaultDictationStyles),
            vocabularyReplacementRules: normalizedVocabularyReplacementRules(loadDecoded([VocabularyReplacementRule].self, forKey: Keys.vocabularyReplacementRules) ?? []),
            markdownWebTargets: loadDecoded([WebContextTarget].self, forKey: Keys.markdownWebTargets) ?? defaultMarkdownWebTargets,
            webTargetBrowserBundleIdentifiers: loadDecoded([String].self, forKey: Keys.webTargetBrowserBundleIdentifiers) ?? defaultWebTargetBrowserBundleIdentifiers,
            monitoredMeetingBundleIdentifiers: loadDecoded([String].self, forKey: Keys.monitoredMeetingBundleIdentifiers) ?? defaultMonitoredMeetingBundleIdentifiers,
            webMeetingTargets: loadDecoded([WebMeetingTarget].self, forKey: Keys.webMeetingTargets) ?? defaultWebMeetingTargets
        )
    }

    /// Struct for UI and indicator settings to avoid large tuple.
    struct UIAndIndicatorSettingsValues {
        let assistantBorderColor: AssistantBorderColor
        let assistantBorderStyle: AssistantBorderStyle
        let assistantBorderWidth: Double
        let assistantGlowSize: Double
        let recordingIndicatorEnabled: Bool
        let recordingIndicatorStyle: RecordingIndicatorStyle
        let recordingIndicatorPosition: RecordingIndicatorPosition
        let recordingIndicatorAnimationSpeed: RecordingIndicatorAnimationSpeed
        let autoDeleteTranscriptions: Bool
        let autoDeletePeriodDays: Int
        let appAccentColor: AppThemeColor
        let soundFeedbackEnabled: Bool
        let recordingStartSound: SoundFeedbackSound
        let recordingStopSound: SoundFeedbackSound
        let showInDock: Bool
    }

    /// Loads UI and indicator settings.
    static func loadUIAndIndicatorSettings() -> UIAndIndicatorSettingsValues {
        let rawBorderColor = UserDefaults.standard.string(forKey: Keys.assistantBorderColor)
        let rawBorderStyle = UserDefaults.standard.string(forKey: Keys.assistantBorderStyle)
        let storedBorderWidth = UserDefaults.standard.object(forKey: Keys.assistantBorderWidth) as? NSNumber
        let storedGlowSize = UserDefaults.standard.object(forKey: Keys.assistantGlowSize) as? NSNumber

        let rawIndicatorStyle = UserDefaults.standard.string(forKey: Keys.recordingIndicatorStyle)
        let rawIndicatorPosition = UserDefaults.standard.string(forKey: Keys.recordingIndicatorPosition)
        let rawIndicatorAnimationSpeed = UserDefaults.standard.string(forKey: Keys.recordingIndicatorAnimationSpeed)

        let rawDays = UserDefaults.standard.object(forKey: Keys.autoDeletePeriodDays) as? Int
        let rawAccentColor = UserDefaults.standard.string(forKey: Keys.appAccentColor)

        let rawStartSound = UserDefaults.standard.string(forKey: Keys.recordingStartSound)
        let rawStopSound = UserDefaults.standard.string(forKey: Keys.recordingStopSound)

        return UIAndIndicatorSettingsValues(
            assistantBorderColor: rawBorderColor.flatMap { AssistantBorderColor(rawValue: $0) } ?? .green,
            assistantBorderStyle: rawBorderStyle.flatMap { AssistantBorderStyle(rawValue: $0) } ?? .stroke,
            assistantBorderWidth: max(1, storedBorderWidth?.doubleValue ?? 8),
            assistantGlowSize: max(0, storedGlowSize?.doubleValue ?? 20),
            recordingIndicatorEnabled: loadBoolDefaultIfUnset(forKey: Keys.recordingIndicatorEnabled, defaultValue: true),
            recordingIndicatorStyle: rawIndicatorStyle.flatMap { RecordingIndicatorStyle(rawValue: $0) } ?? .mini,
            recordingIndicatorPosition: rawIndicatorPosition.flatMap { RecordingIndicatorPosition(rawValue: $0) } ?? .bottom,
            recordingIndicatorAnimationSpeed: rawIndicatorAnimationSpeed.flatMap { RecordingIndicatorAnimationSpeed(rawValue: $0) } ?? .normal,
            autoDeleteTranscriptions: UserDefaults.standard.bool(forKey: Keys.autoDeleteTranscriptions),
            autoDeletePeriodDays: rawDays ?? 30,
            appAccentColor: rawAccentColor.flatMap { AppThemeColor(rawValue: $0) } ?? .system,
            soundFeedbackEnabled: UserDefaults.standard.bool(forKey: Keys.soundFeedbackEnabled),
            recordingStartSound: rawStartSound.flatMap { SoundFeedbackSound(rawValue: $0) } ?? .pop,
            recordingStopSound: rawStopSound.flatMap { SoundFeedbackSound(rawValue: $0) } ?? .glass,
            showInDock: UserDefaults.standard.bool(forKey: Keys.showInDock)
        )
    }

    /// Struct for resolving shortcut definitions to avoid excessive parameters.
    struct ShortcutResolutionConfig {
        let dictationModifierGesture: ModifierShortcutGesture?
        let assistantModifierGesture: ModifierShortcutGesture?
        let meetingModifierGesture: ModifierShortcutGesture?
        let dictationPresetKey: PresetShortcutKey
        let assistantPresetKey: PresetShortcutKey
        let meetingPresetKey: PresetShortcutKey
        let dictationActivationMode: ShortcutActivationMode
        let assistantActivationMode: ShortcutActivationMode
        let shortcutActivationMode: ShortcutActivationMode
    }

    /// Resolves shortcut definitions from loaded values or legacy presets.
    static func resolveShortcutDefinitionsValues(
        from context: InitializationContext,
        config: ShortcutResolutionConfig
    ) -> (
        dictation: ShortcutDefinition?,
        assistant: ShortcutDefinition?,
        meeting: ShortcutDefinition?
    ) {
        (
            context.loadedDictationShortcutDefinition
                .flatMap {
                    normalizedInHouseShortcutDefinition(
                        $0,
                        activationMode: config.dictationActivationMode,
                        allowReturnOrEnter: false
                    )
                } ??
                resolveShortcutDefinition(
                    explicitGesture: config.dictationModifierGesture,
                    legacyPresetKey: config.dictationPresetKey,
                    activationMode: config.dictationActivationMode,
                    allowReturnOrEnter: false
                ) ??
                defaultDictationShortcutDefinition,
            context.loadedAssistantShortcutDefinition
                .flatMap {
                    normalizedInHouseShortcutDefinition(
                        $0,
                        activationMode: config.assistantActivationMode,
                        allowReturnOrEnter: false
                    )
                } ??
                resolveShortcutDefinition(
                    explicitGesture: config.assistantModifierGesture,
                    legacyPresetKey: config.assistantPresetKey,
                    activationMode: config.assistantActivationMode,
                    allowReturnOrEnter: false
                ) ??
                defaultAssistantShortcutDefinition,
            context.loadedMeetingShortcutDefinition
                .flatMap { normalizedInHouseShortcutDefinition($0, activationMode: config.shortcutActivationMode) } ??
                resolveShortcutDefinition(
                    explicitGesture: config.meetingModifierGesture,
                    legacyPresetKey: config.meetingPresetKey,
                    activationMode: config.shortcutActivationMode
                ) ??
                defaultMeetingShortcutDefinition
        )
    }

    /// Finalizes initialization by performing migrations and saving initial state.
    func finalizeInitialization(context: InitializationContext) {
        // Resolve shortcut definitions
        let shortcutConfig = ShortcutResolutionConfig(
            dictationModifierGesture: dictationModifierShortcutGesture,
            assistantModifierGesture: assistantModifierShortcutGesture,
            meetingModifierGesture: meetingModifierShortcutGesture,
            dictationPresetKey: dictationSelectedPresetKey,
            assistantPresetKey: assistantSelectedPresetKey,
            meetingPresetKey: meetingSelectedPresetKey,
            dictationActivationMode: dictationShortcutActivationMode,
            assistantActivationMode: assistantShortcutActivationMode,
            shortcutActivationMode: shortcutActivationMode
        )
        let defs = Self.resolveShortcutDefinitionsValues(
            from: context,
            config: shortcutConfig
        )
        dictationShortcutDefinition = defs.dictation
        assistantShortcutDefinition = defs.assistant
        meetingShortcutDefinition = defs.meeting
        dictationModifierShortcutGesture = defs.dictation?.asModifierShortcutGesture
        assistantModifierShortcutGesture = defs.assistant?.asModifierShortcutGesture
        meetingModifierShortcutGesture = defs.meeting?.asModifierShortcutGesture

        if defs.dictation != nil {
            dictationSelectedPresetKey = .custom
            selectedPresetKey = .custom
        }
        if defs.assistant != nil {
            assistantSelectedPresetKey = .custom
        }
        if defs.meeting != nil {
            meetingSelectedPresetKey = .custom
        }

        if contextAwarenessEnabled {
            contextAwarenessIncludeAccessibilityText = true
        }

        let shouldMigrateLegacyAssistantIntegration = context.loadedIntegrations == nil
        if shouldMigrateLegacyAssistantIntegration {
            var migratedRaycast = AssistantIntegrationConfig.defaultRaycast
            migratedRaycast.isEnabled = assistantRaycastEnabled
            migratedRaycast.deepLink = AssistantIntegrationConfig.defaultRaycastDeepLink
            assistantIntegrations = [migratedRaycast]
            assistantSelectedIntegrationId = migratedRaycast.id
        }

        if assistantSelectedIntegrationId == nil {
            assistantSelectedIntegrationId = assistantIntegrations.first?.id
        }

        synchronizeAssistantIntegrationsState()
        save(assistantIntegrations, forKey: Keys.assistantIntegrations)

        if context.loadedDictationShortcutDefinition == nil {
            save(dictationShortcutDefinition, forKey: Keys.dictationShortcutDefinition)
        }
        if context.loadedAssistantShortcutDefinition == nil {
            save(assistantShortcutDefinition, forKey: Keys.assistantShortcutDefinition)
        }
        if context.loadedMeetingShortcutDefinition == nil {
            save(meetingShortcutDefinition, forKey: Keys.meetingShortcutDefinition)
        }

        if let selectedID = assistantSelectedIntegrationId {
            UserDefaults.standard.set(selectedID.uuidString, forKey: Keys.assistantSelectedIntegrationId)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.assistantSelectedIntegrationId)
        }

        UserDefaults.standard.set(assistantRaycastEnabled, forKey: Keys.assistantRaycastEnabled)
        UserDefaults.standard.set(assistantRaycastDeepLink, forKey: Keys.assistantRaycastDeepLink)
        UserDefaults.standard.removeObject(forKey: Keys.assistantUseEnterToStopRecording)

        if context.hasPersistedLegacyPerTargetBrowsers, !context.hasGlobalBrowserSetting {
            migrateWebTargetBrowsersToGlobalSettingIfNeeded()
        }

        migrateLegacyAudioDevicePriorityToPowerSelectionIfNeeded()
        migrateLegacyMarkdownTargetsToDictationAppRulesIfNeeded()
        migrateLegacyWebTargetBrowsersToDictationAppRulesIfNeeded()
        backfillEnhancementsSelectionModelsIfNeeded()
        migrateEnhancementsProviderRegistrationAPIKeysIfNeeded()
        if UserDefaults.standard.object(forKey: Self.meetingNotesMarkdownReadEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: Self.meetingNotesMarkdownReadEnabledKey)
        }
        applyLanguage(selectedLanguage)
    }

    public func migrateLegacyAudioDevicePriorityToPowerSelectionIfNeeded() {
        let defaults = UserDefaults.standard
        let hasChargingSelection = defaults.object(forKey: Keys.microphoneWhenChargingUID) != nil
        let hasBatterySelection = defaults.object(forKey: Keys.microphoneOnBatteryUID) != nil

        // If either setting was already configured, keep the user's explicit choices.
        guard !hasChargingSelection, !hasBatterySelection else { return }

        guard let firstLegacyUID = audioDevicePriority.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !firstLegacyUID.isEmpty
        else {
            return
        }

        microphoneWhenChargingUID = firstLegacyUID
        microphoneOnBatteryUID = firstLegacyUID
    }
}
