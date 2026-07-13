import Combine
import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import os.log

// MARK: - Transcription Client

/// Client for communicating with the local FluidAudio transcription service.
/// Adapts the local model manager to the existing client interface.
@MainActor
public class TranscriptionClient: ObservableObject, TranscriptionService, TranscriptionServiceDiarizationOverride, TranscriptionServicePurposeAware, TranscriptionServicePurposeDiarized, TranscriptionServiceFinalDiarization {
    public static let shared = TranscriptionClient()

    private let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "TranscriptionClient")
    private let settingsStore: AppSettingsStore
    private let groqTranscriptionClient: GroqTranscriptionClient
    private let elevenLabsTranscriptionClient: ElevenLabsTranscriptionClient

    /// Transient override for the transcription provider/model selection.
    /// When set, the next `transcribe` call uses this selection instead of resolving from settings.
    /// Automatically cleared after being consumed.
    public var selectionOverride: TranscriptionProviderSelection?

    public enum CachedReadinessState: String, Sendable {
        case unknown
        case healthy
        case unhealthy
    }

    /// The underlying transcription implementation based on feature flags.
    private enum TranscriptionImplementation {
        case xpc
        case local
    }

    private enum TranscriptionBackend {
        case xpc
        case local
        case groq(modelID: String)
        case elevenLabs(modelID: String)
    }

    private var transcriptionImplementation: TranscriptionImplementation {
        FeatureFlags.useXPCService ? .xpc : .local
    }

    @Published public private(set) var cachedReadinessState: CachedReadinessState = .unknown

    public var supportsIncrementalTranscription: Bool {
        transcriptionImplementation == .local
    }

    public func supportsIncrementalTranscription(for mode: TranscriptionExecutionMode) -> Bool {
        guard transcriptionImplementation == .local else { return false }
        return settingsStore.supportsIncrementalTranscription(for: mode)
    }

    private init(
        settingsStore: AppSettingsStore = .shared,
        groqTranscriptionClient: GroqTranscriptionClient = GroqTranscriptionClient(),
        elevenLabsTranscriptionClient: ElevenLabsTranscriptionClient = ElevenLabsTranscriptionClient(),
    ) {
        self.settingsStore = settingsStore
        self.groqTranscriptionClient = groqTranscriptionClient
        self.elevenLabsTranscriptionClient = elevenLabsTranscriptionClient
    }

    /// Check if the transcription service is healthy.
    public func healthCheck() async throws -> Bool {
        let isHealthy: Bool
        switch transcriptionImplementation {
        case .xpc:
            do {
                let status = try await MeetingAssistantAIClient.shared.fetchServiceStatus()
                isHealthy = status.status == "healthy"
            } catch {
                isHealthy = false
            }
        case .local:
            isHealthy = FluidAIModelManager.shared.modelState == .loaded
        }
        updateCachedReadiness(isHealthy ? .healthy : .unhealthy)
        return isHealthy
    }

    /// Fetch detailed service status.
    public func fetchServiceStatus() async throws -> ServiceStatusResponse {
        switch transcriptionImplementation {
        case .xpc:
            let xpcStatus = try await MeetingAssistantAIClient.shared.fetchServiceStatus()
            updateCachedReadiness(xpcStatus.status == "healthy" ? .healthy : .unhealthy)
            return ServiceStatusResponse(
                status: xpcStatus.status,
                modelState: xpcStatus.modelState,
                modelLoaded: xpcStatus.modelLoaded,
                device: xpcStatus.device,
                modelName: xpcStatus.modelName,
                uptimeSeconds: xpcStatus.uptimeSeconds,
                lastTranscriptionTime: nil,
                totalTranscriptions: 0,
                totalAudioProcessedSeconds: 0,
            )
        case .local:
            let state = FluidAIModelManager.shared.modelState
            let meetingModelID = settingsStore.resolvedTranscriptionSelection(for: .meeting).selectedModel
            updateCachedReadiness(state == .loaded ? .healthy : (state == .error ? .unhealthy : .unknown))
            return ServiceStatusResponse(
                status: state == .error ? "unhealthy" : "healthy",
                modelState: state.rawValue,
                modelLoaded: state == .loaded,
                device: "ANE",
                modelName: meetingModelID,
                uptimeSeconds: 0,
                lastTranscriptionTime: nil,
                totalTranscriptions: 0,
                totalAudioProcessedSeconds: 0,
            )
        }
    }

    /// Warm up the transcription model.
    public func warmupModel() async throws {
        guard settingsStore.isMeetingTranscriptionEnabled else {
            updateCachedReadiness(.unknown)
            AppLogger.debug(
                "Skipped model warmup because meeting transcription capability is disabled",
                category: .transcriptionEngine,
            )
            return
        }

        switch transcriptionImplementation {
        case .xpc:
            do {
                try await MeetingAssistantAIClient.shared.warmupModel()
                updateCachedReadiness(.healthy)
            } catch {
                updateCachedReadiness(.unhealthy)
                throw error
            }
        case .local:
            await FluidAIModelManager.shared.loadModels()
            let meetingSelection = settingsStore.resolvedTranscriptionSelection(for: .meeting)
            let supportsDiarization = settingsStore.localModelSupportsDiarization(modelID: meetingSelection.selectedModel)
            if FeatureFlags.enableDiarization,
               AppSettingsStore.shared.isDiarizationEnabled,
               supportsDiarization
            {
                await FluidAIModelManager.shared.loadDiarizationModels()
            }
            updateCachedReadiness(FluidAIModelManager.shared.modelState == .loaded ? .healthy : .unhealthy)
        }
    }

    /// Transcribe an audio file.
    public func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil,
    ) async throws -> TranscriptionResponse {
        try await transcribe(
            audioURL: audioURL,
            onProgress: onProgress,
            executionMode: .meeting,
            diarizationEnabledOverride: nil,
        )
    }

    public func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)?,
        capturePurpose: CapturePurpose,
    ) async throws -> TranscriptionResponse {
        try await transcribe(
            audioURL: audioURL,
            onProgress: onProgress,
            executionMode: executionMode(for: capturePurpose),
            diarizationEnabledOverride: nil,
        )
    }

    public func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)?,
        executionMode: TranscriptionExecutionMode,
    ) async throws -> TranscriptionResponse {
        try await transcribe(
            audioURL: audioURL,
            onProgress: onProgress,
            executionMode: executionMode,
            diarizationEnabledOverride: nil,
        )
    }

    public func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)?,
        diarizationEnabledOverride: Bool?,
    ) async throws -> TranscriptionResponse {
        try await transcribe(
            audioURL: audioURL,
            onProgress: onProgress,
            executionMode: .meeting,
            diarizationEnabledOverride: diarizationEnabledOverride,
        )
    }

    public func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)?,
        diarizationEnabledOverride: Bool?,
        capturePurpose: CapturePurpose,
    ) async throws -> TranscriptionResponse {
        try await transcribe(
            audioURL: audioURL,
            onProgress: onProgress,
            executionMode: executionMode(for: capturePurpose),
            diarizationEnabledOverride: diarizationEnabledOverride,
        )
    }

    public func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)?,
        executionMode: TranscriptionExecutionMode,
        diarizationEnabledOverride: Bool?,
    ) async throws -> TranscriptionResponse {
        let selection = selectionOverride ?? settingsStore.resolvedTranscriptionSelection(for: executionMode)
        selectionOverride = nil
        let inputLanguageCode = settingsStore.resolvedTranscriptionInputLanguageCode(for: executionMode)
        let backend = resolvedBackend(for: selection)
        let implementationLabel = switch backend {
        case .xpc:
            "XPC"
        case .local:
            "local"
        case .groq:
            "groq"
        case .elevenLabs:
            "elevenlabs"
        }

        AppLogger.info(
            "Transcribing file",
            category: .transcriptionEngine,
            extra: [
                "filename": audioURL.lastPathComponent,
                "implementation": implementationLabel,
                "mode": executionMode.rawValue,
            ],
        )

        switch backend {
        case .xpc:
            return try await transcribeViaXPC(
                audioURL: audioURL,
                onProgress: onProgress,
                diarizationEnabledOverride: diarizationEnabledOverride,
            )
        case .local:
            let effectiveDiarizationOverride = localDiarizationOverride(
                for: selection,
                requestedOverride: diarizationEnabledOverride,
            )
            return try await transcribeLocally(
                audioURL: audioURL,
                onProgress: onProgress,
                diarizationEnabledOverride: effectiveDiarizationOverride,
                modelID: selection.selectedModel,
                inputLanguageCode: inputLanguageCode,
            )
        case let .groq(modelID):
            return try await transcribeViaGroq(
                audioURL: audioURL,
                modelID: modelID,
                onProgress: onProgress,
                inputLanguageCode: inputLanguageCode,
            )
        case let .elevenLabs(modelID):
            return try await transcribeViaElevenLabs(
                audioURL: audioURL,
                modelID: modelID,
                onProgress: onProgress,
                inputLanguageCode: inputLanguageCode,
            )
        }
    }

    public func transcribe(samples: [Float]) async throws -> TranscriptionResponse {
        AppLogger.info(
            "Transcribing in-memory samples",
            category: .transcriptionEngine,
            extra: ["sampleCount": samples.count, "implementation": transcriptionImplementation == .xpc ? "XPC" : "local"],
        )

        guard supportsIncrementalTranscription else {
            updateCachedReadiness(.unhealthy)
            throw TranscriptionError.transcriptionFailed("Incremental transcription unsupported in current backend")
        }

        do {
            let inputLanguageCode = settingsStore.resolvedTranscriptionInputLanguageCode(for: .dictation)
            let response = try await LocalTranscriptionClient.shared.transcribe(
                samples: samples,
                inputLanguageHintCode: inputLanguageCode,
            )
            updateCachedReadiness(.healthy)
            return response
        } catch {
            updateCachedReadiness(.unhealthy)
            throw error
        }
    }

    public func diarize(audioURL: URL) async throws -> [SpeakerTimelineSegment] {
        guard transcriptionImplementation == .local else {
            throw TranscriptionError.transcriptionFailed("Final diarization unsupported in current backend")
        }

        do {
            let speakerTimeline = try await LocalTranscriptionClient.shared.diarize(audioURL: audioURL)
            updateCachedReadiness(.healthy)
            return speakerTimeline
        } catch {
            updateCachedReadiness(.unhealthy)
            throw error
        }
    }

    public func assignSpeakers(
        to segments: [Transcription.Segment],
        using speakerTimeline: [SpeakerTimelineSegment],
    ) -> [Transcription.Segment] {
        guard transcriptionImplementation == .local else { return segments }
        return LocalTranscriptionClient.shared.assignSpeakers(
            to: segments,
            using: speakerTimeline,
        )
    }

    public func warmupModelIfNeededInBackground() {
        guard FeatureFlags.enableCachedTranscriptionReadinessGate else { return }
        guard settingsStore.isMeetingTranscriptionEnabled else { return }
        guard cachedReadinessState != .healthy else { return }

        Task { @MainActor [weak self] in
            do {
                try await self?.warmupModel()
            } catch {
                self?.logger.error("Background warmup failed: \(error.localizedDescription)")
            }
        }
    }

    private func transcribeViaXPC(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)?,
        diarizationEnabledOverride: Bool?,
    ) async throws -> TranscriptionResponse {
        do {
            let response = try await MeetingAssistantAIClient.shared.transcribe(
                audioURL: audioURL,
                diarizationEnabledOverride: diarizationEnabledOverride,
            )
            updateCachedReadiness(.healthy)
            AppLogger.info(
                "Transcription completed via XPC",
                category: .transcriptionEngine,
                extra: ["words": response.text.split(separator: " ").count],
            )
            return response
        } catch {
            updateCachedReadiness(.unhealthy)
            AppLogger.error(
                "Transcription failed via XPC",
                category: .transcriptionEngine,
                error: error,
                extra: ["filename": audioURL.lastPathComponent],
            )
            throw error
        }
    }

    private func transcribeLocally(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)?,
        diarizationEnabledOverride: Bool?,
        modelID: String,
        inputLanguageCode: String?,
    ) async throws -> TranscriptionResponse {
        do {
            let response = try await LocalTranscriptionClient.shared.transcribe(
                audioURL: audioURL,
                isDiarizationEnabled: diarizationEnabledOverride,
                modelID: modelID,
                inputLanguageHintCode: inputLanguageCode,
                onProgress: onProgress,
            )
            updateCachedReadiness(.healthy)
            AppLogger.info(
                "Transcription completed locally",
                category: .transcriptionEngine,
                extra: ["words": response.text.split(separator: " ").count],
            )
            return response
        } catch {
            updateCachedReadiness(.unhealthy)
            AppLogger.error(
                "Transcription failed locally",
                category: .transcriptionEngine,
                error: error,
                extra: ["filename": audioURL.lastPathComponent],
            )
            throw error
        }
    }

    private func transcribeViaGroq(
        audioURL: URL,
        modelID: String,
        onProgress: (@Sendable (Double) -> Void)?,
        inputLanguageCode: String?,
    ) async throws -> TranscriptionResponse {
        do {
            let response = try await groqTranscriptionClient.transcribe(
                audioURL: audioURL,
                modelID: modelID,
                inputLanguageCode: inputLanguageCode,
                onProgress: onProgress,
            )
            updateCachedReadiness(.healthy)
            AppLogger.info(
                "Transcription completed via Groq",
                category: .transcriptionEngine,
                extra: ["words": response.text.split(separator: " ").count, "model": response.model],
            )
            return response
        } catch {
            updateCachedReadiness(.unhealthy)
            AppLogger.error(
                "Transcription failed via Groq",
                category: .transcriptionEngine,
                error: error,
                extra: ["filename": audioURL.lastPathComponent, "model": modelID],
            )
            throw error
        }
    }

    private func transcribeViaElevenLabs(
        audioURL: URL,
        modelID: String,
        onProgress: (@Sendable (Double) -> Void)?,
        inputLanguageCode: String?,
    ) async throws -> TranscriptionResponse {
        do {
            let response = try await elevenLabsTranscriptionClient.transcribe(
                audioURL: audioURL,
                modelID: modelID,
                inputLanguageCode: inputLanguageCode,
                onProgress: onProgress,
            )
            updateCachedReadiness(.healthy)
            AppLogger.info(
                "Transcription completed via ElevenLabs",
                category: .transcriptionEngine,
                extra: ["words": response.text.split(separator: " ").count, "model": response.model],
            )
            return response
        } catch {
            updateCachedReadiness(.unhealthy)
            AppLogger.error(
                "Transcription failed via ElevenLabs",
                category: .transcriptionEngine,
                error: error,
                extra: ["filename": audioURL.lastPathComponent, "model": modelID],
            )
            throw error
        }
    }

    private func executionMode(for capturePurpose: CapturePurpose) -> TranscriptionExecutionMode {
        switch capturePurpose {
        case .meeting:
            .meeting
        case .dictation:
            .dictation
        }
    }

    private func resolvedBackend(for selection: TranscriptionProviderSelection) -> TranscriptionBackend {
        switch selection.provider {
        case .local:
            transcriptionImplementation == .xpc ? .xpc : .local
        case .groq:
            .groq(modelID: selection.selectedModel)
        case .elevenLabs:
            .elevenLabs(modelID: selection.selectedModel)
        }
    }

    private func localDiarizationOverride(
        for selection: TranscriptionProviderSelection,
        requestedOverride: Bool?,
    ) -> Bool? {
        guard selection.provider == .local else { return requestedOverride }
        guard !settingsStore.localModelSupportsDiarization(modelID: selection.selectedModel) else {
            return requestedOverride
        }

        if requestedOverride != false {
            AppLogger.info(
                "Diarization auto-disabled for selected local transcription model",
                category: .transcriptionEngine,
                extra: ["model": selection.selectedModel],
            )
        }
        return false
    }

    private func updateCachedReadiness(_ state: CachedReadinessState) {
        guard FeatureFlags.enableCachedTranscriptionReadinessGate else { return }
        cachedReadinessState = state
    }

    deinit {
        AppLogger.debug("TranscriptionClient deinitialized", category: .transcriptionEngine)
    }
}
