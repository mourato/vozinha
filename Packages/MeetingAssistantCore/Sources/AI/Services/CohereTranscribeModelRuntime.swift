@preconcurrency import CoreML
@preconcurrency import FluidAudio
import CryptoKit
import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import os.log

enum CohereTranscribeModelRuntime {
    private static let logger = Logger(
        subsystem: AppIdentity.logSubsystem,
        category: "CohereTranscribeModelRuntime"
    )

    /// Try the public FluidVoice-compatible source first, then fallback to the
    /// private FluidInference mirror for environments that have credentials.
    private static let remoteRepoCandidates = [
        "BarathwajAnandan/cohere-transcribe-03-2026-CoreML-6bit",
        "FluidInference/cohere-transcribe-03-2026-coreml-6bit",
    ]

    enum ModelComponent: String, CaseIterable {
        case preprocessor
        case encoder
        case decoder
        case joint

        var displayName: String {
            switch self {
            case .preprocessor:
                "Preprocessor"
            case .encoder:
                "Encoder"
            case .decoder:
                "Decoder"
            case .joint:
                "Joint"
            }
        }

        var artifactCandidates: [String] {
            switch self {
            case .preprocessor:
                [
                    ModelNames.ASR.preprocessorFile,
                    "cohere_frontend.mlmodelc",
                    "cohere_frontend.mlpackage",
                ]
            case .encoder:
                [
                    ModelNames.ASR.encoderFile,
                    "cohere_encoder.mlmodelc",
                    "cohere_encoder.mlpackage",
                ]
            case .decoder:
                [
                    ModelNames.ASR.decoderFile,
                    "cohere_decoder_cached.mlmodelc",
                    "cohere_decoder_cached.mlpackage",
                    "cohere_decoder_stateful.mlmodelc",
                    "cohere_decoder_stateful.mlpackage",
                ]
            case .joint:
                [
                    ModelNames.ASR.jointFile,
                    "cohere_cross_kv_projector.mlmodelc",
                    "cohere_cross_kv_projector.mlpackage",
                    "cohere_decoder_fullseq_masked.mlmodelc",
                    "cohere_decoder_fullseq_masked.mlpackage",
                ]
            }
        }
    }

    private static let requiredModelArtifactCandidates = ModelComponent.allCases.flatMap(\.artifactCandidates)

    private static let tokenVocabularyCandidates = [
        ModelNames.ASR.vocabularyFile,
        "vocab.json",
        "cohere_vocab.json",
        "coreml_manifest.json",
    ]

    enum RuntimeError: LocalizedError {
        case missingRequiredArtifacts([String])
        case tokenVocabularyNotFound
        case tokenVocabularyUnreadable(String)

        var errorDescription: String? {
            switch self {
            case let .missingRequiredArtifacts(missing):
                "Missing required Cohere model artifacts: \(missing.joined(separator: ", "))."
            case .tokenVocabularyNotFound:
                "Could not find a vocabulary file for the Cohere local model."
            case let .tokenVocabularyUnreadable(reason):
                "Unable to parse Cohere vocabulary: \(reason)"
            }
        }
    }

    static func defaultCacheDirectory() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        return appSupport
            .appendingPathComponent("FluidAudio", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(
                LocalTranscriptionModel.cohereTranscribe032026CoreML6Bit.rawValue,
                isDirectory: true
            )
    }

    static func modelsExist(at directory: URL = defaultCacheDirectory()) -> Bool {
        missingComponents(under: directory).isEmpty
            && (try? findVocabularyFile(under: directory)) != nil
    }

    static func downloadIfNeeded(force: Bool = false) async throws -> URL {
        let targetDirectory = defaultCacheDirectory()
        let fileManager = FileManager.default

        if !force, modelsExist(at: targetDirectory) {
            logger.info("Cohere local model already available at \(targetDirectory.path, privacy: .public)")
            return targetDirectory
        }

        if force, fileManager.fileExists(atPath: targetDirectory.path) {
            try fileManager.removeItem(at: targetDirectory)
        }

        var lastError: Error?

        for repoPath in remoteRepoCandidates {
            do {
                if fileManager.fileExists(atPath: targetDirectory.path) {
                    try fileManager.removeItem(at: targetDirectory)
                }
                try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

                logger.info("Downloading Cohere local model artifacts from Hugging Face repo: \(repoPath, privacy: .public)")
                let files = try await HuggingFaceRepositoryDownloader.listFilesRecursively(repoPath: repoPath)
                let filteredFiles = files.filter { shouldDownload(path: $0.path) }

                if filteredFiles.isEmpty {
                    throw RuntimeError.missingRequiredArtifacts(requiredModelArtifactCandidates + tokenVocabularyCandidates)
                }

                try await HuggingFaceRepositoryDownloader.downloadFiles(
                    repoPath: repoPath,
                    files: filteredFiles,
                    to: targetDirectory
                )

                let missing = missingComponents(under: targetDirectory)
                if !missing.isEmpty {
                    throw RuntimeError.missingRequiredArtifacts(missing)
                }

                if (try? findVocabularyFile(under: targetDirectory)) == nil {
                    throw RuntimeError.tokenVocabularyNotFound
                }

                logger.info("Finished Cohere local model download from repo: \(repoPath, privacy: .public)")
                return targetDirectory
            } catch {
                lastError = error
                logger.error("Cohere download attempt failed for repo \(repoPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        if fileManager.fileExists(atPath: targetDirectory.path) {
            try? fileManager.removeItem(at: targetDirectory)
        }

        throw lastError ?? RuntimeError.missingRequiredArtifacts(requiredModelArtifactCandidates + tokenVocabularyCandidates)
    }

    static func downloadAndLoad(configuration: MLModelConfiguration? = nil) async throws -> AsrModels {
        let targetDirectory = try await downloadIfNeeded()
        return try load(from: targetDirectory, configuration: configuration)
    }

    static func load(from directory: URL, configuration: MLModelConfiguration? = nil) throws -> AsrModels {
        let config: MLModelConfiguration
        if let configuration {
            config = configuration
        } else {
            let defaultConfiguration = AsrModels.defaultConfiguration()
            // Cohere public CoreML packages are frequently distributed as
            // portable .mlpackage exports; forcing ANE at first load can
            // trigger long plan-build stalls. Default to CPU+GPU for stability.
            defaultConfiguration.computeUnits = .cpuAndGPU
            config = defaultConfiguration
        }

        let preprocessorURL = try findDirectory(
            matchingAnyOf: ModelComponent.preprocessor.artifactCandidates,
            under: directory
        )
        let encoderURL = try findDirectory(
            matchingAnyOf: ModelComponent.encoder.artifactCandidates,
            under: directory
        )
        let decoderURL = try findDirectory(
            matchingAnyOf: ModelComponent.decoder.artifactCandidates,
            under: directory
        )
        let jointURL = try findDirectory(
            matchingAnyOf: ModelComponent.joint.artifactCandidates,
            under: directory
        )
        let tokenVocabularyURL = try findVocabularyFile(under: directory)

        let preprocessorConfig = MLModelConfiguration()
        preprocessorConfig.allowLowPrecisionAccumulationOnGPU = true
        preprocessorConfig.computeUnits = .cpuOnly

        let encoderModel = try loadModel(
            component: .encoder,
            from: encoderURL,
            modelDirectory: directory,
            configuration: config
        )
        let preprocessorModel = try loadModel(
            component: .preprocessor,
            from: preprocessorURL,
            modelDirectory: directory,
            configuration: preprocessorConfig
        )
        let decoderModel = try loadModel(
            component: .decoder,
            from: decoderURL,
            modelDirectory: directory,
            configuration: config
        )
        let jointModel = try loadModel(
            component: .joint,
            from: jointURL,
            modelDirectory: directory,
            configuration: config
        )

        let modelVocabulary = try loadTokenVocabulary(from: tokenVocabularyURL)

        return AsrModels(
            encoder: encoderModel,
            preprocessor: preprocessorModel,
            decoder: decoderModel,
            joint: jointModel,
            configuration: config,
            vocabulary: modelVocabulary,
            version: .v3
        )
    }

    private static func loadModel(
        component: ModelComponent,
        from artifactURL: URL,
        modelDirectory: URL,
        configuration: MLModelConfiguration
    ) throws -> MLModel {
        // Public Cohere repos commonly ship .mlpackage artifacts. Compile them
        // on-device before loading to avoid "not a valid .mlmodelc" runtime failures.
        if artifactURL.pathExtension == "mlpackage" {
            let compiledURL = try resolveCompiledModelURL(
                for: component,
                artifactURL: artifactURL,
                modelDirectory: modelDirectory
            )

            do {
                return try MLModel(contentsOf: compiledURL, configuration: configuration)
            } catch {
                reportCompiledModelEvent(
                    name: "recompile_after_load_failure",
                    component: component,
                    artifactURL: artifactURL,
                    compiledURL: compiledURL,
                    extra: ["failure": error.localizedDescription]
                )
                let fileManager = FileManager.default
                try? fileManager.removeItem(at: compiledURL)
                let rebuiltURL = try buildCompiledModelURL(
                    for: component,
                    artifactURL: artifactURL,
                    modelDirectory: modelDirectory,
                    destinationURL: compiledURL,
                    fileManager: fileManager
                )
                return try MLModel(contentsOf: rebuiltURL, configuration: configuration)
            }
        }

        return try MLModel(contentsOf: artifactURL, configuration: configuration)
    }

    static func compiledArtifactsRootDirectory(baseDirectory: URL = defaultCacheDirectory()) -> URL {
        baseDirectory.appendingPathComponent("Compiled", isDirectory: true)
    }

    static func currentCompiledArtifactDirectories(at modelDirectory: URL = defaultCacheDirectory()) throws -> [URL] {
        ModelComponent.allCases.compactMap { component in
            guard let artifactURL = try? findDirectory(matchingAnyOf: component.artifactCandidates, under: modelDirectory) else {
                return nil
            }
            guard artifactURL.pathExtension == "mlpackage" else { return nil }
            return try? compiledModelDirectory(for: component, artifactURL: artifactURL, modelDirectory: modelDirectory)
        }
    }

    static func persistedCompiledModelDirectories(
        at modelDirectory: URL = defaultCacheDirectory(),
        fileManager: FileManager = .default
    ) -> [URL] {
        let rootDirectory = compiledArtifactsRootDirectory(baseDirectory: modelDirectory)
        guard fileManager.fileExists(atPath: rootDirectory.path) else { return [] }

        let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
        let componentDirectories = (try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )) ?? []

        return componentDirectories.flatMap { componentDirectory in
            ((try? fileManager.contentsOfDirectory(
                at: componentDirectory,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )) ?? []).filter { candidate in
                let values = try? candidate.resourceValues(forKeys: Set(resourceKeys))
                return values?.isDirectory == true && candidate.pathExtension == "mlmodelc"
            }
        }
    }

    static func compiledModelDirectory(
        for component: ModelComponent,
        artifactURL: URL,
        modelDirectory: URL = defaultCacheDirectory()
    ) throws -> URL {
        let fingerprint = try modelArtifactFingerprint(for: artifactURL)
        return compiledArtifactsRootDirectory(baseDirectory: modelDirectory)
            .appendingPathComponent(component.rawValue, isDirectory: true)
            .appendingPathComponent("\(fingerprint).mlmodelc", isDirectory: true)
    }

    static func pruneCompiledModelCache(
        for component: ModelComponent,
        keeping keepDirectory: URL,
        in modelDirectory: URL = defaultCacheDirectory(),
        fileManager: FileManager = .default
    ) {
        let componentDirectory = compiledArtifactsRootDirectory(baseDirectory: modelDirectory)
            .appendingPathComponent(component.rawValue, isDirectory: true)
        guard fileManager.fileExists(atPath: componentDirectory.path) else { return }

        let entries = (try? fileManager.contentsOfDirectory(
            at: componentDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for entry in entries where entry.standardizedFileURL != keepDirectory.standardizedFileURL {
            try? fileManager.removeItem(at: entry)
        }
    }

    private static func shouldDownload(path: String) -> Bool {
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        if tokenVocabularyCandidates.contains(fileName) {
            return true
        }

        return requiredModelArtifactCandidates.contains { directoryName in
            path.contains("/\(directoryName)/") || path.hasPrefix("\(directoryName)/")
        }
    }

    private static func missingComponents(under rootDirectory: URL) -> [String] {
        ModelComponent.allCases.compactMap { component in
            let exists = (try? findDirectory(matchingAnyOf: component.artifactCandidates, under: rootDirectory)) != nil
            return exists ? nil : component.displayName
        }
    }

    private static func findDirectory(matchingAnyOf targetNames: [String], under rootDirectory: URL) throws -> URL {
        for targetName in targetNames {
            if let found = try? findDirectory(named: targetName, under: rootDirectory) {
                return found
            }
        }

        throw RuntimeError.missingRequiredArtifacts(targetNames)
    }

    private static func findDirectory(named targetName: String, under rootDirectory: URL) throws -> URL {
        let keys: [URLResourceKey] = [.isDirectoryKey]
        guard
            let enumerator = FileManager.default.enumerator(
                at: rootDirectory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )
        else {
            throw RuntimeError.missingRequiredArtifacts([targetName])
        }

        for case let candidateURL as URL in enumerator {
            guard candidateURL.lastPathComponent == targetName else { continue }
            let values = try candidateURL.resourceValues(forKeys: Set(keys))
            if values.isDirectory == true {
                return candidateURL
            }
        }

        throw RuntimeError.missingRequiredArtifacts([targetName])
    }

    private static func findVocabularyFile(under rootDirectory: URL) throws -> URL {
        let keys: [URLResourceKey] = [.isDirectoryKey]
        guard
            let enumerator = FileManager.default.enumerator(
                at: rootDirectory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )
        else {
            throw RuntimeError.tokenVocabularyNotFound
        }

        for case let candidateURL as URL in enumerator {
            let fileName = candidateURL.lastPathComponent
            guard tokenVocabularyCandidates.contains(fileName) else { continue }
            let values = try candidateURL.resourceValues(forKeys: Set(keys))
            if values.isDirectory != true {
                return candidateURL
            }
        }

        throw RuntimeError.tokenVocabularyNotFound
    }

    private static func loadTokenVocabulary(from tokenVocabularyURL: URL) throws -> [Int: String] {
        let data = try Data(contentsOf: tokenVocabularyURL)
        return try parseVocabularyData(data, sourceName: tokenVocabularyURL.lastPathComponent)
    }

    private static func resolveCompiledModelURL(
        for component: ModelComponent,
        artifactURL: URL,
        modelDirectory: URL
    ) throws -> URL {
        let compiledURL = try compiledModelDirectory(for: component, artifactURL: artifactURL, modelDirectory: modelDirectory)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: compiledURL.path) {
            reportCompiledModelEvent(
                name: "cache_hit",
                component: component,
                artifactURL: artifactURL,
                compiledURL: compiledURL,
                extra: [:]
            )
            return compiledURL
        }

        return try buildCompiledModelURL(
            for: component,
            artifactURL: artifactURL,
            modelDirectory: modelDirectory,
            destinationURL: compiledURL,
            fileManager: fileManager
        )
    }

    private static func buildCompiledModelURL(
        for component: ModelComponent,
        artifactURL: URL,
        modelDirectory: URL,
        destinationURL: URL,
        fileManager: FileManager
    ) throws -> URL {
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        let compileStartedAt = Date()
        let temporaryCompiledURL = try MLModel.compileModel(at: artifactURL)
        try fileManager.moveItem(at: temporaryCompiledURL, to: destinationURL)
        pruneCompiledModelCache(for: component, keeping: destinationURL, in: modelDirectory, fileManager: fileManager)

        let compileDurationMs = Int(Date().timeIntervalSince(compileStartedAt) * 1_000)
        reportCompiledModelEvent(
            name: "compiled_persist",
            component: component,
            artifactURL: artifactURL,
            compiledURL: destinationURL,
            extra: ["compile_duration_ms": String(max(compileDurationMs, 0))]
        )
        PerformanceMonitor.shared.reportMetric(
            name: "cohere_compiled_model_compile_duration_ms",
            value: Double(max(compileDurationMs, 0)),
            unit: "ms"
        )
        return destinationURL
    }

    private static func reportCompiledModelEvent(
        name: String,
        component: ModelComponent,
        artifactURL: URL,
        compiledURL: URL,
        extra: [String: String]
    ) {
        var payload: [String: Any] = [
            "event": name,
            "component": component.rawValue,
            "source_artifact": artifactURL.lastPathComponent,
            "compiled_artifact": compiledURL.lastPathComponent,
        ]

        for (key, value) in extra {
            payload[key] = value
        }

        AppLogger.info(
            "Cohere compiled model lifecycle",
            category: .transcription,
            extra: payload
        )
    }

    private static func modelArtifactFingerprint(for artifactURL: URL) throws -> String {
        let fileManager = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey]
        var records = [artifactURL.lastPathComponent]

        let values = try artifactURL.resourceValues(forKeys: resourceKeys)
        if values.isDirectory == true {
            guard let enumerator = fileManager.enumerator(
                at: artifactURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                return stableFingerprint(for: records)
            }

            for case let candidateURL as URL in enumerator {
                let candidateValues = try candidateURL.resourceValues(forKeys: resourceKeys)
                if candidateValues.isDirectory == true { continue }
                let relativePath = candidateURL.path.replacingOccurrences(of: artifactURL.path + "/", with: "")
                let contentHash = SHA256.hash(data: try Data(contentsOf: candidateURL))
                let contentHex = contentHash.compactMap { String(format: "%02x", $0) }.joined()
                records.append("\(relativePath)|\(contentHex)")
            }
        } else {
            let contentHash = SHA256.hash(data: try Data(contentsOf: artifactURL))
            let contentHex = contentHash.compactMap { String(format: "%02x", $0) }.joined()
            records.append("\(artifactURL.lastPathComponent)|\(contentHex)")
        }

        return stableFingerprint(for: records.sorted())
    }

    private static func stableFingerprint(for records: [String]) -> String {
        var hash: UInt64 = 1_469_598_103_934_665_603

        for record in records {
            for byte in record.utf8 {
                hash ^= UInt64(byte)
                hash &*= 1_099_511_628_211
            }
            hash ^= 0xff
            hash &*= 1_099_511_628_211
        }

        return String(format: "%016llX", hash)
    }

    static func parseVocabularyData(_ data: Data, sourceName: String) throws -> [Int: String] {
        let json = try JSONSerialization.jsonObject(with: data)

        if
            let dictionary = json as? [String: Any],
            let tokens = dictionary["id_to_token"] as? [String],
            !tokens.isEmpty
        {
            var vocabulary: [Int: String] = [:]
            for (index, token) in tokens.enumerated() {
                vocabulary[index] = token
            }
            return vocabulary
        }

        if let dictionary = json as? [String: String] {
            var vocabulary: [Int: String] = [:]
            for (key, value) in dictionary {
                if let tokenID = Int(key) {
                    vocabulary[tokenID] = value
                }
            }
            if !vocabulary.isEmpty {
                return vocabulary
            }
        }

        if let array = json as? [String], !array.isEmpty {
            var vocabulary: [Int: String] = [:]
            for (index, token) in array.enumerated() {
                vocabulary[index] = token
            }
            return vocabulary
        }

        throw RuntimeError.tokenVocabularyUnreadable(sourceName)
    }
}
