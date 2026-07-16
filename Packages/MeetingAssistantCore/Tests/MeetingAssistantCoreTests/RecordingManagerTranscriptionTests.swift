import AppKit
import AVFoundation
import Combine
import CryptoKit
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
extension RecordingManagerTests {
    func testStopRecording_DictationUsesDictationPromptSelection() async throws {
        let manager = try XCTUnwrap(manager)
        let settings = AppSettingsStore.shared

        let originalPostProcessing = settings.postProcessingEnabled
        let originalMeetingSelection = settings.enhancementsAISelection
        let originalDictationSelection = settings.enhancementsDictationAISelection
        let originalMeetingPrompts = settings.meetingPrompts
        let originalDictationPrompts = settings.dictationPrompts
        let originalSelectedPromptId = settings.selectedPromptId
        let originalDictationSelectedPromptId = settings.dictationSelectedPromptId
        let originalDictationStyles = settings.dictationStyles

        let meetingPrompt = PostProcessingPrompt(
            title: "Meeting Prompt Test",
            promptText: "MEETING_PROMPT_SENTINEL",
            isActive: true,
        )
        let dictationPrompt = PostProcessingPrompt(
            title: "Dictation Prompt Test",
            promptText: "DICTATION_PROMPT_SENTINEL",
            isActive: true,
        )
        let dictationSelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")

        defer {
            settings.postProcessingEnabled = originalPostProcessing
            settings.enhancementsAISelection = originalMeetingSelection
            settings.enhancementsDictationAISelection = originalDictationSelection
            settings.meetingPrompts = originalMeetingPrompts
            settings.dictationPrompts = originalDictationPrompts
            settings.selectedPromptId = originalSelectedPromptId
            settings.dictationSelectedPromptId = originalDictationSelectedPromptId
            settings.dictationStyles = originalDictationStyles
        }

        settings.postProcessingEnabled = true
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")
        settings.enhancementsDictationAISelection = dictationSelection
        // Apply enhancementsSelection to the default dictation style so the snapshot picks it up.
        var updatedStyles = settings.dictationStyles
        if let defaultIndex = updatedStyles.firstIndex(where: { $0.isDefault }) {
            updatedStyles[defaultIndex] = DictationStyle(
                id: updatedStyles[defaultIndex].id,
                name: updatedStyles[defaultIndex].name,
                iconSymbol: updatedStyles[defaultIndex].iconSymbol,
                promptInstructions: updatedStyles[defaultIndex].promptInstructions,
                postProcessingEnabled: true,
                forceMarkdownOutput: updatedStyles[defaultIndex].forceMarkdownOutput,
                replaceBasePrompt: updatedStyles[defaultIndex].replaceBasePrompt,
                outputLanguage: updatedStyles[defaultIndex].outputLanguage,
                targets: updatedStyles[defaultIndex].targets,
                contextSourcePolicy: updatedStyles[defaultIndex].contextSourcePolicy,
                enhancementsSelection: dictationSelection,
                isDefault: true,
                textHandlingPolicy: updatedStyles[defaultIndex].textHandlingPolicy,
                transcriptionConfiguration: updatedStyles[defaultIndex].transcriptionConfiguration,
            )
        }
        settings.dictationStyles = updatedStyles
        settings.meetingPrompts = [meetingPrompt]
        settings.dictationPrompts = [dictationPrompt]
        settings.selectedPromptId = meetingPrompt.id
        settings.dictationSelectedPromptId = dictationPrompt.id

        await manager.startRecording(source: .microphone)
        XCTAssertTrue(manager.isRecording)

        let meeting = Meeting(app: .unknown)
        let configuration = manager.debugResolvePostProcessingConfiguration(meeting: meeting, settings: settings)

        XCTAssertEqual(configuration.kernelMode, .dictation)
        XCTAssertTrue(configuration.applyPostProcessing)
        XCTAssertEqual(configuration.promptId, dictationPrompt.id)
        XCTAssertEqual(configuration.promptTitle, dictationPrompt.title)

        await manager.cancelRecording()
    }

    func testStopRecording_MeetingUsesMeetingPromptSelection() async throws {
        let manager = try XCTUnwrap(manager)
        let settings = AppSettingsStore.shared

        let originalPostProcessing = settings.postProcessingEnabled
        let originalMeetingSelection = settings.enhancementsAISelection
        let originalDictationSelection = settings.enhancementsDictationAISelection
        let originalMeetingPrompts = settings.meetingPrompts
        let originalDictationPrompts = settings.dictationPrompts
        let originalSelectedPromptId = settings.selectedPromptId
        let originalDictationSelectedPromptId = settings.dictationSelectedPromptId
        let originalDictationStyles = settings.dictationStyles

        let meetingPrompt = PostProcessingPrompt(
            title: "Meeting Prompt Test 2",
            promptText: "MEETING_PROMPT_SENTINEL_2",
            isActive: true,
        )
        let dictationPrompt = PostProcessingPrompt(
            title: "Dictation Prompt Test 2",
            promptText: "DICTATION_PROMPT_SENTINEL_2",
            isActive: true,
        )

        defer {
            settings.postProcessingEnabled = originalPostProcessing
            settings.enhancementsAISelection = originalMeetingSelection
            settings.enhancementsDictationAISelection = originalDictationSelection
            settings.meetingPrompts = originalMeetingPrompts
            settings.dictationPrompts = originalDictationPrompts
            settings.selectedPromptId = originalSelectedPromptId
            settings.dictationSelectedPromptId = originalDictationSelectedPromptId
            settings.dictationStyles = originalDictationStyles
        }

        settings.postProcessingEnabled = true
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")
        settings.enhancementsDictationAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")
        settings.meetingPrompts = [meetingPrompt]
        settings.dictationPrompts = [dictationPrompt]
        settings.selectedPromptId = meetingPrompt.id
        settings.dictationSelectedPromptId = dictationPrompt.id

        await manager.startRecording(source: .all)
        XCTAssertTrue(manager.isRecording)

        let meeting = Meeting(app: .zoom)
        let configuration = manager.debugResolvePostProcessingConfiguration(meeting: meeting, settings: settings)

        XCTAssertEqual(configuration.kernelMode, .meeting)
        XCTAssertTrue(configuration.applyPostProcessing)
        XCTAssertEqual(configuration.promptId, meetingPrompt.id)
        XCTAssertEqual(configuration.promptTitle, meetingPrompt.title)

        await manager.cancelRecording()
    }

    // MARK: - Error Handling Tests

    func testStartRecording_FailsWhenSystemRecorderFails() async throws {
        // Given
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)

        mockMic.permissionGranted = true
        mockSystem.permissionGranted = true
        mockMic.shouldFailStart = true

        // When
        do {
            try await mockMic.startRecording(to: URL(fileURLWithPath: "/tmp/test.m4a"), retryCount: 0)
            XCTFail("Expected error to be thrown")
        } catch {
            // Then
            XCTAssertNotNil(error)
        }
    }

    func testStopRecording_HandlesErrorGracefully() async throws {
        // Given
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)

        mockMic.permissionGranted = true
        mockSystem.permissionGranted = true

        await manager.startRecording()

        // When - stopping should not throw even if cleanup fails
        await manager.stopRecording()

        // Then - should have stopped
        XCTAssertFalse(manager.isRecording)
    }

    func testStopRecording_WithSilenceRemovalDisabled_UsesOriginalAudio() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)
        let mockTranscription = try XCTUnwrap(mockTranscription)
        let mockCompactor = try XCTUnwrap(mockAudioSilenceCompactor)
        let settings = AppSettingsStore.shared

        settings.removeSilenceBeforeProcessing = false
        mockMic.permissionGranted = true
        mockSystem.permissionGranted = true

        await manager.startRecording()
        let rawURL = try XCTUnwrap(mockMic.currentRecordingURL)
        try writeTestAudioFile(at: rawURL)

        await manager.stopRecording()

        XCTAssertEqual(mockTranscription.lastTranscribeAudioURL, rawURL)
        XCTAssertEqual(mockCompactor.compactCallCount, 0)
    }

    func testStopRecording_WithSilenceRemovalEnabled_UsesTemporaryCompactedAudioAndCleansItUp() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)
        let mockTranscription = try XCTUnwrap(mockTranscription)
        let mockCompactor = try XCTUnwrap(mockAudioSilenceCompactor)
        let settings = AppSettingsStore.shared

        settings.audioFormat = .m4a
        settings.removeSilenceBeforeProcessing = true
        mockMic.permissionGranted = true
        mockSystem.permissionGranted = true

        await manager.startRecording()
        let rawURL = try XCTUnwrap(mockMic.currentRecordingURL)
        try writeTestAudioFile(at: rawURL)

        await manager.stopRecording()

        let compactedURL = try XCTUnwrap(mockCompactor.lastOutputURL)
        XCTAssertEqual(mockTranscription.lastTranscribeAudioURL, compactedURL)
        XCTAssertEqual(mockCompactor.lastFormat, .wav)
        XCTAssertEqual(compactedURL.pathExtension.lowercased(), "wav")
        XCTAssertFalse(FileManager.default.fileExists(atPath: compactedURL.path))
    }

    func testStopRecording_WithRemoteGroqTranscription_SkipsSilenceCompaction() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)
        let mockTranscription = try XCTUnwrap(mockTranscription)
        let mockCompactor = try XCTUnwrap(mockAudioSilenceCompactor)
        let settings = AppSettingsStore.shared
        let originalAudioFormat = settings.audioFormat
        let originalRemoveSilence = settings.removeSilenceBeforeProcessing
        let originalSelection = settings.transcriptionDictationSelection
        let originalModels = settings.transcriptionProviderSelectedModels

        defer {
            settings.audioFormat = originalAudioFormat
            settings.removeSilenceBeforeProcessing = originalRemoveSilence
            settings.transcriptionDictationSelection = originalSelection
            settings.transcriptionProviderSelectedModels = originalModels
        }

        settings.audioFormat = .m4a
        settings.removeSilenceBeforeProcessing = true
        settings.updateTranscriptionDictationSelection(
            provider: .groq,
            model: "whisper-large-v3-turbo",
        )
        mockMic.permissionGranted = true
        mockSystem.permissionGranted = true

        await manager.startCapture(purpose: .dictation)
        let rawURL = try XCTUnwrap(mockMic.currentRecordingURL)
        try writeTestAudioFile(at: rawURL)

        await manager.stopRecording()

        XCTAssertEqual(mockTranscription.lastTranscribeAudioURL, rawURL)
        XCTAssertEqual(mockCompactor.compactCallCount, 0)
    }

    func testStopRecording_WhenCompactionFails_FallsBackToOriginalAudio() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)
        let mockTranscription = try XCTUnwrap(mockTranscription)
        let mockCompactor = try XCTUnwrap(mockAudioSilenceCompactor)
        let settings = AppSettingsStore.shared

        settings.removeSilenceBeforeProcessing = true
        mockCompactor.shouldThrow = true
        mockMic.permissionGranted = true
        mockSystem.permissionGranted = true

        await manager.startRecording()
        let rawURL = try XCTUnwrap(mockMic.currentRecordingURL)
        try writeTestAudioFile(at: rawURL)

        await manager.stopRecording()

        XCTAssertEqual(mockTranscription.lastTranscribeAudioURL, rawURL)
    }

    func testRetryTranscription_ReappliesSilenceCompactionAndCleansTemporaryCopy() async throws {
        let manager = try XCTUnwrap(manager)
        let mockTranscription = try XCTUnwrap(mockTranscription)
        let mockCompactor = try XCTUnwrap(mockAudioSilenceCompactor)
        let settings = AppSettingsStore.shared

        settings.removeSilenceBeforeProcessing = true

        let rawURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        try writeTestAudioFile(at: rawURL)
        defer { try? FileManager.default.removeItem(at: rawURL) }

        let transcription = Transcription(
            meeting: Meeting(app: .zoom, capturePurpose: .meeting, audioFilePath: rawURL.path),
            text: "Existing",
            rawText: "Existing",
            processedContent: nil,
            postProcessingPromptId: nil,
            postProcessingPromptTitle: nil,
            language: "en",
            modelName: "test-model",
        )

        await manager.retryTranscription(for: transcription)

        let compactedURL = try XCTUnwrap(mockCompactor.lastOutputURL)
        XCTAssertEqual(mockTranscription.lastTranscribeAudioURL, compactedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: compactedURL.path))
    }

    func testRetryTranscription_RemoteDictationOverrideSkipsHealthCheckAndSilenceCompaction() async throws {
        let manager = try XCTUnwrap(manager)
        let mockTranscription = try XCTUnwrap(mockTranscription)
        let mockCompactor = try XCTUnwrap(mockAudioSilenceCompactor)
        let settings = AppSettingsStore.shared

        let originalRemoveSilence = settings.removeSilenceBeforeProcessing
        let originalSelection = settings.transcriptionDictationSelection
        defer {
            settings.removeSilenceBeforeProcessing = originalRemoveSilence
            settings.transcriptionDictationSelection = originalSelection
        }

        settings.removeSilenceBeforeProcessing = true
        settings.updateTranscriptionDictationSelection(
            provider: .local,
            model: LocalTranscriptionModel.parakeetTdt06BV3.rawValue,
        )
        readyRetryProviders = [.groq]
        mockTranscription.shouldFailHealthCheck = true

        let rawURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        try writeTestAudioFile(at: rawURL)
        defer { try? FileManager.default.removeItem(at: rawURL) }

        let transcription = Transcription(
            meeting: Meeting(app: .unknown, capturePurpose: .dictation, audioFilePath: rawURL.path),
            text: "Existing",
            rawText: "Existing",
            processedContent: nil,
            postProcessingPromptId: nil,
            postProcessingPromptTitle: nil,
            language: "en",
            modelName: "test-model",
        )

        await manager.retryTranscription(
            for: transcription,
            selectionOverride: TranscriptionProviderSelection(
                provider: .groq,
                selectedModel: TranscriptionProvider.groqPresetModelIDs[0],
            ),
        )

        XCTAssertEqual(mockTranscription.healthCheckCallCount, 0)
        XCTAssertEqual(mockCompactor.compactCallCount, 0)
        XCTAssertEqual(mockTranscription.lastTranscribeAudioURL, rawURL)
    }

    func testRetryTranscription_RemoteMeetingOverrideFallsBackToConfiguredLocalSelection() async throws {
        let manager = try XCTUnwrap(manager)
        let mockTranscription = try XCTUnwrap(mockTranscription)
        let mockCompactor = try XCTUnwrap(mockAudioSilenceCompactor)
        let settings = AppSettingsStore.shared
        let originalRemoveSilence = settings.removeSilenceBeforeProcessing
        defer {
            settings.removeSilenceBeforeProcessing = originalRemoveSilence
        }

        settings.removeSilenceBeforeProcessing = true
        readyRetryProviders = [.groq]

        let rawURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        try writeTestAudioFile(at: rawURL)
        defer { try? FileManager.default.removeItem(at: rawURL) }

        let transcription = Transcription(
            meeting: Meeting(app: .zoom, capturePurpose: .meeting, audioFilePath: rawURL.path),
            text: "Existing",
            rawText: "Existing",
            processedContent: nil,
            postProcessingPromptId: nil,
            postProcessingPromptTitle: nil,
            language: "en",
            modelName: "test-model",
        )

        await manager.retryTranscription(
            for: transcription,
            selectionOverride: TranscriptionProviderSelection(
                provider: .groq,
                selectedModel: TranscriptionProvider.groqPresetModelIDs[0],
            ),
        )

        let compactedURL = try XCTUnwrap(mockCompactor.lastOutputURL)
        XCTAssertEqual(mockTranscription.healthCheckCallCount, 1)
        XCTAssertEqual(mockCompactor.compactCallCount, 1)
        XCTAssertEqual(mockTranscription.lastTranscribeAudioURL, compactedURL)
    }

    func testApplyPostProcessing_UsesDictationPromptForImportedDictationAudio() async throws {
        let manager = try XCTUnwrap(manager)
        let mockPostProcessing = try XCTUnwrap(mockPostProcessing)
        let settings = AppSettingsStore.shared

        let originalPostProcessingEnabled = settings.postProcessingEnabled
        let originalSelectedPromptId = settings.selectedPromptId
        let originalDictationSelectedPromptId = settings.dictationSelectedPromptId
        let originalMeetingPrompts = settings.meetingPrompts
        let originalDictationPrompts = settings.dictationPrompts
        let originalMeetingSelection = settings.enhancementsAISelection
        let originalDictationSelection = settings.enhancementsDictationAISelection
        let originalProviderModels = settings.enhancementsProviderSelectedModels

        defer {
            settings.postProcessingEnabled = originalPostProcessingEnabled
            settings.selectedPromptId = originalSelectedPromptId
            settings.dictationSelectedPromptId = originalDictationSelectedPromptId
            settings.meetingPrompts = originalMeetingPrompts
            settings.dictationPrompts = originalDictationPrompts
            settings.enhancementsAISelection = originalMeetingSelection
            settings.enhancementsDictationAISelection = originalDictationSelection
            settings.enhancementsProviderSelectedModels = originalProviderModels
        }

        let meetingPrompt = PostProcessingPrompt(
            title: "Meeting Prompt",
            promptText: "meeting",
            isPredefined: false,
        )
        let dictationPrompt = PostProcessingPrompt(
            title: "Dictation Prompt",
            promptText: "dictation",
            isPredefined: false,
        )
        settings.meetingPrompts = [meetingPrompt]
        settings.dictationPrompts = [dictationPrompt]
        settings.selectedPromptId = meetingPrompt.id
        settings.dictationSelectedPromptId = dictationPrompt.id
        settings.updateEnhancementsSelection(provider: .openai, model: "gpt-5.4-mini", for: .meeting)
        settings.updateEnhancementsSelection(provider: .openai, model: "gpt-5.4-mini", for: .dictation)
        settings.postProcessingEnabled = true

        let meeting = Meeting(
            app: .importedFile,
            capturePurpose: .dictation,
            audioFilePath: "/tmp/imported-dictation.wav",
        )

        _ = await manager.applyPostProcessing(
            postProcessingInput: "raw dictation text",
            meeting: meeting,
            qualityProfile: nil,
            capturePurposeOverride: .dictation,
        )

        XCTAssertEqual(mockPostProcessing.lastPromptTitle, dictationPrompt.title)
    }

    func testTranscribeExternalAudio_DoesNotApplySilenceCompaction() async throws {
        let manager = try XCTUnwrap(manager)
        let mockTranscription = try XCTUnwrap(mockTranscription)
        let mockCompactor = try XCTUnwrap(mockAudioSilenceCompactor)
        let settings = AppSettingsStore.shared

        settings.removeSilenceBeforeProcessing = true

        let importedURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        try writeTestAudioFile(at: importedURL)
        defer { try? FileManager.default.removeItem(at: importedURL) }

        await manager.transcribeExternalAudio(from: importedURL)

        XCTAssertEqual(mockTranscription.lastTranscribeAudioURL, importedURL)
        XCTAssertEqual(mockCompactor.compactCallCount, 0)
    }

    func testTranscription_FailsWithInvalidURL() async throws {
        // Given
        let mockTranscription = try XCTUnwrap(mockTranscription)
        let invalidURL = URL(fileURLWithPath: "/nonexistent/path/file.m4a")
        mockTranscription.shouldFailTranscription = true

        // When/Then
        do {
            _ = try await mockTranscription.transcribe(audioURL: invalidURL)
            XCTFail("Expected error for transcription failure")
        } catch {
            // Should fail when shouldFailTranscription is true
            XCTAssertNotNil(error)
        }
    }

    func testTranscribeRecording_WhenFullFileTranscriptionFails_PersistsFailedHistoryItem() async throws {
        let manager = try XCTUnwrap(manager)
        let mockStorage = try XCTUnwrap(mockStorage)
        let mockTranscription = try XCTUnwrap(mockTranscription)
        mockTranscription.shouldFailTranscription = true

        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        try writeTestAudioFile(at: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let meetingID = UUID()
        let meeting = Meeting(
            id: meetingID,
            app: .unknown,
            capturePurpose: .dictation,
            startTime: Date(),
        )
        let session = RecordingManager.TranscriptionSessionSnapshot(
            id: meetingID,
            meeting: meeting,
            recordingSource: .microphone,
            kernelMode: .dictation,
            postProcessingContext: nil,
            postProcessingContextItems: [],
            meetingNotesContent: .empty,
            dictationSessionOutputLanguageOverride: nil,
            dictationStartBundleIdentifier: nil,
            dictationStartURL: nil,
        )

        await manager.transcribeRecording(audioURL: audioURL, session: session)

        let failed = try XCTUnwrap(mockStorage.savedTranscriptions.last)
        XCTAssertEqual(failed.lifecycleState, .failed)
        XCTAssertEqual(failed.meeting.id, meetingID)
        XCTAssertEqual(failed.capturePurpose, .dictation)
        XCTAssertEqual(failed.text, "")
        XCTAssertEqual(failed.rawText, "")
        XCTAssertEqual(failed.meeting.audioFilePath, audioURL.path)
        XCTAssertTrue(failed.postProcessingFailureReason?.contains("Transcription failed") == true)
    }

    func testMockStorageService_LoadTranscriptions() async throws {
        // Given
        let mockStorage = try XCTUnwrap(mockStorage)

        let mockTranscription = Transcription(
            meeting: Meeting(app: .unknown),
            text: "Test transcription",
            rawText: "Test transcription",
            processedContent: nil,
            postProcessingPromptId: nil,
            postProcessingPromptTitle: nil,
            language: "pt",
            modelName: "test-model",
        )
        mockStorage.mockTranscriptions = [mockTranscription]

        // When
        let transcriptions = try await mockStorage.loadTranscriptions()

        // Then
        XCTAssertEqual(transcriptions.count, 1)
        XCTAssertEqual(mockStorage.loadTranscriptionsCallCount, 1)
    }

    func testMockTranscriptionClient_CallTracking() async throws {
        // Given
        let mockTranscription = try XCTUnwrap(mockTranscription)
        let audioURL = URL(fileURLWithPath: "/tmp/test.m4a")

        // When
        _ = try await mockTranscription.transcribe(audioURL: audioURL)

        // Then
        XCTAssertEqual(mockTranscription.transcribeCallCount, 1)
        XCTAssertEqual(mockTranscription.lastTranscribeAudioURL, audioURL)
    }

    func testMockAudioRecorder_CallTracking() async throws {
        // Given
        let mockMic = try XCTUnwrap(mockMic)
        let audioURL = URL(fileURLWithPath: "/tmp/test.m4a")

        // When
        try await mockMic.startRecording(to: audioURL, retryCount: 0)
        _ = await mockMic.stopRecording()

        // Then
        XCTAssertEqual(mockMic.startRecordingParams.count, 1)
        XCTAssertEqual(mockMic.startRecordingParams.first?.url, audioURL)
        XCTAssertEqual(mockMic.stopRecordingCalledCount, 1)
    }

    private func writeTestAudioFile(at url: URL) throws {
        let format = AppSettingsStore.AudioFormat(rawValue: url.pathExtension.lowercased()) ?? .wav
        let sampleRate = 16_000.0
        let settings: [String: Any] = switch format {
        case .m4a:
            [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000,
            ]
        case .wav:
            [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: true,
            ]
        }

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )

        let file = try AVAudioFile(
            forWriting: url,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false,
        )
        let frameCount = AVAudioFrameCount(sampleRate * 0.2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
            XCTFail("Failed to allocate test audio buffer")
            return
        }

        buffer.frameLength = frameCount
        if let channelData = buffer.floatChannelData {
            for frameIndex in 0..<Int(frameCount) {
                let sample = Float(sin(2 * .pi * Double(frameIndex) / 40.0) * 0.2)
                channelData[0][frameIndex] = sample
            }
        }

        try file.write(from: buffer)
    }
}
