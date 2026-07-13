import Foundation
@testable import MeetingAssistantCoreAI
@testable import MeetingAssistantCoreInfrastructure
import XCTest

final class CohereTranscribeModelRuntimeTests: XCTestCase {
    func testParseVocabularyData_WhenCoreMLManifestContainsIDToToken_ReturnsIndexedVocabulary() throws {
        let payload: [String: Any] = [
            "model_id": "CohereLabs/cohere-transcribe-03-2026",
            "id_to_token": ["<unk>", "hello", "world"],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)

        let vocabulary = try CohereTranscribeModelRuntime.parseVocabularyData(
            data,
            sourceName: "coreml_manifest.json",
        )

        XCTAssertEqual(vocabulary[0], "<unk>")
        XCTAssertEqual(vocabulary[1], "hello")
        XCTAssertEqual(vocabulary[2], "world")
        XCTAssertEqual(vocabulary.count, 3)
    }

    func testParseVocabularyData_WhenNumericDictionaryFormat_ReturnsMappedVocabulary() throws {
        let payload = [
            "0": "<unk>",
            "1": "ola",
        ]
        let data = try JSONEncoder().encode(payload)

        let vocabulary = try CohereTranscribeModelRuntime.parseVocabularyData(
            data,
            sourceName: "vocab.json",
        )

        XCTAssertEqual(vocabulary[0], "<unk>")
        XCTAssertEqual(vocabulary[1], "ola")
        XCTAssertEqual(vocabulary.count, 2)
    }

    func testModelsExist_WhenPublicCohereArtifactsAndManifestExist_ReturnsTrue() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        for folder in [
            "cohere_frontend.mlpackage",
            "cohere_encoder.mlpackage",
            "cohere_decoder_cached.mlpackage",
            "cohere_cross_kv_projector.mlpackage",
        ] {
            let folderURL = directory.appendingPathComponent(folder, isDirectory: true)
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        let manifestURL = directory.appendingPathComponent("coreml_manifest.json")
        let manifestPayload: [String: Any] = ["id_to_token": ["<unk>", "hi"]]
        let manifestData = try JSONSerialization.data(withJSONObject: manifestPayload)
        try manifestData.write(to: manifestURL)

        XCTAssertTrue(CohereTranscribeModelRuntime.modelsExist(at: directory))
    }

    func testModelsExist_WhenJointArtifactIsMissing_ReturnsFalse() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        for folder in [
            "cohere_frontend.mlpackage",
            "cohere_encoder.mlpackage",
            "cohere_decoder_cached.mlpackage",
        ] {
            let folderURL = directory.appendingPathComponent(folder, isDirectory: true)
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        let manifestURL = directory.appendingPathComponent("coreml_manifest.json")
        let manifestPayload: [String: Any] = ["id_to_token": ["<unk>", "hi"]]
        let manifestData = try JSONSerialization.data(withJSONObject: manifestPayload)
        try manifestData.write(to: manifestURL)

        XCTAssertFalse(CohereTranscribeModelRuntime.modelsExist(at: directory))
    }

    func testCompiledModelDirectory_WhenSourceContentsChange_ProducesDifferentFingerprint() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let encoderURL = directory.appendingPathComponent("cohere_encoder.mlpackage", isDirectory: true)
        try FileManager.default.createDirectory(at: encoderURL, withIntermediateDirectories: true)
        let weightsURL = encoderURL.appendingPathComponent("weights.bin")
        try Data("v1".utf8).write(to: weightsURL)

        let firstCompiledURL = try CohereTranscribeModelRuntime.compiledModelDirectory(
            for: .encoder,
            artifactURL: encoderURL,
            modelDirectory: directory,
        )

        try Data("v2".utf8).write(to: weightsURL)

        let secondCompiledURL = try CohereTranscribeModelRuntime.compiledModelDirectory(
            for: .encoder,
            artifactURL: encoderURL,
            modelDirectory: directory,
        )

        XCTAssertNotEqual(firstCompiledURL, secondCompiledURL)
    }

    func testPersistedCompiledModelDirectories_WhenArtifactsExist_ReturnsAllCompiledDirectories() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let compiledRoot = CohereTranscribeModelRuntime.compiledArtifactsRootDirectory(baseDirectory: directory)
        let encoderCompiled = compiledRoot.appendingPathComponent("encoder/ENCODER.mlmodelc", isDirectory: true)
        let decoderCompiled = compiledRoot.appendingPathComponent("decoder/DECODER.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: encoderCompiled, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: decoderCompiled, withIntermediateDirectories: true)

        let directories = CohereTranscribeModelRuntime.persistedCompiledModelDirectories(at: directory)

        XCTAssertEqual(Set(directories.map(\.standardizedFileURL)), Set([encoderCompiled.standardizedFileURL, decoderCompiled.standardizedFileURL]))
    }

    @MainActor
    func testCohereLoadIntegration_WhenEnabled_LoadsModelManagerSuccessfully() async throws {
        guard ProcessInfo.processInfo.environment["PRISMA_ENABLE_COHERE_RUNTIME_INTEGRATION_TEST"] == "1" else {
            throw XCTSkip("Set PRISMA_ENABLE_COHERE_RUNTIME_INTEGRATION_TEST=1 to enable this runtime integration test.")
        }

        let manager = FluidAIModelManager.shared
        await manager.loadModels(for: LocalTranscriptionModel.cohereTranscribe032026CoreML6Bit.rawValue)

        XCTAssertEqual(
            manager.modelState,
            .loaded,
            "Expected Cohere model to load successfully. Current state: \(manager.modelState.rawValue), lastError: \(manager.lastError ?? "nil")",
        )
        XCTAssertEqual(
            manager.loadedASRLocalModelID,
            LocalTranscriptionModel.cohereTranscribe032026CoreML6Bit.rawValue,
            "Loaded model ID did not match Cohere selection.",
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CohereRuntimeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
