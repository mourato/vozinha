import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Post Processing Configuration

extension RecordingManager {
    struct UseCaseConfig {
        let kernelMode: IntelligenceKernelMode
        let applyPostProcessing: Bool
        let dictationStructuredPostProcessingEnabled: Bool
        let postProcessingPrompt: DomainPostProcessingPrompt?
        let defaultPostProcessingPrompt: DomainPostProcessingPrompt?
        let postProcessingModel: String?
        let postProcessingIdentity: ModelPerformanceModelIdentity?
        let autoDetectMeetingType: Bool
        let availablePrompts: [DomainPostProcessingPrompt]
        let postProcessingContext: String?
        let postProcessingContextItems: [TranscriptionContextItem]
    }

    func makeUseCaseConfig(
        session: TranscriptionSessionSnapshot,
        settings: AppSettingsStore,
    ) -> UseCaseConfig {
        let meeting = session.meeting
        let kernelMode = session.kernelMode
        let isDictation = kernelMode == .dictation
        let readinessIssue = settings.postProcessingEnabled
            ? settings.enhancementsInferenceReadinessIssue(for: kernelMode, apiKeyExists: apiKeyExists)
            : nil
        if currentMeeting?.id == session.id {
            setPostProcessingReadinessWarning(issue: readinessIssue, mode: kernelMode)
        }
        let applyPostProcessing = Self.shouldApplyEnhancementsPostProcessing(
            settings: settings,
            kernelMode: kernelMode,
            apiKeyExists: apiKeyExists,
        )

        let disabledForRecording = isDictation
            ? settings.isDictationPostProcessingDisabled
            : settings.isMeetingPostProcessingDisabled
        let shouldApplyPostProcessing = applyPostProcessing && !disabledForRecording

        if settings.postProcessingEnabled, let readinessIssue {
            let reasonCode = readinessIssue.rawValue
            AppLogger.info(
                "Post-processing disabled for this recording: enhancements configuration not ready",
                category: .recordingManager,
                extra: ["reasonCode": reasonCode],
            )
        }

        guard shouldApplyPostProcessing else {
            let reasonCode = resolveDisabledReasonCode(
                settings: settings,
                readinessIssue: readinessIssue,
                disabledForRecording: disabledForRecording,
                isDictation: isDictation,
            )

            AppLogger.info(
                "Post-processing skipped for this recording",
                category: .recordingManager,
                extra: [
                    "mode": kernelMode.rawValue,
                    "reasonCode": reasonCode,
                    "isDictation": isDictation,
                ],
            )
            return UseCaseConfig(
                kernelMode: kernelMode,
                applyPostProcessing: false,
                dictationStructuredPostProcessingEnabled: settings.dictationStructuredPostProcessingEnabled,
                postProcessingPrompt: nil,
                defaultPostProcessingPrompt: nil,
                postProcessingModel: nil,
                postProcessingIdentity: nil,
                autoDetectMeetingType: false,
                availablePrompts: [],
                postProcessingContext: nil,
                postProcessingContextItems: session.postProcessingContextItems,
            )
        }

        let availablePrompts = makeAvailablePrompts(isDictation: isDictation, settings: settings)
        let defaultMeetingPrompt = makeDefaultMeetingPrompt(isDictation: isDictation, settings: settings)
        let prompt = resolvePostProcessingPromptForUseCase(
            meeting: meeting,
            isDictation: isDictation,
            settings: settings,
            defaultMeetingPrompt: defaultMeetingPrompt,
            session: session,
        )

        let autoDetectMeetingType = !isDictation && meeting.type == .autodetect

        AppLogger.info(
            "Post-processing configured for this recording",
            category: .recordingManager,
            extra: [
                "mode": kernelMode.rawValue,
                "isDictation": isDictation,
                "promptTitle": prompt?.title ?? "nil",
                "autoDetectMeetingType": autoDetectMeetingType,
            ],
        )

        var resolvedContextItems = session.postProcessingContextItems
        if let meetingNotesItem = meetingNotesContextItem(
            from: session.meetingNotesContent,
            capturePurpose: meeting.capturePurpose,
        ) {
            if let existingIndex = resolvedContextItems.firstIndex(where: { $0.source == .meetingNotes }) {
                resolvedContextItems[existingIndex] = meetingNotesItem
            } else {
                resolvedContextItems.append(meetingNotesItem)
            }
        }

        return UseCaseConfig(
            kernelMode: kernelMode,
            applyPostProcessing: true,
            dictationStructuredPostProcessingEnabled: settings.dictationStructuredPostProcessingEnabled,
            postProcessingPrompt: prompt,
            defaultPostProcessingPrompt: autoDetectMeetingType ? defaultMeetingPrompt : nil,
            postProcessingModel: settings.resolvedEnhancementsAIConfiguration(for: kernelMode).selectedModel,
            postProcessingIdentity: settings.resolvedEnhancementsPerformanceIdentity(for: kernelMode),
            autoDetectMeetingType: autoDetectMeetingType,
            availablePrompts: availablePrompts,
            postProcessingContext: session.postProcessingContext,
            postProcessingContextItems: resolvedContextItems,
        )
    }

    private func resolveDisabledReasonCode(
        settings: AppSettingsStore,
        readinessIssue: EnhancementsInferenceReadinessIssue?,
        disabledForRecording: Bool,
        isDictation: Bool,
    ) -> String {
        if !settings.postProcessingEnabled {
            "post_processing.disabled"
        } else if let readinessIssue {
            readinessIssue.rawValue
        } else if disabledForRecording {
            isDictation ? "dictation.prompt.disabled" : "meeting.prompt.disabled"
        } else {
            "post_processing.unknown"
        }
    }

    #if DEBUG
    func debugResolvePostProcessingConfiguration(
        meeting: Meeting,
        settings: AppSettingsStore = .shared,
    ) -> PostProcessingConfigurationDebugInfo {
        let snapshot = makeTranscriptionSessionSnapshot(meeting)
        let kernelMode = snapshot.kernelMode
        let config = makeUseCaseConfig(session: snapshot, settings: settings)
        return PostProcessingConfigurationDebugInfo(
            kernelMode: kernelMode,
            applyPostProcessing: config.applyPostProcessing,
            promptId: config.postProcessingPrompt?.id,
            promptTitle: config.postProcessingPrompt?.title,
        )
    }
    #endif

    static func shouldApplyEnhancementsPostProcessing(
        settings: AppSettingsStore,
        kernelMode: IntelligenceKernelMode,
        apiKeyExists: ((AIProvider) -> Bool)? = nil,
    ) -> Bool {
        let readinessIssue = settings.enhancementsInferenceReadinessIssue(for: kernelMode, apiKeyExists: apiKeyExists)
        let kernelModeEnabled: Bool = switch kernelMode {
        case .dictation:
            true
        case .meeting, .assistant:
            settings.isIntelligenceKernelModeEnabled(kernelMode)
        }

        return settings.postProcessingEnabled
            && readinessIssue == nil
            && kernelModeEnabled
    }

    func refreshPostProcessingReadinessWarning(
        for kernelMode: IntelligenceKernelMode,
        settings: AppSettingsStore = .shared,
        apiKeyExists: ((AIProvider) -> Bool)? = nil,
    ) {
        let resolvedAPIKeyExists = apiKeyExists ?? self.apiKeyExists
        let issue = settings.postProcessingEnabled
            ? settings.enhancementsInferenceReadinessIssue(for: kernelMode, apiKeyExists: resolvedAPIKeyExists)
            : nil
        setPostProcessingReadinessWarning(issue: issue, mode: kernelMode)
    }

    func clearPostProcessingReadinessWarning() {
        postProcessingReadinessWarningIssue = nil
        postProcessingReadinessWarningMode = nil
        activePostProcessingKernelMode = nil
    }

    func setPostProcessingReadinessWarning(
        issue: EnhancementsInferenceReadinessIssue?,
        mode: IntelligenceKernelMode,
    ) {
        postProcessingReadinessWarningIssue = issue
        postProcessingReadinessWarningMode = issue == nil ? nil : mode
    }

    // MARK: - Prompt Resolution

    func makeAvailablePrompts(isDictation: Bool, settings: AppSettingsStore) -> [DomainPostProcessingPrompt] {
        postProcessingConfigurationProvider.makeAvailablePrompts(
            isDictation: isDictation,
            settings: settings,
        )
    }

    func makeDefaultMeetingPrompt(
        isDictation: Bool,
        settings: AppSettingsStore,
    ) -> DomainPostProcessingPrompt? {
        postProcessingConfigurationProvider.makeDefaultMeetingPrompt(
            isDictation: isDictation,
            settings: settings,
        )
    }

    func resolvePostProcessingPromptForUseCase(
        meeting: Meeting,
        isDictation: Bool,
        settings: AppSettingsStore,
        defaultMeetingPrompt: DomainPostProcessingPrompt?,
        session: TranscriptionSessionSnapshot? = nil,
    ) -> DomainPostProcessingPrompt? {
        postProcessingConfigurationProvider.resolvePostProcessingPromptForUseCase(
            meeting: meeting,
            isDictation: isDictation,
            settings: settings,
            defaultMeetingPrompt: defaultMeetingPrompt,
            dictationContext: dictationContextSnapshot(for: session),
        )
    }

    func domainPrompt(from prompt: PostProcessingPrompt) -> DomainPostProcessingPrompt {
        postProcessingConfigurationProvider.domainPrompt(from: prompt)
    }

    // MARK: - Dictation Prompt Overrides

    func promptWithDictationRuleOverrides(
        prompt: PostProcessingPrompt,
        settings: AppSettingsStore,
        session: TranscriptionSessionSnapshot? = nil,
    ) -> PostProcessingPrompt {
        postProcessingConfigurationProvider.promptWithDictationRuleOverrides(
            prompt: prompt,
            settings: settings,
            dictationContext: dictationContextSnapshot(for: session),
        )
    }

    func matchingDictationStyleForDictation(
        settings: AppSettingsStore,
        session: TranscriptionSessionSnapshot? = nil,
    ) -> DictationStyle? {
        postProcessingConfigurationProvider.matchingDictationStyleForDictation(
            settings: settings,
            dictationContext: dictationContextSnapshot(for: session),
        )
    }

    func effectiveCustomPromptInstructionsForDictation(
        settings: AppSettingsStore,
        session: TranscriptionSessionSnapshot? = nil,
        matchedStyle: DictationStyle? = nil,
    ) -> String? {
        postProcessingConfigurationProvider.effectiveCustomPromptInstructionsForDictation(
            settings: settings,
            dictationContext: dictationContextSnapshot(for: session),
            matchedStyle: matchedStyle,
        )
    }

    func matchingDictationAppRule(
        settings: AppSettingsStore,
        session: TranscriptionSessionSnapshot? = nil,
    ) -> DictationAppRule? {
        postProcessingConfigurationProvider.matchingDictationAppRule(
            settings: settings,
            dictationContext: dictationContextSnapshot(for: session),
        )
    }

    func outputLanguageForDictation(
        settings: AppSettingsStore,
        session: TranscriptionSessionSnapshot? = nil,
        matchedStyle: DictationStyle? = nil,
    ) -> DictationOutputLanguage {
        postProcessingConfigurationProvider.outputLanguageForDictation(
            settings: settings,
            dictationContext: dictationContextSnapshot(for: session),
            matchedStyle: matchedStyle,
        )
    }

    func shouldForceMarkdownForDictation(
        settings: AppSettingsStore,
        session: TranscriptionSessionSnapshot? = nil,
        matchedStyle: DictationStyle? = nil,
    ) -> Bool {
        postProcessingConfigurationProvider.shouldForceMarkdownForDictation(
            settings: settings,
            dictationContext: dictationContextSnapshot(for: session),
            matchedStyle: matchedStyle,
        )
    }

    func matchingWebContextTargetForDictation(
        settings: AppSettingsStore,
        session: TranscriptionSessionSnapshot? = nil,
    ) -> WebContextTarget? {
        postProcessingConfigurationProvider.matchingWebContextTargetForDictation(
            settings: settings,
            dictationContext: dictationContextSnapshot(for: session),
        )
    }

    func activeBrowserURL(for bundleIdentifier: String?) -> URL? {
        guard let bundleIdentifier else { return nil }
        let normalized = WebTargetDetection.normalizeBundleIdentifier(bundleIdentifier)

        if let provider = browserProviders[normalized] {
            return provider.activeTabURL()
        }

        guard let provider = BrowserProviderRegistry.provider(for: bundleIdentifier) else {
            return nil
        }

        browserProviders[normalized] = provider
        return provider.activeTabURL()
    }

    func promptWithMeetingSummaryOverrides(
        prompt: PostProcessingPrompt,
    ) -> PostProcessingPrompt {
        postProcessingConfigurationProvider.promptWithMeetingSummaryOverrides(prompt: prompt)
    }

    // MARK: - Mode Detection

    func isDictationMode(
        for meeting: Meeting?,
        capturePurposeOverride: CapturePurpose? = nil,
    ) -> Bool {
        if let capturePurposeOverride {
            return capturePurposeOverride == .dictation
        }

        if isRecording || isTranscribing {
            return currentCapturePurpose == .dictation
        }

        return meeting?.capturePurpose == .dictation || currentCapturePurpose == .dictation
    }

    func postProcessingKernelMode(
        for meeting: Meeting?,
        capturePurposeOverride: CapturePurpose? = nil,
    ) -> IntelligenceKernelMode {
        if let activePostProcessingKernelMode, capturePurposeOverride == nil {
            return activePostProcessingKernelMode
        }

        return isDictationMode(for: meeting, capturePurposeOverride: capturePurposeOverride) ? .dictation : .meeting
    }

    func isPostProcessingDisabled(isDictation: Bool, settings: AppSettingsStore) -> Bool {
        if isDictation {
            return settings.isDictationPostProcessingDisabled
        }
        return settings.isMeetingPostProcessingDisabled
    }

    private func dictationContextSnapshot(
        for session: TranscriptionSessionSnapshot?,
    ) -> DictationContextSnapshot {
        DictationContextSnapshot(
            bundleIdentifier: session?.dictationStartBundleIdentifier ?? dictationStartBundleIdentifier,
            activeURL: session?.dictationStartURL ?? dictationStartURL,
            outputLanguageOverride: session?.dictationSessionOutputLanguageOverride ?? dictationSessionOutputLanguageOverride,
        )
    }
}
