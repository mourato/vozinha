import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Retry Transcription

extension RecordingManager {
    /// Retry transcription for an existing entry using the currently active model.
    /// - Parameter transcription: Existing transcription to overwrite with new results.
    public func retryTranscription(for transcription: Transcription) async {
        guard !isTranscribing else {
            AppLogger.info("Already transcribing", category: .recordingManager)
            return
        }

        guard let audioURL = resolveRetryAudioURL(for: transcription) else { return }

        await runRetryTranscription(audioURL: audioURL, transcription: transcription)
    }

    func resolveRetryAudioURL(for transcription: Transcription) -> URL? {
        guard let audioURL = transcription.audioURL else {
            AppLogger.error("Audio file missing for retry", category: .recordingManager, extra: ["id": transcription.id.uuidString])
            lastError = AudioImportError.fileNotFound
            return nil
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            AppLogger.error("Audio file not found for retry", category: .recordingManager, extra: ["path": audioURL.path])
            lastError = AudioImportError.fileNotFound
            return nil
        }

        return audioURL
    }

    func runRetryTranscription(audioURL: URL, transcription: Transcription) async {
        let preparedAudio = await prepareAudioForTranscription(
            audioURL: audioURL,
            allowSilenceRemoval: true
        )
        defer {
            cleanupPreparedTranscriptionAudio(preparedAudio)
        }

        isTranscribing = true
        cancelEstimatedPostProcessingProgress()
        let audioDuration = await getAudioDuration(from: preparedAudio.transcriptionURL)
        transcriptionStatus.beginTranscription(audioDuration: audioDuration)
        RecordingIndicatorProcessingStateStore.shared.update(
            snapshot: RecordingIndicatorProcessingSnapshot(step: .preparingAudio, progressPercent: 0)
        )

        do {
            let updated = try await performRetryTranscription(
                audioURL: preparedAudio.transcriptionURL,
                transcription: transcription,
                audioDuration: audioDuration
            )
            try await storage.saveTranscription(updated)
            RecordingIndicatorProcessingStateStore.shared.update(
                snapshot: RecordingIndicatorProcessingSnapshot(step: .finalizingResult, progressPercent: 100)
            )
            transcriptionStatus.completeTranscription(success: true)
            notifySuccess(for: updated)
            scheduleStatusReset()
        } catch {
            cancelEstimatedPostProcessingProgress()
            handleTranscriptionError(error)
        }

        cancelEstimatedPostProcessingProgress()
        isTranscribing = false
    }

    func performRetryTranscription(
        audioURL: URL,
        transcription: Transcription,
        audioDuration: Double?
    ) async throws -> Transcription {
        try await performHealthCheck(capturePurpose: transcription.meeting.capturePurpose)

        let transcriptionStart = Date()
        let diarizationEnabledOverride = shouldEnableDiarization(for: transcription.meeting)
        let response = try await performTranscription(
            audioURL: audioURL,
            diarizationEnabledOverride: diarizationEnabledOverride,
            capturePurpose: transcription.meeting.capturePurpose
        )
        let transcriptionProcessingDuration = Date().timeIntervalSince(transcriptionStart)
        let settings = AppSettingsStore.shared
        let replacedText = applyVocabularyReplacements(
            to: response.text,
            with: settings.vocabularyReplacementRules
        )
        guard !replacedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranscriptionError.transcriptionFailed(
                PostProcessingError.emptyTranscription.localizedDescription
            )
        }
        let wordCount = replacedText.split { $0.isWhitespace || $0.isNewline }.count
        AppLogger.info(
            "Validated transcript before post-processing",
            category: .recordingManager,
            extra: [
                "characters": String(replacedText.trimmingCharacters(in: .whitespacesAndNewlines).count),
                "words": String(wordCount),
                "segments": String(response.segments.count),
                "durationSeconds": String(response.durationSeconds),
            ]
        )
        let replacedSegments = applyVocabularyReplacements(
            to: response.segments,
            with: settings.vocabularyReplacementRules
        )
        let qualityProfile = transcriptPreprocessor.preprocess(
            transcriptionText: replacedText,
            segments: replacedSegments.map {
                DomainTranscriptionSegment(
                    id: $0.id,
                    speaker: $0.speaker,
                    text: $0.text,
                    startTime: $0.startTime,
                    endTime: $0.endTime
                )
            },
            asrConfidenceScore: response.confidenceScore
        )
        let includeQualityMetadata = !isDictationMode(
            for: transcription.meeting,
            capturePurposeOverride: transcription.meeting.capturePurpose
        )
        let resolvedPostProcessingContext = PostProcessingSystemContextMetadata.augment(postProcessingContext)
        let postProcessingInput = mergedPostProcessingInput(
            transcriptionText: qualityProfile.normalizedTextForIntelligence,
            qualityProfile: qualityProfile,
            context: resolvedPostProcessingContext,
            meetingNotes: transcription.contextItems.first(where: { $0.source == .meetingNotes })?.text,
            includeQualityMetadata: includeQualityMetadata
        )

        let meeting = updatedMeeting(for: transcription.meeting, audioDuration: audioDuration)
        let postProcessing = await applyPostProcessing(
            postProcessingInput: postProcessingInput,
            meeting: meeting,
            qualityProfile: qualityProfile,
            capturePurposeOverride: transcription.meeting.capturePurpose
        )
        let resolvedMeeting = meetingWithResolvedTitle(meeting, canonicalSummary: postProcessing.canonicalSummary)

        return Transcription(
            id: transcription.id,
            meeting: resolvedMeeting,
            contextItems: transcription.contextItems,
            segments: replacedSegments,
            text: postProcessing.processedContent ?? replacedText,
            rawText: response.text,
            processedContent: postProcessing.processedContent,
            canonicalSummary: postProcessing.canonicalSummary,
            qualityProfile: qualityProfile,
            postProcessingPromptId: postProcessing.promptId,
            postProcessingPromptTitle: postProcessing.promptTitle,
            postProcessingRequestSystemPrompt: postProcessing.requestSystemPrompt,
            postProcessingRequestUserPrompt: postProcessing.requestUserPrompt,
            language: response.language,
            createdAt: transcription.createdAt,
            modelName: response.model,
            inputSource: transcription.inputSource,
            transcriptionDuration: transcriptionProcessingDuration,
            postProcessingDuration: postProcessing.duration,
            postProcessingModel: postProcessing.model,
            meetingType: transcription.meeting.type.rawValue,
            postProcessingFailureReason: postProcessing.failureReason
        )
    }

    // MARK: - Vocabulary Replacements

    func applyVocabularyReplacements(
        to text: String,
        with rules: [VocabularyReplacementRule]
    ) -> String {
        VocabularyReplacementRule.apply(rules: rules, to: text)
    }

    func applyVocabularyReplacements(
        to segments: [Transcription.Segment],
        with rules: [VocabularyReplacementRule]
    ) -> [Transcription.Segment] {
        segments.map { segment in
            Transcription.Segment(
                id: segment.id,
                speaker: segment.speaker,
                text: applyVocabularyReplacements(to: segment.text, with: rules),
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }
    }

    // MARK: - Post Processing Input

    func mergedPostProcessingInput(
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

    func qualityMetadataBlock(from qualityProfile: TranscriptionQualityProfile) -> String {
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

    func recalibrateCanonicalSummary(
        _ summary: CanonicalSummary,
        with qualityProfile: TranscriptionQualityProfile
    ) -> CanonicalSummary {
        let trustFlags = CanonicalSummary.TrustFlags(
            isGroundedInTranscript: summary.trustFlags.isGroundedInTranscript,
            containsSpeculation: summary.trustFlags.containsSpeculation || qualityProfile.containsUncertainty,
            isHumanReviewed: summary.trustFlags.isHumanReviewed,
            confidenceScore: min(summary.trustFlags.confidenceScore, qualityProfile.overallConfidence)
        )

        return CanonicalSummary(
            schemaVersion: summary.schemaVersion,
            generatedAt: summary.generatedAt,
            title: summary.title,
            summary: summary.summary,
            keyPoints: summary.keyPoints,
            decisions: summary.decisions,
            actionItems: summary.actionItems,
            openQuestions: summary.openQuestions,
            trustFlags: trustFlags
        )
    }

    func meetingWithResolvedTitle(
        _ meeting: Meeting,
        canonicalSummary: CanonicalSummary?
    ) -> Meeting {
        guard meeting.supportsMeetingConversation else {
            return meeting.sanitizedForPersistence()
        }

        guard let title = canonicalSummary?.title.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return meeting
        }

        if let persistedTitle = meeting.title?.trimmingCharacters(in: .whitespacesAndNewlines), !persistedTitle.isEmpty {
            return meeting
        }

        if let calendarTitle = meeting.linkedCalendarEvent?.trimmedTitle, !calendarTitle.isEmpty {
            return meeting
        }

        var updatedMeeting = meeting
        updatedMeeting.title = title
        return updatedMeeting
    }

    func updatedMeeting(for meeting: Meeting, audioDuration: Double?) -> Meeting {
        guard let audioDuration else { return meeting }
        guard meeting.endTime == nil else { return meeting }

        var updatedMeeting = meeting
        updatedMeeting.endTime = meeting.startTime.addingTimeInterval(audioDuration)
        return updatedMeeting
    }

    func resolveInputSourceLabel(
        for meeting: Meeting,
        recordingSource: RecordingSource? = nil
    ) -> String? {
        if meeting.app == .importedFile {
            return "meeting.app.imported".localized
        }

        switch recordingSource ?? self.recordingSource {
        case .microphone:
            return resolveMicrophoneDeviceName() ?? "recording.source.microphone".localized
        case .system:
            return "recording.source.system".localized
        case .all:
            let system = "recording.source.system".localized
            let mic = resolveMicrophoneDeviceName()
            if let mic {
                return "\(system) + \(mic)"
            }
            let microphone = "recording.source.microphone".localized
            return "\(system) + \(microphone)"
        }
    }

    func resolveMicrophoneDeviceName() -> String? {
        let settings = AppSettingsStore.shared

        return microphoneInputSelectionResolver.resolvePreferredMicrophoneDeviceName(settings: settings)
    }

    func resolveSystemDefaultMicrophoneDeviceName() -> String? {
        microphoneInputSelectionResolver.resolveSystemDefaultMicrophoneDeviceName()
    }
}
