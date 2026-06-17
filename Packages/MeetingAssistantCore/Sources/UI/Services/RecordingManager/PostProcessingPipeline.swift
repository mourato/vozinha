import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Post Processing Pipeline

extension RecordingManager {
    struct PostProcessingResult {
        let processedContent: String?
        let canonicalSummary: CanonicalSummary?
        let promptId: UUID?
        let promptTitle: String?
        let duration: Double
        let model: String?
        let requestSystemPrompt: String?
        let requestUserPrompt: String?
        let failureReason: String?

        static var empty: PostProcessingResult {
            PostProcessingResult(
                processedContent: nil,
                canonicalSummary: nil,
                promptId: nil,
                promptTitle: nil,
                duration: 0,
                model: nil,
                requestSystemPrompt: nil,
                requestUserPrompt: nil,
                failureReason: nil
            )
        }

        init(
            processedContent: String? = nil,
            canonicalSummary: CanonicalSummary? = nil,
            promptId: UUID? = nil,
            promptTitle: String? = nil,
            duration: Double = 0,
            model: String? = nil,
            requestSystemPrompt: String? = nil,
            requestUserPrompt: String? = nil,
            failureReason: String? = nil
        ) {
            self.processedContent = processedContent
            self.canonicalSummary = canonicalSummary
            self.promptId = promptId
            self.promptTitle = promptTitle
            self.duration = duration
            self.model = model
            self.requestSystemPrompt = requestSystemPrompt
            self.requestUserPrompt = requestUserPrompt
            self.failureReason = failureReason
        }
    }

    func applyPostProcessing(
        postProcessingInput: String,
        meeting: Meeting?,
        qualityProfile: TranscriptionQualityProfile?,
        capturePurposeOverride: CapturePurpose? = nil
    ) async -> PostProcessingResult {
        transcriptionStatus.updateProgress(phase: .postProcessing, percentage: Constants.postProcessingProgress)
        RecordingIndicatorProcessingStateStore.shared.update(
            snapshot: RecordingIndicatorProcessingSnapshot(
                step: .postProcessing,
                progressPercent: Constants.postProcessingProgress
            )
        )

        let settings = AppSettingsStore.shared
        guard settings.postProcessingEnabled else {
            return PostProcessingResult(failureReason: "Post-processing is disabled globally.")
        }
        let kernelMode = postProcessingKernelMode(
            for: meeting,
            capturePurposeOverride: capturePurposeOverride
        )
        let readinessIssue = settings.enhancementsInferenceReadinessIssue(for: kernelMode, apiKeyExists: apiKeyExists)
        setPostProcessingReadinessWarning(issue: readinessIssue, mode: kernelMode)
        if let readinessIssue {
            let reasonCode = readinessIssue.rawValue
            AppLogger.info(
                "Post-processing skipped: enhancements configuration not ready",
                category: .recordingManager,
                extra: ["reasonCode": reasonCode]
            )
            return PostProcessingResult(failureReason: "recording_indicator.post_processing_warning.missing_config".localized)
        }

        let isDictation = kernelMode == .dictation
        guard !isPostProcessingDisabled(isDictation: isDictation, settings: settings) else {
            return PostProcessingResult(failureReason: "Post-processing is disabled for this recording type.")
        }

        let type = meeting?.type ?? currentMeeting?.type ?? .general
        if type == .autodetect {
            RecordingIndicatorProcessingStateStore.shared.update(
                snapshot: RecordingIndicatorProcessingSnapshot(
                    step: .detectingMeetingType,
                    progressPercent: Constants.postProcessingProgress
                )
            )
        }
        let prompt = await resolvePostProcessingPrompt(
            rawText: postProcessingInput,
            isDictation: isDictation,
            meetingType: type,
            settings: settings
        )

        // Construct context metadata
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let contextMetadata = """
        Current time: \(formatter.string(from: Date()))
        Time zone: \(TimeZone.current.identifier)
        Locale: \(Locale.current.identifier)
        Computer name: \(Host.current().localizedName ?? "Unknown")
        User's full name: \(NSFullUserName())
        Application context: \(meeting?.app.displayName ?? "Unknown")
        """

        transcriptionStatus.updateProgress(phase: .postProcessing, percentage: Constants.aiProcessingProgress)
        RecordingIndicatorProcessingStateStore.shared.update(
            snapshot: RecordingIndicatorProcessingSnapshot(
                step: .postProcessing,
                progressPercent: Constants.aiProcessingProgress
            )
        )
        return await runPostProcessing(
            postProcessingInput: postProcessingInput,
            prompt: prompt,
            settings: settings,
            qualityProfile: qualityProfile,
            kernelMode: kernelMode,
            dictationStructuredPostProcessingEnabled: settings.dictationStructuredPostProcessingEnabled,
            contextMetadata: contextMetadata
        )
    }

    func runPostProcessing(
        postProcessingInput: String,
        prompt: PostProcessingPrompt,
        settings: AppSettingsStore,
        qualityProfile: TranscriptionQualityProfile?,
        kernelMode: IntelligenceKernelMode,
        dictationStructuredPostProcessingEnabled: Bool,
        contextMetadata: String
    ) async -> PostProcessingResult {
        let (requestSystemPrompt, requestUserPrompt) = buildRequestPrompts(
            from: prompt.promptText,
            transcription: postProcessingInput,
            mode: kernelMode,
            contextMetadata: contextMetadata
        )

        do {
            let startTime = Date()
            let useStructuredPipeline = kernelMode == .meeting || dictationStructuredPostProcessingEnabled
            let pipeline = useStructuredPipeline ? "structured" : "fast"
            let processedContent: String
            let canonicalSummary: CanonicalSummary?

            if useStructuredPipeline {
                let structuredResult = try await postProcessingService.processTranscriptionStructured(
                    postProcessingInput,
                    with: prompt,
                    mode: kernelMode
                )
                processedContent = structuredResult.processedText
                canonicalSummary = qualityProfile.map { profile in
                    recalibrateCanonicalSummary(structuredResult.canonicalSummary, with: profile)
                } ?? structuredResult.canonicalSummary
                AppLogger.info(
                    "Post-processing complete",
                    category: .recordingManager,
                    extra: [
                        "mode": kernelMode.rawValue,
                        "pipeline": pipeline,
                        "prompt": prompt.title,
                        "output_state": structuredResult.outputState.rawValue,
                    ]
                )
            } else {
                processedContent = try await postProcessingService.processTranscription(
                    postProcessingInput,
                    with: prompt,
                    mode: kernelMode,
                    systemPromptOverride: nil
                )
                canonicalSummary = nil
                AppLogger.info(
                    "Post-processing complete",
                    category: .recordingManager,
                    extra: [
                        "mode": kernelMode.rawValue,
                        "pipeline": pipeline,
                        "prompt": prompt.title,
                    ]
                )
            }

            let duration = Date().timeIntervalSince(startTime)
            let model = settings.resolvedEnhancementsAIConfiguration(for: kernelMode).selectedModel
            RecordingIndicatorProcessingStateStore.shared.update(
                snapshot: RecordingIndicatorProcessingSnapshot(step: .finalizingResult, progressPercent: 100)
            )
            return PostProcessingResult(
                processedContent: processedContent,
                canonicalSummary: canonicalSummary,
                promptId: prompt.id,
                promptTitle: prompt.title,
                duration: duration,
                model: model,
                requestSystemPrompt: requestSystemPrompt,
                requestUserPrompt: requestUserPrompt
            )
        } catch {
            AppLogger.error("Post-processing failed, using raw transcription", category: .recordingManager, error: error)
            RecordingIndicatorProcessingStateStore.shared.update(
                snapshot: RecordingIndicatorProcessingSnapshot(step: .postProcessingFailed, progressPercent: nil)
            )
            return PostProcessingResult(failureReason: error.localizedDescription)
        }
    }

    func resolvePostProcessingPrompt(
        rawText: String,
        isDictation: Bool,
        meetingType: MeetingType,
        settings: AppSettingsStore
    ) async -> PostProcessingPrompt {
        if isDictation {
            return settings.selectedDictationPrompt ?? .defaultPrompt
        }

        if meetingType == .autodetect {
            return await resolveAutodetectPrompt(rawText: rawText, settings: settings)
        }

        if meetingType != .general {
            let strategy = PromptService.shared.strategy(for: meetingType)
            let prompt = strategy.promptObject()
            AppLogger.info("Using context-aware prompt for type: \(meetingType.displayName)", category: .transcriptionEngine)
            return prompt
        }

        return settings.selectedPrompt ?? PromptService.shared.strategy(for: .general).promptObject()
    }

    func resolveAutodetectPrompt(rawText: String, settings: AppSettingsStore) async -> PostProcessingPrompt {
        let fallback = settings.selectedPrompt ?? PromptService.shared.strategy(for: .general).promptObject()
        let classifierPrompt = makeMeetingTypeClassifierPrompt()

        do {
            let jsonString = try await postProcessingService.processTranscription(rawText, with: classifierPrompt)
            guard let detectedType = parseMeetingType(from: jsonString), detectedType != .general else { return fallback }
            return resolveBuiltInMeetingPrompt(for: detectedType, fallbackGeneral: fallback)
        } catch {
            AppLogger.warning("Meeting type autodetect failed; falling back to general prompt", category: .recordingManager, extra: ["error": error.localizedDescription])
            return fallback
        }
    }

    func makeMeetingTypeClassifierPrompt() -> PostProcessingPrompt {
        PostProcessingPrompt(
            title: "Classifier",
            promptText: """
            <INTERNAL_MEETING_TYPE_CLASSIFIER>
            true
            </INTERNAL_MEETING_TYPE_CLASSIFIER>

            Analyze the transcription and classify the meeting type.
            Reply ONLY with JSON in the following format:
            { "type": "VALUE" }
            Allowed values: standup, presentation, design_review, one_on_one, planning, general.
            """,
            icon: "sparkles",
            isPredefined: false
        )
    }

    func resolveBuiltInMeetingPrompt(for type: MeetingType, fallbackGeneral: PostProcessingPrompt) -> PostProcessingPrompt {
        switch type {
        case .standup:
            .standup
        case .presentation:
            .presentation
        case .designReview:
            .designReview
        case .oneOnOne:
            .oneOnOne
        case .planning:
            .planning
        case .general:
            fallbackGeneral
        case .autodetect:
            fallbackGeneral
        }
    }

    func parseMeetingType(from jsonString: String) -> MeetingType? {
        if let type = parseMeetingTypeFromJSON(jsonString) {
            return type
        }

        guard let startIndex = jsonString.firstIndex(of: "{"),
              let endIndex = jsonString.lastIndex(of: "}")
        else {
            return nil
        }

        let candidate = String(jsonString[startIndex...endIndex])
        return parseMeetingTypeFromJSON(candidate)
    }

    func parseMeetingTypeFromJSON(_ jsonString: String) -> MeetingType? {
        guard let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawType = object["type"] as? String
        else {
            return nil
        }

        let trimmed = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let type = MeetingType(rawValue: trimmed) else { return nil }

        let allowed: Set<MeetingType> = [.standup, .presentation, .designReview, .oneOnOne, .planning, .general]
        return allowed.contains(type) ? type : nil
    }

    private func buildRequestPrompts(
        from promptContent: String,
        transcription: String,
        mode: IntelligenceKernelMode,
        contextMetadata _: String
    ) -> (systemPrompt: String, userPrompt: String) {
        let extracted = AIPromptTemplates.extractSiteOrAppPriorityInstructions(from: promptContent)
        let baseSystemMessage = AIPromptTemplates.defaultSystemPrompt
        let promptWithLanguage = applyMeetingLanguagePreferenceIfNeeded(
            to: extracted.cleanPrompt,
            mode: mode
        )
        let systemMessage = AIPromptTemplates.systemPrompt(
            basePrompt: baseSystemMessage,
            priorityInstructions: extracted.priorityInstructions
        )
        let userContent = AIPromptTemplates.userMessage(
            transcription: transcription,
            prompt: promptWithLanguage,
            priorityInstructions: extracted.priorityInstructions,
            contextMetadata: nil
        )
        return (systemMessage, userContent)
    }

    private func applyMeetingLanguagePreferenceIfNeeded(
        to prompt: String,
        mode: IntelligenceKernelMode
    ) -> String {
        guard mode == .meeting else { return prompt }
        return prompt
    }
}
