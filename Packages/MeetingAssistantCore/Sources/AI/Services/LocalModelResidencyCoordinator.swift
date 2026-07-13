import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import os.log

@MainActor
protocol LocalModelResidencyManaging: AnyObject {
    /// Stable identifier for diagnostics and residency coverage auditing.
    var residencyManagerID: String { get }
    /// Local model IDs whose runtime memory lifecycle is managed by this residency manager.
    var managedLocalModelIDs: Set<String> { get }
    var lastASRActivityAt: Date? { get }
    var lastDiarizationActivityAt: Date? { get }
    var isASRInUse: Bool { get }
    var isDiarizationInUse: Bool { get }
    var isASRResidentInMemory: Bool { get }
    var isDiarizationResidentInMemory: Bool { get }
    @discardableResult func unloadASRFromMemoryIfPossible() -> Bool
    @discardableResult func unloadDiarizationFromMemoryIfPossible() -> Bool
}

extension FluidAIModelManager: LocalModelResidencyManaging {}

extension FluidAIModelManager {
    var residencyManagerID: String {
        "fluidaudio"
    }

    var managedLocalModelIDs: Set<String> {
        [
            LocalTranscriptionModel.parakeetTdt06BV3.rawValue,
            LocalTranscriptionModel.cohereTranscribe032026CoreML6Bit.rawValue,
        ]
    }
}

@MainActor
enum LocalModelRuntimeRegistry {
    /// Single source of truth for residency-managed local model runtimes.
    static var residencyManagers: [any LocalModelResidencyManaging] {
        [FluidAIModelManager.shared]
    }
}

@MainActor
protocol ModelResidencyTimeoutSettingsProviding: AnyObject {
    var modelResidencyTimeout: AppSettingsStore.ModelResidencyTimeoutOption { get }
}

extension AppSettingsStore: ModelResidencyTimeoutSettingsProviding {}

@MainActor
public final class LocalModelResidencyCoordinator {
    public static let shared = LocalModelResidencyCoordinator()

    private let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "LocalModelResidencyCoordinator")
    private let modelManagers: [any LocalModelResidencyManaging]
    private let settingsStore: any ModelResidencyTimeoutSettingsProviding
    private let checkIntervalNanoseconds: UInt64

    private var monitorTask: Task<Void, Never>?

    init(
        modelManager: any LocalModelResidencyManaging,
        settingsStore: any ModelResidencyTimeoutSettingsProviding = AppSettingsStore.shared,
        checkIntervalSeconds: TimeInterval = 30,
    ) {
        modelManagers = [modelManager]
        self.settingsStore = settingsStore
        let clampedInterval = max(1, checkIntervalSeconds)
        checkIntervalNanoseconds = UInt64(clampedInterval * 1_000_000_000)
    }

    init(
        modelManagers: [any LocalModelResidencyManaging] = LocalModelRuntimeRegistry.residencyManagers,
        settingsStore: any ModelResidencyTimeoutSettingsProviding = AppSettingsStore.shared,
        checkIntervalSeconds: TimeInterval = 30,
    ) {
        self.modelManagers = modelManagers
        self.settingsStore = settingsStore
        let clampedInterval = max(1, checkIntervalSeconds)
        checkIntervalNanoseconds = UInt64(clampedInterval * 1_000_000_000)
    }

    deinit {
        monitorTask?.cancel()
    }

    public func startMonitoring() {
        guard monitorTask == nil else { return }

        logLocalModelResidencyCoverage()
        logger.info("Starting local model residency monitoring.")
        monitorTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                evaluateAndUnloadIfNeeded(now: Date())
                try? await Task.sleep(nanoseconds: checkIntervalNanoseconds)
            }
        }
    }

    public func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func evaluateAndUnloadIfNeeded(now: Date = Date()) {
        guard let timeoutInterval = settingsStore.modelResidencyTimeout.inactivityInterval else {
            return
        }

        for modelManager in modelManagers {
            if shouldUnloadASR(using: modelManager, now: now, timeoutInterval: timeoutInterval),
               modelManager.unloadASRFromMemoryIfPossible()
            {
                logger.info("Auto-unloaded ASR model from RAM after inactivity threshold for manager=\(modelManager.residencyManagerID, privacy: .public).")
            }

            if shouldUnloadDiarization(using: modelManager, now: now, timeoutInterval: timeoutInterval),
               modelManager.unloadDiarizationFromMemoryIfPossible()
            {
                logger.info("Auto-unloaded diarization model from RAM after inactivity threshold for manager=\(modelManager.residencyManagerID, privacy: .public).")
            }
        }
    }

    func isResidencyManaged(localModelID: String) -> Bool {
        modelManagers.contains { $0.managedLocalModelIDs.contains(localModelID) }
    }

    private func shouldUnloadASR(
        using modelManager: any LocalModelResidencyManaging,
        now: Date,
        timeoutInterval: TimeInterval,
    ) -> Bool {
        guard modelManager.isASRResidentInMemory else { return false }
        guard !modelManager.isASRInUse else { return false }
        guard let lastActivity = modelManager.lastASRActivityAt else { return false }
        return now.timeIntervalSince(lastActivity) >= timeoutInterval
    }

    private func shouldUnloadDiarization(
        using modelManager: any LocalModelResidencyManaging,
        now: Date,
        timeoutInterval: TimeInterval,
    ) -> Bool {
        guard modelManager.isDiarizationResidentInMemory else { return false }
        guard !modelManager.isDiarizationInUse else { return false }
        guard let lastActivity = modelManager.lastDiarizationActivityAt else { return false }
        return now.timeIntervalSince(lastActivity) >= timeoutInterval
    }

    private func logLocalModelResidencyCoverage() {
        let managedModelIDs = Set(modelManagers.flatMap(\.managedLocalModelIDs))
        let configuredModelIDs = Set(LocalTranscriptionModel.allCases.map(\.rawValue))
        let uncoveredModelIDs = configuredModelIDs.subtracting(managedModelIDs)

        if uncoveredModelIDs.isEmpty {
            logger.info("Local model residency coverage verified for all configured local model IDs.")
            return
        }

        logger.error(
            "Missing residency manager coverage for local model IDs: \(uncoveredModelIDs.sorted().joined(separator: ", "), privacy: .public).",
        )
    }
}
