import Foundation
@testable import MeetingAssistantCoreAI
@testable import MeetingAssistantCoreInfrastructure
import XCTest

@MainActor
final class LocalAICacheMaintenanceServiceTests: XCTestCase {
    func testComputeCleanupPreview_WhenCompiledModelIsActive_ExcludesActiveCompiledDirectory() async throws {
        let rootDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let modelDirectory = rootDirectory.appendingPathComponent("Models", isDirectory: true)
        let sourceDirectory = modelDirectory.appendingPathComponent("cohere_encoder.mlpackage", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try Data("encoder".utf8).write(to: sourceDirectory.appendingPathComponent("weights.bin"))

        let activeCompiledDirectory = try CohereTranscribeModelRuntime.compiledModelDirectory(
            for: .encoder,
            artifactURL: sourceDirectory,
            modelDirectory: modelDirectory,
        )
        try FileManager.default.createDirectory(at: activeCompiledDirectory, withIntermediateDirectories: true)
        try Data("compiled".utf8).write(to: activeCompiledDirectory.appendingPathComponent("model.bin"))

        let staleCompiledDirectory = activeCompiledDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("STALE.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: staleCompiledDirectory, withIntermediateDirectories: true)
        try Data("stale".utf8).write(to: staleCompiledDirectory.appendingPathComponent("model.bin"))
        try setModificationDate(daysAgo: 60, for: staleCompiledDirectory)

        let runtimeState = MockLocalAICacheRuntimeState(
            loadedASRLocalModelID: LocalTranscriptionModel.cohereTranscribe032026CoreML6Bit.rawValue,
            modelState: .loaded,
            isASRInUse: false,
            isASRResidentInMemory: true,
        )
        let service = LocalAICacheMaintenanceService(
            runtimeState: runtimeState,
            fileManager: .default,
            cohereModelDirectoryProvider: { modelDirectory },
            appleRuntimeCacheDirectoryProvider: { rootDirectory.appendingPathComponent("AppleCache", isDirectory: true) },
        )

        let preview = try await service.computeCleanupPreview(olderThanDays: 30)

        XCTAssertEqual(preview.compiledModelCount, 1)
        XCTAssertEqual(preview.candidates.first?.url.standardizedFileURL, staleCompiledDirectory.standardizedFileURL)
    }

    func testComputeCleanupPreview_WhenRuntimeActive_ExcludesAppleRuntimeCache() async throws {
        let rootDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let appleCacheRoot = rootDirectory.appendingPathComponent("AppleCache", isDirectory: true)
        let bucketDirectory = appleCacheRoot.appendingPathComponent("25E246", isDirectory: true)
        let runtimeDirectory = bucketDirectory.appendingPathComponent("CACHE-A", isDirectory: true)
        try FileManager.default.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true)
        try Data("runtime".utf8).write(to: runtimeDirectory.appendingPathComponent("payload.bin"))
        try setModificationDate(daysAgo: 60, for: runtimeDirectory)

        let runtimeState = MockLocalAICacheRuntimeState(
            loadedASRLocalModelID: LocalTranscriptionModel.cohereTranscribe032026CoreML6Bit.rawValue,
            modelState: .loaded,
            isASRInUse: false,
            isASRResidentInMemory: true,
        )
        let service = LocalAICacheMaintenanceService(
            runtimeState: runtimeState,
            fileManager: .default,
            cohereModelDirectoryProvider: { rootDirectory.appendingPathComponent("Models", isDirectory: true) },
            appleRuntimeCacheDirectoryProvider: { appleCacheRoot },
        )

        let preview = try await service.computeCleanupPreview(olderThanDays: 30)

        XCTAssertEqual(preview.appleRuntimeCount, 0)
    }

    func testPerformCleanup_WhenCandidateEligible_RemovesCacheDirectory() async throws {
        let rootDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let appleCacheRoot = rootDirectory.appendingPathComponent("AppleCache", isDirectory: true)
        let bucketDirectory = appleCacheRoot.appendingPathComponent("25E246", isDirectory: true)
        let runtimeDirectory = bucketDirectory.appendingPathComponent("CACHE-A", isDirectory: true)
        try FileManager.default.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true)
        try Data(repeating: 0xab, count: 32).write(to: runtimeDirectory.appendingPathComponent("payload.bin"))
        try setModificationDate(daysAgo: 60, for: runtimeDirectory)

        let runtimeState = MockLocalAICacheRuntimeState()
        let service = LocalAICacheMaintenanceService(
            runtimeState: runtimeState,
            fileManager: .default,
            cohereModelDirectoryProvider: { rootDirectory.appendingPathComponent("Models", isDirectory: true) },
            appleRuntimeCacheDirectoryProvider: { appleCacheRoot },
        )

        let preview = try await service.computeCleanupPreview(olderThanDays: 30)
        let result = try await service.performCleanup(preview: preview)

        XCTAssertEqual(result.deletedAppleRuntimeCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: runtimeDirectory.path))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalAICacheMaintenanceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func setModificationDate(daysAgo: Int, for url: URL) throws {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date.distantPast
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }
}

@MainActor
private final class MockLocalAICacheRuntimeState: LocalAICacheRuntimeStateProviding {
    var loadedASRLocalModelID: String?
    var modelState: FluidAIModelManager.ModelState
    var isASRInUse: Bool
    var isASRResidentInMemory: Bool

    init(
        loadedASRLocalModelID: String? = nil,
        modelState: FluidAIModelManager.ModelState = .unloaded,
        isASRInUse: Bool = false,
        isASRResidentInMemory: Bool = false,
    ) {
        self.loadedASRLocalModelID = loadedASRLocalModelID
        self.modelState = modelState
        self.isASRInUse = isASRInUse
        self.isASRResidentInMemory = isASRResidentInMemory
    }
}
