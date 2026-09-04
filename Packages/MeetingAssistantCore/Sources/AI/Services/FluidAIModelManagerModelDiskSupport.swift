@preconcurrency import FluidAudio
import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import os.log

extension FluidAIModelManager {
    func hasASRModelsOnDisk() -> Bool {
        LocalTranscriptionModel.allCases.contains { model in
            isASRModelInstalled(localModelID: model.rawValue)
        }
    }

    public func isASRModelInstalled(localModelID: String) -> Bool {
        guard let model = LocalTranscriptionModel(rawValue: localModelID) else { return false }
        let runtime = LocalASRModelRuntimeRegistry.runtime(for: model)
        return runtime.isInstalled()
    }

    func resolveLocalModel(from rawValue: String) -> LocalTranscriptionModel {
        LocalTranscriptionModel(rawValue: rawValue) ?? .parakeetTdt06BV3
    }

    func loadASRModels(for model: LocalTranscriptionModel) async throws -> AsrModels {
        let runtime = LocalASRModelRuntimeRegistry.runtime(for: model)
        return try await runtime.downloadAndLoad()
    }

    func asrModelDirectory(for model: LocalTranscriptionModel) -> URL {
        switch model {
        case .parakeetTdt06BV3:
            AsrModels.defaultCacheDirectory(for: .v3)
        }
    }

    func removeASRModelFromDisk(_ model: LocalTranscriptionModel) throws {
        let fileManager = FileManager.default
        let targetDirectory = asrModelDirectory(for: model)

        if fileManager.fileExists(atPath: targetDirectory.path) {
            try fileManager.removeItem(at: targetDirectory)
        }
    }

    func hasDiarizationModelsOnDisk() -> Bool {
        let fallbackLogger = Logger(subsystem: AppIdentity.logSubsystem, category: "FluidAIModelManager")
        let fileManager = FileManager.default
        guard let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return false
        }

        let modelsDir = supportDir.appendingPathComponent("FluidAudio/Models")
        guard fileManager.fileExists(atPath: modelsDir.path) else {
            return false
        }

        do {
            let contents = try fileManager.contentsOfDirectory(at: modelsDir, includingPropertiesForKeys: nil)
            return contents.contains { url in
                let name = url.lastPathComponent.lowercased()
                return name.contains("pyannote") || name.contains("segmentation")
            }
        } catch {
            fallbackLogger.error("Failed to inspect Diarization model directory: \(error.localizedDescription)")
            return false
        }
    }
}
