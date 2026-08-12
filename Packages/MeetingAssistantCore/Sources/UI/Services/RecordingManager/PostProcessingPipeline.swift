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
        let outputState: DomainPostProcessingOutputState?

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
                failureReason: nil,
                outputState: nil,
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
            failureReason: String? = nil,
            outputState: DomainPostProcessingOutputState? = nil,
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
            self.outputState = outputState
        }
    }

    private struct PostProcessingExecution {
        let processedContent: String
        let canonicalSummary: CanonicalSummary?
        let outputState: DomainPostProcessingOutputState?
    }

    func applyPostProcessing(
        postProcessingInput: String,
        meeting: Meeting?,
        qualityProfile: TranscriptionQualityProfile?,
        capturePurposeOverride: CapturePurpose? = nil,
    ) async -> PostProcessingResult {
        transcriptionStatus.updateProgress(phase: .postProcessing, percentage: Constants.postProcessingProgress)
        RecordingIndicatorProcessingStateStore.shared.update(
            snapshot: RecordingIndicatorProcessingSnapshot(
                step: .postProcessing,
                progressPercent: Constants.postProcessingProgress,
            ),
        )

        let settings = AppSettingsStore.shared
        let kernelMode = postProcessingKernelMode(
            for: meeting,
            capturePurposeOverride: capturePurposeOverride,
        )
        let isDictation = kernelMode == .dictation
        guard isDictation || settings.postProcessingEnabled else {
            return PostProcessingResult(failureReason: "Post-processing is disabled globally.")
        }
        guard !isDictation || (matchingDictationStyleForDictation(settings: settings)?.postProcessingEnabled ?? true) else {
            return PostProcessingResult(failureReason: "Post-processing is disabled for this recording type.")
        }
        let dictationSelectionOverride = isDictation
            ? matchingDictationStyleForDictation(settings: settings)?.enhancementsSelection
            : nil
        let readinessIssue = dictationSelectionOverride.map {
            settings.enhancementsInferenceReadinessIssue(for: $0, apiKeyExists: apiKeyExists)
        } ?? settings.enhancementsInferenceReadinessIssue(for: kernelMode, apiKeyExists: apiKeyExists)
        setPostProcessingReadinessWarning(issue: readinessIssue, mode: kernelMode)
        if let readinessIssue {
            let reasonCode = readinessIssue.rawValue
            AppLogger.info(
                "Post-processing skipped: enhancements configuration not ready",
                category: .recordingManager,
                extra: ["reasonCode": reasonCode],
            )
            return PostProcessingResult(failureReason: "recording_indicator.post_processing_warning.missing_config".localized)
        }

        let type = meeting?.type ?? currentMeeting?.type ?? .general
        if type == .autodetect {
            RecordingIndicatorProcessingStateStore.shared.update(
                snapshot: RecordingIndicatorProcessingSnapshot(
                    step: .detectingMeetingType,
                    progressPercent: Constants.postProcessingProgress,
                ),
            )
        }
        let prompt = await resolvePostProcessingPrompt(
            rawText: TranscriptionOutputSanitizer.stripPromptMetadata(from: postProcessingInput),
            isDictation: isDictation,
            meetingType: type,
            settings: settings,
        )

        transcriptionStatus.updateProgress(phase: .postProcessing, percentage: Constants.aiProcessingProgress)
        RecordingIndicatorProcessingStateStore.shared.update(
            snapshot: RecordingIndicatorProcessingSnapshot(
                step: .postProcessing,
                progressPercent: Constants.aiProcessingProgress,
            ),
        )
        return await runPostProcessing(
            postProcessingInput: postProcessingInput,
            prompt: prompt,
            settings: settings,
            qualityProfile: qualityProfile,
            kernelMode: kernelMode,
            selectionOverride: dictationSelectionOverride,
            dictationStructuredPostProcessingEnabled: settings.dictationStructuredPostProcessingEnabled,
        )
    }

    func runPostProcessing(
        postProcessingInput: String,
        prompt: PostProcessingPrompt,
        settings: AppSettingsStore,
        qualityProfile: TranscriptionQualityProfile?,
        kernelMode: IntelligenceKernelMode,
        selectionOverride: EnhancementsAISelection? = nil,
        dictationStructuredPostProcessingEnabled: Bool,
    ) async -> PostProcessingResult {
        let requestSelection = selectionOverride ?? settings.enhancementsSelection(for: kernelMode)
        let requestConfig = settings.resolvedEnhancementsAIConfiguration(for: requestSelection)
        let readinessIssue = settings.enhancementsInferenceReadinessIssue(for: requestSelection, apiKeyExists: apiKeyExists)
        let (requestSystemPrompt, requestUserPrompt) = buildRequestPrompts(
            prompt: prompt,
            from: prompt.promptText,
            transcription: postProcessingInput,
            mode: kernelMode,
            selectedModel: requestConfig.selectedModel,
        )

        do {
            let startTime = Date()
            let useStructuredPipeline = kernelMode == .meeting || dictationStructuredPostProcessingEnabled
            let request = makePostProcessingRequest(
                prompt: prompt,
                mode: kernelMode,
                selectionOverride: requestSelection,
                configuration: DomainPostProcessingConfiguration(
                    providerID: requestConfig.provider.rawValue,
                    baseURL: requestConfig.baseURL,
                    modelID: requestConfig.selectedModel,
                    readinessIssue: readinessIssue?.rawValue,
                    outputLanguageID: kernelMode == .meeting ? settings.meetingSummaryOutputLanguage.rawValue : nil,
                ),
                useStructuredPipeline: useStructuredPipeline,
            )
            let execution = try await executePostProcessing(
                input: postProcessingInput,
                request: request,
                mode: kernelMode,
                qualityProfile: qualityProfile,
                useStructuredPipeline: useStructuredPipeline,
            )

            let duration = Date().timeIntervalSince(startTime)
            RecordingIndicatorProcessingStateStore.shared.update(
                snapshot: RecordingIndicatorProcessingSnapshot(step: .finalizingResult, progressPercent: 100),
            )
            return PostProcessingResult(
                processedContent: execution.processedContent,
                canonicalSummary: execution.canonicalSummary,
                promptId: prompt.id,
                promptTitle: prompt.title,
                duration: duration,
                model: requestConfig.selectedModel,
                requestSystemPrompt: requestSystemPrompt,
                requestUserPrompt: requestUserPrompt,
                outputState: execution.outputState,
            )
        } catch {
            AppLogger.error("Post-processing failed, using raw transcription", category: .recordingManager, error: error)
            RecordingIndicatorProcessingStateStore.shared.update(
                snapshot: RecordingIndicatorProcessingSnapshot(step: .postProcessingFailed, progressPercent: nil),
            )
            return PostProcessingResult(failureReason: error.localizedDescription)
        }
    }

    private func executePostProcessing(
        input: String,
        request: DomainPostProcessingRequest,
        mode: IntelligenceKernelMode,
        qualityProfile: TranscriptionQualityProfile?,
        useStructuredPipeline: Bool,
    ) async throws -> PostProcessingExecution {
        let pipeline = useStructuredPipeline ? "structured" : "fast"
        let promptTitle = request.prompt?.title ?? "unknown"
        if useStructuredPipeline {
            let result = try await postProcessingRepository.processTranscriptionStructured(input, request: request)
            AppLogger.info(
                "Post-processing complete",
                category: .recordingManager,
                extra: [
                    "mode": mode.rawValue,
                    "pipeline": pipeline,
                    "prompt": promptTitle,
                    "output_state": result.outputState.rawValue,
                ],
            )
            return PostProcessingExecution(
                processedContent: result.processedText,
                canonicalSummary: qualityProfile.map { recalibrateCanonicalSummary(result.canonicalSummary, with: $0) } ?? result.canonicalSummary,
                outputState: result.outputState,
            )
        }

        let content = try await postProcessingRepository.processTranscription(input, request: request)
        AppLogger.info(
            "Post-processing complete",
            category: .recordingManager,
            extra: [
                "mode": mode.rawValue,
                "pipeline": pipeline,
                "prompt": promptTitle,
            ],
        )
        return PostProcessingExecution(processedContent: content, canonicalSummary: nil, outputState: nil)
    }

    private func makePostProcessingRequest(
        prompt: PostProcessingPrompt,
        mode: IntelligenceKernelMode,
        selectionOverride: EnhancementsAISelection?,
        configuration: DomainPostProcessingConfiguration,
        useStructuredPipeline: Bool,
    ) -> DomainPostProcessingRequest {
        DomainPostProcessingRequest(
            prompt: DomainPostProcessingPrompt(id: prompt.id, title: prompt.title, content: prompt.promptText),
            mode: mode,
            selection: selectionOverride.map {
                DomainPostProcessingSelection(
                    providerID: $0.provider.rawValue,
                    modelID: $0.selectedModel,
                    registrationID: $0.registrationID,
                )
            },
            configuration: configuration,
            useStructuredPipeline: useStructuredPipeline,
        )
    }

    func resolvePostProcessingPrompt(
        rawText: String,
        isDictation: Bool,
        meetingType: MeetingType,
        settings: AppSettingsStore,
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
        let selection = settings.enhancementsSelection(for: .meeting)
        let configuration = settings.resolvedEnhancementsAIConfiguration(for: selection)
        let readinessIssue = settings.enhancementsInferenceReadinessIssue(for: selection, apiKeyExists: apiKeyExists)

        do {
            let jsonString = try await postProcessingRepository.processTranscription(
                rawText,
                request: DomainPostProcessingRequest(
                    prompt: DomainPostProcessingPrompt(
                        id: classifierPrompt.id,
                        title: classifierPrompt.title,
                        content: classifierPrompt.promptText,
                    ),
                    mode: .meeting,
                    selection: DomainPostProcessingSelection(
                        providerID: selection.provider.rawValue,
                        modelID: selection.selectedModel,
                        registrationID: selection.registrationID,
                    ),
                    configuration: DomainPostProcessingConfiguration(
                        providerID: configuration.provider.rawValue,
                        baseURL: configuration.baseURL,
                        modelID: configuration.selectedModel,
                        readinessIssue: readinessIssue?.rawValue,
                        outputLanguageID: settings.meetingSummaryOutputLanguage.rawValue,
                    ),
                    useStructuredPipeline: false,
                ),
            )
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
            isPredefined: false,
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
        prompt: PostProcessingPrompt,
        from promptContent: String,
        transcription: String,
        mode: IntelligenceKernelMode,
        selectedModel: String?,
    ) -> (systemPrompt: String, userPrompt: String) {
        let snapshotPrompt = PostProcessingPrompt(
            id: prompt.id,
            title: prompt.title,
            promptText: promptContent,
            isActive: prompt.isActive,
            icon: prompt.icon,
            description: prompt.description,
            isPredefined: prompt.isPredefined,
        )
        let requestPrompts = AIPromptTemplates.requestPrompts(
            transcription: transcription,
            prompt: snapshotPrompt,
            mode: mode,
            selectedModel: selectedModel,
        )
        return (requestPrompts.systemPrompt, requestPrompts.userPrompt)
    }
}
