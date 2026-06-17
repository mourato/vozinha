// TranscribeAudioUseCase - Caso de uso para transcrever áudio

import Foundation
import MeetingAssistantCoreCommon

/// Caso de uso para transcrever arquivo de áudio
public final class TranscribeAudioUseCase: Sendable {
    public typealias PhaseChangeHandler = @Sendable (TranscriptionPhase) -> Void
    public typealias TranscriptionProgressHandler = @Sendable (Double) -> Void

    private let transcriptionRepository: TranscriptionRepository
    private let transcriptionStorageRepository: TranscriptionStorageRepository
    private let postProcessingRepository: PostProcessingRepository?
    private let transcriptPreprocessor: TranscriptIntelligencePreprocessor

    /// Inicializa o caso de uso com dependências
    public init(
        transcriptionRepository: TranscriptionRepository,
        transcriptionStorageRepository: TranscriptionStorageRepository,
        postProcessingRepository: PostProcessingRepository? = nil,
        transcriptPreprocessor: TranscriptIntelligencePreprocessor = .init()
    ) {
        self.transcriptionRepository = transcriptionRepository
        self.transcriptionStorageRepository = transcriptionStorageRepository
        self.postProcessingRepository = postProcessingRepository
        self.transcriptPreprocessor = transcriptPreprocessor
    }

    /// Executa o caso de uso para transcrever áudio
    /// - Parameters:
    ///   - audioURL: URL do arquivo de áudio a transcrever
    ///   - meeting: Reunião associada à transcrição
    ///   - applyPostProcessing: Se deve aplicar pós-processamento
    ///   - postProcessingPrompt: Prompt específico para pós-processamento (opcional)
    /// - Returns: Entidade de transcrição criada
    /// - Throws: TranscriptionError se falhar na transcrição
    public func execute(
        audioURL: URL,
        transcriptionID: UUID? = nil,
        meeting: MeetingEntity,
        inputSource: String? = nil,
        contextItems: [TranscriptionContextItem] = [],
        vocabularyReplacementRules: [VocabularyReplacementRule] = [],
        diarizationEnabledOverride: Bool? = nil,
        applyPostProcessing: Bool = false,
        postProcessingPrompt: DomainPostProcessingPrompt? = nil,
        defaultPostProcessingPrompt: DomainPostProcessingPrompt? = nil,
        postProcessingModel: String? = nil,
        autoDetectMeetingType: Bool = false,
        availablePrompts: [DomainPostProcessingPrompt] = [],
        postProcessingContext: String? = nil,
        kernelMode: IntelligenceKernelMode = .meeting,
        dictationStructuredPostProcessingEnabled: Bool = false,
        onPhaseChange: PhaseChangeHandler? = nil,
        onTranscriptionProgress: TranscriptionProgressHandler? = nil
    ) async throws -> TranscriptionEntity {
        onPhaseChange?(.preparing)

        do {
            onPhaseChange?(.processing)
            let transcriptionStartTime = Date()
            let response: DomainTranscriptionResponse
            do {
                if let diarizationPurposeAwareRepository = transcriptionRepository as? any TranscriptionRepositoryPurposeDiarized {
                    response = try await diarizationPurposeAwareRepository.transcribe(
                        audioURL: audioURL,
                        onProgress: onTranscriptionProgress,
                        diarizationEnabledOverride: diarizationEnabledOverride,
                        capturePurpose: meeting.capturePurpose
                    )
                } else if let diarizationAwareRepository = transcriptionRepository as? any TranscriptionRepositoryDiarizationOverride {
                    response = try await diarizationAwareRepository.transcribe(
                        audioURL: audioURL,
                        onProgress: onTranscriptionProgress,
                        diarizationEnabledOverride: diarizationEnabledOverride
                    )
                } else if let capturePurposeAwareRepository = transcriptionRepository as? any TranscriptionRepositoryPurposeAware {
                    response = try await capturePurposeAwareRepository.transcribe(
                        audioURL: audioURL,
                        onProgress: onTranscriptionProgress,
                        capturePurpose: meeting.capturePurpose
                    )
                } else {
                    response = try await transcriptionRepository.transcribe(
                        audioURL: audioURL,
                        onProgress: onTranscriptionProgress
                    )
                }
            } catch {
                throw DomainTranscriptionError.transcriptionFailed(error.localizedDescription)
            }
            let transcriptionDuration = Date().timeIntervalSince(transcriptionStartTime)

            return try await finalizePreparedResponse(
                response: response,
                transcriptionID: transcriptionID,
                meeting: meeting,
                inputSource: inputSource,
                contextItems: contextItems,
                vocabularyReplacementRules: vocabularyReplacementRules,
                applyPostProcessing: applyPostProcessing,
                postProcessingPrompt: postProcessingPrompt,
                defaultPostProcessingPrompt: defaultPostProcessingPrompt,
                postProcessingModel: postProcessingModel,
                autoDetectMeetingType: autoDetectMeetingType,
                availablePrompts: availablePrompts,
                postProcessingContext: postProcessingContext,
                kernelMode: kernelMode,
                dictationStructuredPostProcessingEnabled: dictationStructuredPostProcessingEnabled,
                transcriptionDuration: transcriptionDuration,
                onPhaseChange: onPhaseChange
            )
        } catch {
            onPhaseChange?(.failed)
            throw error
        }
    }

    public func finalizePreparedResponse(
        response: DomainTranscriptionResponse,
        transcriptionID: UUID?,
        meeting: MeetingEntity,
        inputSource: String? = nil,
        contextItems: [TranscriptionContextItem] = [],
        vocabularyReplacementRules: [VocabularyReplacementRule] = [],
        applyPostProcessing: Bool = false,
        postProcessingPrompt: DomainPostProcessingPrompt? = nil,
        defaultPostProcessingPrompt: DomainPostProcessingPrompt? = nil,
        postProcessingModel: String? = nil,
        autoDetectMeetingType: Bool = false,
        availablePrompts: [DomainPostProcessingPrompt] = [],
        postProcessingContext: String? = nil,
        kernelMode: IntelligenceKernelMode = .meeting,
        dictationStructuredPostProcessingEnabled: Bool = false,
        transcriptionDuration: Double,
        onPhaseChange: PhaseChangeHandler? = nil
    ) async throws -> TranscriptionEntity {
        do {
            let (replacedTranscriptionText, replacedSegments, qualityProfile) = processTranscriptionResult(
                response: response,
                vocabularyReplacementRules: vocabularyReplacementRules
            )
            try ensureNonEmptyTranscriptionText(replacedTranscriptionText)
            logValidatedTranscriptMetrics(
                text: replacedTranscriptionText,
                segmentCount: replacedSegments.count,
                durationSeconds: response.durationSeconds
            )

            let resolvedPostProcessingContext = PostProcessingSystemContextMetadata.augment(postProcessingContext)

            let postProcessingInput = mergedPostProcessingInput(
                transcriptionText: qualityProfile.normalizedTextForIntelligence,
                qualityProfile: qualityProfile,
                context: resolvedPostProcessingContext,
                meetingNotes: contextItems.first(where: { $0.source == .meetingNotes })?.text,
                includeQualityMetadata: kernelMode == .meeting
            )

            let postProcessingConfig = PostProcessingConfiguration(
                applyPostProcessing: applyPostProcessing,
                postProcessingPrompt: postProcessingPrompt,
                defaultPostProcessingPrompt: defaultPostProcessingPrompt,
                autoDetectMeetingType: autoDetectMeetingType,
                availablePrompts: availablePrompts,
                kernelMode: kernelMode,
                dictationStructuredPostProcessingEnabled: dictationStructuredPostProcessingEnabled,
                postProcessingContext: resolvedPostProcessingContext
            )

            if postProcessingConfig.shouldRunPostProcessing(postProcessingRepository: postProcessingRepository) {
                onPhaseChange?(.postProcessing)
            }

            let postProcessingStartTime = Date()
            let postProcessingResult = await performPostProcessing(
                postProcessingInput: postProcessingInput,
                postProcessingRepository: postProcessingRepository,
                config: postProcessingConfig,
                qualityProfile: qualityProfile
            )
            let postProcessingDuration = Date().timeIntervalSince(postProcessingStartTime)
            let resolvedMeeting = meetingWithResolvedTitle(meeting, postProcessingResult: postProcessingResult)

            let transcription = TranscriptionEntity(
                meeting: resolvedMeeting,
                config: buildConfiguration(
                    .init(
                        transcriptionID: transcriptionID,
                        response: response,
                        replacedText: replacedTranscriptionText,
                        replacedSegments: replacedSegments,
                        qualityProfile: qualityProfile,
                        contextItems: contextItems,
                        processedContent: postProcessingResult.processedContent,
                        canonicalSummary: postProcessingResult.canonicalSummary,
                        promptId: postProcessingResult.promptId,
                        promptTitle: postProcessingResult.promptTitle,
                        meetingType: postProcessingResult.meetingType,
                        inputSource: inputSource,
                        transcriptionDuration: transcriptionDuration,
                        postProcessingDuration: postProcessingDuration,
                        postProcessingModel: postProcessingModel,
                        requestSystemPrompt: postProcessingResult.requestSystemPrompt,
                        requestUserPrompt: postProcessingResult.requestUserPrompt,
                        postProcessingFailureReason: postProcessingResult.failureReason
                    )
                )
            )

            try await transcriptionStorageRepository.saveTranscription(transcription)
            onPhaseChange?(.completed)
            return transcription
        } catch {
            onPhaseChange?(.failed)
            throw error
        }
    }

    // MARK: - Private Helpers

    /// Processa o resultado da transcrição aplicando substituições de vocabulário
    private func processTranscriptionResult(
        response: DomainTranscriptionResponse,
        vocabularyReplacementRules: [VocabularyReplacementRule]
    ) -> (String, [DomainTranscriptionSegment], TranscriptionQualityProfile) {
        let replacedTranscriptionText = applyVocabularyReplacements(
            to: response.text,
            with: vocabularyReplacementRules
        )
        let replacedSegments = applyVocabularyReplacements(
            to: response.segments,
            with: vocabularyReplacementRules
        )
        let qualityProfile = transcriptPreprocessor.preprocess(
            transcriptionText: replacedTranscriptionText,
            segments: replacedSegments,
            asrConfidenceScore: response.confidenceScore
        )
        return (replacedTranscriptionText, replacedSegments, qualityProfile)
    }

    private func ensureNonEmptyTranscriptionText(_ text: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainTranscriptionError.transcriptionFailed(
                PostProcessingError.emptyTranscription.localizedDescription
            )
        }
    }

    private func logValidatedTranscriptMetrics(
        text: String,
        segmentCount: Int,
        durationSeconds: Double
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmed.split { $0.isWhitespace || $0.isNewline }.count
        AppLogger.info(
            "Validated transcript before post-processing",
            category: .transcriptionEngine,
            extra: [
                "characters": String(trimmed.count),
                "words": String(wordCount),
                "segments": String(segmentCount),
                "durationSeconds": String(durationSeconds),
            ]
        )
    }

    private func applyVocabularyReplacements(
        to text: String,
        with rules: [VocabularyReplacementRule]
    ) -> String {
        VocabularyReplacementRule.apply(rules: rules, to: text)
    }

    private func applyVocabularyReplacements(
        to segments: [DomainTranscriptionSegment],
        with rules: [VocabularyReplacementRule]
    ) -> [DomainTranscriptionSegment] {
        segments.map { segment in
            DomainTranscriptionSegment(
                id: segment.id,
                speaker: segment.speaker,
                text: applyVocabularyReplacements(to: segment.text, with: rules),
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }
    }

    private struct ConfigurationBuildInput {
        let transcriptionID: UUID?
        let response: DomainTranscriptionResponse
        let replacedText: String
        let replacedSegments: [DomainTranscriptionSegment]
        let qualityProfile: TranscriptionQualityProfile
        let contextItems: [TranscriptionContextItem]
        let processedContent: String?
        let canonicalSummary: CanonicalSummary?
        let promptId: UUID?
        let promptTitle: String?
        let meetingType: String?
        let inputSource: String?
        let transcriptionDuration: Double
        let postProcessingDuration: Double
        let postProcessingModel: String?
        let requestSystemPrompt: String?
        let requestUserPrompt: String?
        let postProcessingFailureReason: String?
    }

    private func buildConfiguration(_ input: ConfigurationBuildInput) -> TranscriptionEntity.Configuration {
        let sortedSegments = input.replacedSegments.sorted { lhs, rhs in
            if lhs.startTime != rhs.startTime {
                return lhs.startTime < rhs.startTime
            }
            if lhs.endTime != rhs.endTime {
                return lhs.endTime < rhs.endTime
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        var config = TranscriptionEntity.Configuration(
            text: input.processedContent ?? input.replacedText,
            rawText: input.response.text,
            segments: sortedSegments.map { segment in
                TranscriptionEntity.Segment(
                    speaker: segment.speaker,
                    text: segment.text,
                    startTime: segment.startTime,
                    endTime: segment.endTime
                )
            },
            language: input.response.language
        )
        if let transcriptionID = input.transcriptionID {
            config.id = transcriptionID
        }
        config.contextItems = input.contextItems
        config.processedContent = input.processedContent
        config.canonicalSummary = input.canonicalSummary
        config.qualityProfile = input.qualityProfile
        config.postProcessingPromptId = input.promptId
        config.postProcessingPromptTitle = input.promptTitle
        config.modelName = input.response.model
        config.meetingType = input.meetingType
        config.inputSource = input.inputSource
        config.transcriptionDuration = input.transcriptionDuration
        config.postProcessingDuration = input.processedContent == nil ? 0 : input.postProcessingDuration
        config.postProcessingModel = input.processedContent == nil ? nil : input.postProcessingModel
        config.postProcessingRequestSystemPrompt = input.requestSystemPrompt
        config.postProcessingRequestUserPrompt = input.requestUserPrompt
        config.postProcessingFailureReason = input.postProcessingFailureReason
        return config
    }

    private func mergedPostProcessingInput(
        transcriptionText: String,
        qualityProfile: TranscriptionQualityProfile,
        context: String?,
        meetingNotes: String?,
        includeQualityMetadata: Bool
    ) -> String {
        var blocks = [transcriptionText]
        if includeQualityMetadata {
            blocks.append(qualityMetadataBlock(from: qualityProfile))
        }

        if let meetingNotes {
            let trimmedMeetingNotes = meetingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedMeetingNotes.isEmpty {
                let sanitizedMeetingNotes = MeetingNotesMarkdownSanitizer
                    .sanitizeForPromptBlockContent(trimmedMeetingNotes)
                blocks.append(
                    """
                    <MEETING_NOTES>
                    \(sanitizedMeetingNotes)
                    </MEETING_NOTES>
                    """
                )
            }
        }

        if let context {
            let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedContext.isEmpty {
                let sanitizedContext = MeetingNotesMarkdownSanitizer
                    .sanitizeForPromptBlockContent(trimmedContext)
                blocks.append(
                    """
                    <CONTEXT_METADATA>
                    \(sanitizedContext)
                    </CONTEXT_METADATA>
                    """
                )
            }
        }

        return blocks.joined(separator: "\n\n")
    }

    private func qualityMetadataBlock(from qualityProfile: TranscriptionQualityProfile) -> String {
        let markerLines: [String] = if qualityProfile.markers.isEmpty {
            ["none"]
        } else {
            qualityProfile.markers.map { marker in
                "- [\(marker.reason.rawValue)] \(marker.snippet) [\(marker.startTime)-\(marker.endTime)]"
            }
        }

        return """
        <TRANSCRIPT_QUALITY>
        normalizationVersion: \(qualityProfile.normalizationVersion)
        overallConfidence: \(qualityProfile.overallConfidence)
        containsUncertainty: \(qualityProfile.containsUncertainty)
        markers:
        \(markerLines.joined(separator: "\n"))
        </TRANSCRIPT_QUALITY>
        """
    }

    private func meetingWithResolvedTitle(
        _ meeting: MeetingEntity,
        postProcessingResult: PostProcessingResult
    ) -> MeetingEntity {
        guard meeting.supportsMeetingConversation else {
            return meeting.sanitizedForPersistence()
        }

        guard let summaryTitle = postProcessingResult.canonicalSummary?.title.trimmingCharacters(in: .whitespacesAndNewlines),
              !summaryTitle.isEmpty
        else {
            return meeting
        }

        if let persistedTitle = meeting.title?.trimmingCharacters(in: .whitespacesAndNewlines), !persistedTitle.isEmpty {
            return meeting
        }

        if let calendarTitle = meeting.linkedCalendarEvent?.trimmedTitle, !calendarTitle.isEmpty {
            return meeting
        }

        var updatedMeeting = meeting
        updatedMeeting.title = summaryTitle
        return updatedMeeting
    }
}

/// Erros específicos do caso de uso de transcrição
public enum DomainTranscriptionError: Error {
    case serviceUnavailable
    case transcriptionFailed(String)
    case invalidAudioFile
    case postProcessingFailed(String)
}
