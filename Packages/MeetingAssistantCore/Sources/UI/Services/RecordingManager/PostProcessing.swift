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
        let autoDetectMeetingType: Bool
        let availablePrompts: [DomainPostProcessingPrompt]
        let postProcessingContext: String?
        let postProcessingContextItems: [TranscriptionContextItem]
    }

    func makeUseCaseConfig(
        session: TranscriptionSessionSnapshot,
        settings: AppSettingsStore
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
            apiKeyExists: apiKeyExists
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
                extra: ["reasonCode": reasonCode]
            )
        }

        guard shouldApplyPostProcessing else {
            let reasonCode = resolveDisabledReasonCode(
                settings: settings,
                readinessIssue: readinessIssue,
                disabledForRecording: disabledForRecording,
                isDictation: isDictation
            )

            AppLogger.info(
                "Post-processing skipped for this recording",
                category: .recordingManager,
                extra: [
                    "mode": kernelMode.rawValue,
                    "reasonCode": reasonCode,
                    "isDictation": isDictation,
                ]
            )
            return UseCaseConfig(
                kernelMode: kernelMode,
                applyPostProcessing: false,
                dictationStructuredPostProcessingEnabled: settings.dictationStructuredPostProcessingEnabled,
                postProcessingPrompt: nil,
                defaultPostProcessingPrompt: nil,
                postProcessingModel: nil,
                autoDetectMeetingType: false,
                availablePrompts: [],
                postProcessingContext: nil,
                postProcessingContextItems: session.postProcessingContextItems
            )
        }

        let availablePrompts = makeAvailablePrompts(isDictation: isDictation, settings: settings)
        let defaultMeetingPrompt = makeDefaultMeetingPrompt(isDictation: isDictation, settings: settings)
        let prompt = resolvePostProcessingPromptForUseCase(
            meeting: meeting,
            isDictation: isDictation,
            settings: settings,
            defaultMeetingPrompt: defaultMeetingPrompt,
            session: session
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
            ]
        )

        var resolvedContextItems = session.postProcessingContextItems
        if let meetingNotesItem = meetingNotesContextItem(
            from: session.meetingNotesContent,
            capturePurpose: meeting.capturePurpose
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
            autoDetectMeetingType: autoDetectMeetingType,
            availablePrompts: availablePrompts,
            postProcessingContext: session.postProcessingContext,
            postProcessingContextItems: resolvedContextItems
        )
    }

    private func resolveDisabledReasonCode(
        settings: AppSettingsStore,
        readinessIssue: EnhancementsInferenceReadinessIssue?,
        disabledForRecording: Bool,
        isDictation: Bool
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
        settings: AppSettingsStore = .shared
    ) -> PostProcessingConfigurationDebugInfo {
        let snapshot = makeTranscriptionSessionSnapshot(meeting)
        let kernelMode = snapshot.kernelMode
        let config = makeUseCaseConfig(session: snapshot, settings: settings)
        return PostProcessingConfigurationDebugInfo(
            kernelMode: kernelMode,
            applyPostProcessing: config.applyPostProcessing,
            promptId: config.postProcessingPrompt?.id,
            promptTitle: config.postProcessingPrompt?.title
        )
    }
    #endif

    static func shouldApplyEnhancementsPostProcessing(
        settings: AppSettingsStore,
        kernelMode: IntelligenceKernelMode,
        apiKeyExists: ((AIProvider) -> Bool)? = nil
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
        apiKeyExists: ((AIProvider) -> Bool)? = nil
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
        mode: IntelligenceKernelMode
    ) {
        postProcessingReadinessWarningIssue = issue
        postProcessingReadinessWarningMode = issue == nil ? nil : mode
    }

    // MARK: - Prompt Resolution

    func makeAvailablePrompts(isDictation: Bool, settings: AppSettingsStore) -> [DomainPostProcessingPrompt] {
        guard !isDictation else { return [] }

        let builtIn: [PostProcessingPrompt] = [.standup, .presentation, .designReview, .oneOnOne, .planning]
        return (builtIn + settings.meetingPrompts).map(domainPrompt(from:))
    }

    func makeDefaultMeetingPrompt(
        isDictation: Bool,
        settings: AppSettingsStore
    ) -> DomainPostProcessingPrompt? {
        guard !isDictation else { return nil }

        if let selected = settings.selectedPrompt {
            return domainPrompt(from: selected)
        }

        return domainPrompt(from: PromptService.shared.strategy(for: .general).promptObject())
    }

    func resolvePostProcessingPromptForUseCase(
        meeting: Meeting,
        isDictation: Bool,
        settings: AppSettingsStore,
        defaultMeetingPrompt: DomainPostProcessingPrompt?,
        session: TranscriptionSessionSnapshot? = nil
    ) -> DomainPostProcessingPrompt? {
        if isDictation {
            let basePrompt = settings.selectedDictationPrompt ?? .defaultPrompt
            let resolvedPrompt = promptWithDictationRuleOverrides(
                prompt: basePrompt,
                settings: settings,
                session: session
            )
            return domainPrompt(from: resolvedPrompt)
        }

        switch meeting.type {
        case .autodetect:
            return nil
        case .standup:
            return domainPrompt(from: promptWithMeetingSummaryOverrides(prompt: .standup))
        case .presentation:
            return domainPrompt(from: promptWithMeetingSummaryOverrides(prompt: .presentation))
        case .designReview:
            return domainPrompt(from: promptWithMeetingSummaryOverrides(prompt: .designReview))
        case .oneOnOne:
            return domainPrompt(from: promptWithMeetingSummaryOverrides(prompt: .oneOnOne))
        case .planning:
            return domainPrompt(from: promptWithMeetingSummaryOverrides(prompt: .planning))
        case .general:
            guard let defaultMeetingPrompt else { return nil }
            let prompt = PostProcessingPrompt(
                id: defaultMeetingPrompt.id,
                title: defaultMeetingPrompt.title,
                promptText: defaultMeetingPrompt.content,
                isPredefined: false
            )
            let enrichedPrompt = promptWithMeetingSummaryOverrides(prompt: prompt)
            return domainPrompt(from: enrichedPrompt)
        }
    }

    func domainPrompt(from prompt: PostProcessingPrompt) -> DomainPostProcessingPrompt {
        DomainPostProcessingPrompt(id: prompt.id, title: prompt.title, content: prompt.promptText, isDefault: false)
    }

    // MARK: - Dictation Prompt Overrides

    func promptWithDictationRuleOverrides(
        prompt: PostProcessingPrompt,
        settings: AppSettingsStore,
        session: TranscriptionSessionSnapshot? = nil
    ) -> PostProcessingPrompt {
        let matchedStyle = matchingDictationStyleForDictation(settings: settings, session: session)
        let basePromptText = resolvedDictationBasePromptText(
            defaultPromptText: prompt.promptText,
            matchedStyle: matchedStyle
        )

        var appliedInstructions: [String] = []
        var priorityInstructions: [String] = []

        if shouldForceMarkdownForDictation(settings: settings, session: session, matchedStyle: matchedStyle) {
            appliedInstructions.append(Self.markdownFormatInstruction)
        }

        let outputLanguage = outputLanguageForDictation(
            settings: settings,
            session: session,
            matchedStyle: matchedStyle
        )
        if outputLanguage != .original {
            priorityInstructions.append(Self.translationInstruction(for: outputLanguage))
        }

        if let customInstructions = effectiveCustomPromptInstructionsForDictation(
            settings: settings,
            session: session,
            matchedStyle: matchedStyle
        ) {
            priorityInstructions.append(customInstructions)
        }

        if !priorityInstructions.isEmpty {
            appliedInstructions.append(
                Self.siteOrAppPriorityInstructionBlock(priorityInstructions.joined(separator: "\n\n"))
            )
        }

        guard !(appliedInstructions.isEmpty && basePromptText == prompt.promptText) else { return prompt }

        let augmentedText = ([basePromptText] + appliedInstructions).joined(separator: "\n\n")

        return PostProcessingPrompt(
            id: prompt.id,
            title: prompt.title,
            promptText: augmentedText,
            isActive: prompt.isActive,
            icon: prompt.icon,
            description: prompt.description,
            isPredefined: prompt.isPredefined
        )
    }

    private func resolvedDictationBasePromptText(
        defaultPromptText: String,
        matchedStyle: DictationStyle?
    ) -> String {
        guard let matchedStyle, matchedStyle.replaceBasePrompt else {
            return defaultPromptText
        }

        let stylePrompt = matchedStyle.promptInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stylePrompt.isEmpty else { return defaultPromptText }
        return stylePrompt
    }

    func matchingDictationStyleForDictation(
        settings: AppSettingsStore,
        session: TranscriptionSessionSnapshot? = nil
    ) -> DictationStyle? {
        let bundleIdentifier = session?.dictationStartBundleIdentifier ?? dictationStartBundleIdentifier
        let activeURL = session?.dictationStartURL ?? dictationStartURL

        guard bundleIdentifier != nil || activeURL != nil else {
            return nil
        }

        return settings.dictationStyles.first {
            $0.matches(bundleIdentifier: bundleIdentifier, activeURL: activeURL)
        }
    }

    func effectiveCustomPromptInstructionsForDictation(
        settings: AppSettingsStore,
        session: TranscriptionSessionSnapshot? = nil,
        matchedStyle: DictationStyle? = nil
    ) -> String? {
        guard let style = matchedStyle ?? matchingDictationStyleForDictation(settings: settings, session: session) else {
            return nil
        }

        guard !style.replaceBasePrompt else { return nil }

        let normalized = style.promptInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    func matchingDictationAppRule(
        settings: AppSettingsStore,
        session: TranscriptionSessionSnapshot? = nil
    ) -> DictationAppRule? {
        guard let bundleIdentifier = session?.dictationStartBundleIdentifier ?? dictationStartBundleIdentifier else { return nil }
        let normalized = WebTargetDetection.normalizeBundleIdentifier(bundleIdentifier)

        return settings.dictationAppRules.first {
            WebTargetDetection.normalizeBundleIdentifier($0.bundleIdentifier) == normalized
        }
    }

    func outputLanguageForDictation(
        settings: AppSettingsStore,
        session: TranscriptionSessionSnapshot? = nil,
        matchedStyle: DictationStyle? = nil
    ) -> DictationOutputLanguage {
        if let override = session?.dictationSessionOutputLanguageOverride ?? dictationSessionOutputLanguageOverride {
            return override
        }

        return (matchedStyle ?? matchingDictationStyleForDictation(settings: settings, session: session))?.outputLanguage ?? .original
    }

    func shouldForceMarkdownForDictation(
        settings: AppSettingsStore,
        session: TranscriptionSessionSnapshot? = nil,
        matchedStyle: DictationStyle? = nil
    ) -> Bool {
        (matchedStyle ?? matchingDictationStyleForDictation(settings: settings, session: session))?.forceMarkdownOutput ?? false
    }

    func matchingWebContextTargetForDictation(
        settings: AppSettingsStore,
        session: TranscriptionSessionSnapshot? = nil
    ) -> WebContextTarget? {
        guard let bundleIdentifier = session?.dictationStartBundleIdentifier ?? dictationStartBundleIdentifier else { return nil }
        let normalized = WebTargetDetection.normalizeBundleIdentifier(bundleIdentifier)
        let webTargets = settings.markdownWebTargets
        guard !webTargets.isEmpty else { return nil }

        if let url = session?.dictationStartURL ?? dictationStartURL,
           let target = WebTargetDetection.matchTarget(
               for: url,
               bundleIdentifier: normalized,
               targets: webTargets,
               fallbackBrowserBundleIdentifiers: settings.effectiveWebTargetBrowserBundleIdentifiers
           )
        {
            return target
        }

        return WebTargetDetection.matchTargetByWindowTitle(
            bundleIdentifier: normalized,
            targets: webTargets,
            fallbackBrowserBundleIdentifiers: settings.effectiveWebTargetBrowserBundleIdentifiers
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

    static let markdownFormatInstruction = """
    <OUTPUT_FORMAT>
    ALWAYS format the output as Markdown. When formatting using Markdown, use traditional formatting conventions for ordered or unordered lists, **bold**, *italics*, and headings as well.
    </OUTPUT_FORMAT>
    """

    static func translationInstruction(for language: DictationOutputLanguage) -> String {
        """
        <OUTPUT_LANGUAGE>
        Translate the final output to \(language.instructionDisplayName). This requirement overrides any instruction that says to keep the original language.
        </OUTPUT_LANGUAGE>
        """
    }

    static let meetingNotesPriorityInstruction = """
    <MEETING_NOTES_POLICY>
    If a <MEETING_NOTES> block is present, treat it as high-priority user-provided signal.
    Preserve those points in the summary and enrich them only with grounded details from the transcription.
    Never contradict explicit meeting notes unless the transcription clearly disproves them.
    </MEETING_NOTES_POLICY>
    """

    func promptWithMeetingSummaryOverrides(
        prompt: PostProcessingPrompt
    ) -> PostProcessingPrompt {
        let augmentedText = [
            prompt.promptText,
            Self.meetingNotesPriorityInstruction,
        ].joined(separator: "\n\n")

        return PostProcessingPrompt(
            id: prompt.id,
            title: prompt.title,
            promptText: augmentedText,
            isActive: prompt.isActive,
            icon: prompt.icon,
            description: prompt.description,
            isPredefined: prompt.isPredefined
        )
    }

    static func siteOrAppPriorityInstructionBlock(_ instructions: String) -> String {
        """
        <\(AIPromptTemplates.siteOrAppPriorityTag)>
        \(instructions)
        </\(AIPromptTemplates.siteOrAppPriorityTag)>
        """
    }

    // MARK: - Mode Detection

    func isDictationMode(
        for meeting: Meeting?,
        capturePurposeOverride: CapturePurpose? = nil
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
        capturePurposeOverride: CapturePurpose? = nil
    ) -> IntelligenceKernelMode {
        if let activePostProcessingKernelMode, capturePurposeOverride == nil {
            return activePostProcessingKernelMode
        }

        return isDictationMode(for: meeting, capturePurposeOverride: capturePurposeOverride) ? .dictation : .meeting
    }

    func isPostProcessingDisabled(isDictation: Bool, settings: AppSettingsStore) -> Bool {
        if isDictation { return settings.isDictationPostProcessingDisabled }
        return settings.isMeetingPostProcessingDisabled
    }
}
