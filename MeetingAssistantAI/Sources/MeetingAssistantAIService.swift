import Foundation
import MeetingAssistantCore
import os.log

/// Implementation of the MeetingAssistant XPC Service.
final class MeetingAssistantAIService: NSObject, MeetingAssistantXPCProtocol {

    private static let logger = Logger(subsystem: AppIdentity.xpcServiceName, category: "AIService")

    func transcribe(
        audioURL: URL,
        settingsData: Data,
        withReply reply: @escaping @Sendable (Data?, Error?) -> Void,
    ) {
        MeetingAssistantAIService.logger.info("XPC Request: Transcribe \(audioURL.lastPathComponent)")

        Task { @MainActor in
            do {
                let decoder = JSONDecoder()
                let settings = try decoder.decode(MeetingAssistantXPCModels.AppSettings.self, from: settingsData)
                let providerID = settings.providerID ?? TranscriptionProvider.local.rawValue
                guard providerID == TranscriptionProvider.local.rawValue else {
                    throw TranscriptionError.transcriptionFailed("XPC transcription supports only the local provider")
                }
                let modelID = settings.modelID ?? LocalTranscriptionModel.parakeetTdt06BV3.rawValue
                guard LocalTranscriptionModel(rawValue: modelID) != nil else {
                    throw TranscriptionError.transcriptionFailed("Unsupported local transcription model")
                }

                let result = try await LocalTranscriptionClient.shared.transcribe(
                    audioURL: audioURL,
                    isDiarizationEnabled: settings.diarization,
                    modelID: modelID,
                    inputLanguageHintCode: settings.inputLanguageCode,
                    minSpeakers: settings.minSpeakers,
                    maxSpeakers: settings.maxSpeakers,
                    numSpeakers: settings.numSpeakers,
                    useSettingsLanguageFallback: !settings.hasExplicitTranscriptionRequest,
                    useSettingsDiarizationFallback: false,
                )

                let encoder = JSONEncoder()
                let data = try encoder.encode(result)
                reply(data, nil)

            } catch {
                MeetingAssistantAIService.logger.error("XPC Transcription failed: \(error.localizedDescription)")
                reply(nil, error)
            }
        }
    }

    func fetchServiceStatus(withReply reply: @escaping @Sendable (Data?, Error?) -> Void) {
        Task { @MainActor in
            do {
                MeetingAssistantAIService.logger.info("Fetching service status...")
                let currentState = FluidAIModelManager.shared.modelState
                MeetingAssistantAIService.logger.info("Model state: \(currentState.rawValue)")

                let status = MeetingAssistantXPCModels.ServiceStatus(
                    status: currentState == .error ? "unhealthy" : "healthy",
                    modelState: currentState.rawValue,
                    modelLoaded: currentState == .loaded,
                    device: "ANE",
                    modelName: "parakeet-tdt-0.6b-v3",
                    uptimeSeconds: 0,
                )

                let encoder = JSONEncoder()
                let data = try encoder.encode(status)
                MeetingAssistantAIService.logger.info("Sending status response")
                reply(data, nil)
            } catch {
                MeetingAssistantAIService.logger.error("Failed to fetch status: \(error.localizedDescription)")
                reply(nil, error)
            }
        }
    }

    func warmupModel(withReply reply: @escaping @Sendable (Error?) -> Void) {
        Task { @MainActor in
            await FluidAIModelManager.shared.loadModels()
            if FeatureFlags.enableDiarization, AppSettingsStore.shared.isDiarizationEnabled {
                await FluidAIModelManager.shared.loadDiarizationModels()
            }
            reply(nil)
        }
    }
}
