import AppKit
import Combine
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import os
import ServiceManagement
import SwiftUI

@MainActor
public class GeneralSettingsViewModel: ObservableObject {
    private let settingsStore: AppSettingsStore
    private let storage: StorageService
    private let localAICacheMaintenance: LocalAICacheMaintenanceService

    @Published public var autoStartRecording: Bool {
        didSet {
            settingsStore.autoStartRecording = autoStartRecording
        }
    }

    @Published public var recordingsPath: String {
        didSet {
            settingsStore.recordingsDirectory = recordingsPath
        }
    }

    @Published public var audioFormat: AppSettingsStore.AudioFormat {
        didSet {
            settingsStore.audioFormat = audioFormat
        }
    }

    @Published public var shouldMergeAudioFiles: Bool {
        didSet {
            settingsStore.shouldMergeAudioFiles = shouldMergeAudioFiles
        }
    }

    @Published public var selectedLanguage: AppLanguage {
        didSet {
            settingsStore.selectedLanguage = selectedLanguage
        }
    }

    @Published public var showSettingsOnLaunch: Bool {
        didSet {
            settingsStore.showSettingsOnLaunch = showSettingsOnLaunch
        }
    }

    @Published public var autoCopyTranscriptionToClipboard: Bool {
        didSet {
            settingsStore.autoCopyTranscriptionToClipboard = autoCopyTranscriptionToClipboard
        }
    }

    @Published public var shortcutDoubleTapIntervalMilliseconds: Double {
        didSet {
            settingsStore.shortcutDoubleTapIntervalMilliseconds = shortcutDoubleTapIntervalMilliseconds
        }
    }

    @Published public var autoPasteTranscriptionToActiveApp: Bool {
        didSet {
            settingsStore.autoPasteTranscriptionToActiveApp = autoPasteTranscriptionToActiveApp
        }
    }

    @Published public var smartSpacingAndCapitalizationEnabled: Bool {
        didSet {
            settingsStore.smartSpacingAndCapitalizationEnabled = smartSpacingAndCapitalizationEnabled
        }
    }

    @Published public var recordingMediaHandlingMode: AppSettingsStore.RecordingMediaHandlingMode {
        didSet {
            settingsStore.recordingMediaHandlingMode = recordingMediaHandlingMode
        }
    }

    @Published public var audioDuckingLevelPercent: Int {
        didSet {
            let clamped = AppSettingsStore.clampedAudioDuckingLevelPercent(audioDuckingLevelPercent)
            guard clamped == audioDuckingLevelPercent else {
                audioDuckingLevelPercent = clamped
                return
            }

            settingsStore.audioDuckingLevelPercent = audioDuckingLevelPercent
        }
    }

    @Published public var useSystemDefaultInput: Bool {
        didSet {
            settingsStore.useSystemDefaultInput = useSystemDefaultInput
        }
    }

    @Published public var autoIncreaseMicrophoneVolume: Bool {
        didSet {
            settingsStore.autoIncreaseMicrophoneVolume = autoIncreaseMicrophoneVolume
        }
    }

    @Published public var removeSilenceBeforeProcessing: Bool {
        didSet {
            settingsStore.removeSilenceBeforeProcessing = removeSilenceBeforeProcessing
        }
    }

    @Published public var recordingIndicatorEnabled: Bool {
        didSet {
            settingsStore.recordingIndicatorEnabled = recordingIndicatorEnabled
        }
    }

    @Published public var recordingIndicatorStyle: RecordingIndicatorStyle {
        didSet {
            settingsStore.recordingIndicatorStyle = recordingIndicatorStyle
        }
    }

    @Published public var recordingIndicatorPosition: RecordingIndicatorPosition {
        didSet {
            settingsStore.recordingIndicatorPosition = recordingIndicatorPosition
        }
    }

    @Published public var recordingIndicatorAnimationSpeed: RecordingIndicatorAnimationSpeed {
        didSet {
            settingsStore.recordingIndicatorAnimationSpeed = recordingIndicatorAnimationSpeed
        }
    }

    @Published public var autoDeleteTranscriptions: Bool {
        didSet {
            settingsStore.autoDeleteTranscriptions = autoDeleteTranscriptions
        }
    }

    @Published public var autoDeletePeriodDays: Int {
        didSet {
            settingsStore.autoDeletePeriodDays = autoDeletePeriodDays
        }
    }

    // MARK: - Sound Feedback Properties

    @Published public var soundFeedbackEnabled: Bool {
        didSet {
            settingsStore.soundFeedbackEnabled = soundFeedbackEnabled
        }
    }

    @Published public var recordingStartSound: SoundFeedbackSound {
        didSet {
            settingsStore.recordingStartSound = recordingStartSound
        }
    }

    @Published public var recordingStopSound: SoundFeedbackSound {
        didSet {
            settingsStore.recordingStopSound = recordingStopSound
        }
    }

    @Published public var showInDock: Bool {
        didSet {
            settingsStore.showInDock = showInDock
        }
    }

    @Published public var launchAtLogin: Bool {
        didSet {
            // Avoid infinite loop if we revert the state
            guard launchAtLogin != settingsStore.launchAtLogin else { return }

            settingsStore.launchAtLogin = launchAtLogin
            updateLaunchAtLogin(launchAtLogin)
        }
    }

    @Published public var microphoneWhenChargingUID: String? {
        didSet {
            settingsStore.microphoneWhenChargingUID = microphoneWhenChargingUID
            rebuildAvailableDevices()
        }
    }

    @Published public var microphoneOnBatteryUID: String? {
        didSet {
            settingsStore.microphoneOnBatteryUID = microphoneOnBatteryUID
            rebuildAvailableDevices()
        }
    }

    @Published public var availableDevices: [AudioInputDevice] = []
    @Published public var showCleanupSuccessAlert = false
    @Published public var showCleanupConfirmationDialog = false
    @Published public var cleanupInProgress = false
    @Published public var cleanupError: String?
    @Published public var cleanupPreview: RetentionCleanupPreview?
    @Published public var localAICacheCleanupPreview: LocalAICacheCleanupPreview?

    private let deviceManager = AudioDeviceManager()
    private var cancellables = Set<AnyCancellable>()
    private nonisolated static let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "GeneralSettingsViewModel")

    public init(
        settingsStore: AppSettingsStore = .shared,
        storage: StorageService = FileSystemStorageService.shared,
        localAICacheMaintenance: LocalAICacheMaintenanceService = .shared
    ) {
        self.settingsStore = settingsStore
        self.storage = storage
        self.localAICacheMaintenance = localAICacheMaintenance
        autoStartRecording = settingsStore.autoStartRecording
        recordingsPath = settingsStore.recordingsDirectory
        audioFormat = settingsStore.audioFormat
        shouldMergeAudioFiles = settingsStore.shouldMergeAudioFiles
        selectedLanguage = settingsStore.selectedLanguage
        showSettingsOnLaunch = settingsStore.showSettingsOnLaunch
        autoCopyTranscriptionToClipboard = settingsStore.autoCopyTranscriptionToClipboard
        shortcutDoubleTapIntervalMilliseconds = settingsStore.shortcutDoubleTapIntervalMilliseconds
        autoPasteTranscriptionToActiveApp = settingsStore.autoPasteTranscriptionToActiveApp
        smartSpacingAndCapitalizationEnabled = settingsStore.smartSpacingAndCapitalizationEnabled
        recordingMediaHandlingMode = settingsStore.recordingMediaHandlingMode
        audioDuckingLevelPercent = settingsStore.audioDuckingLevelPercent
        useSystemDefaultInput = settingsStore.useSystemDefaultInput
        microphoneWhenChargingUID = settingsStore.microphoneWhenChargingUID
        microphoneOnBatteryUID = settingsStore.microphoneOnBatteryUID
        autoIncreaseMicrophoneVolume = settingsStore.autoIncreaseMicrophoneVolume
        removeSilenceBeforeProcessing = settingsStore.removeSilenceBeforeProcessing
        recordingIndicatorEnabled = settingsStore.recordingIndicatorEnabled
        recordingIndicatorStyle = settingsStore.recordingIndicatorStyle
        recordingIndicatorPosition = settingsStore.recordingIndicatorPosition
        recordingIndicatorAnimationSpeed = settingsStore.recordingIndicatorAnimationSpeed
        autoDeleteTranscriptions = settingsStore.autoDeleteTranscriptions
        autoDeletePeriodDays = settingsStore.autoDeletePeriodDays
        soundFeedbackEnabled = settingsStore.soundFeedbackEnabled
        recordingStartSound = settingsStore.recordingStartSound
        recordingStopSound = settingsStore.recordingStopSound
        showInDock = settingsStore.showInDock
        launchAtLogin = settingsStore.launchAtLogin

        setupDeviceObservation()
        rebuildAvailableDevices()
    }

    public var usesDuckingControls: Bool {
        recordingMediaHandlingMode.usesDucking
    }

    public var currentPowerSourceState: PowerSourceState {
        PowerSourceStateProvider().currentPowerSourceState()
    }

    public var systemDefaultInputDevice: AudioInputDevice? {
        availableDevices.first(where: { $0.isDefault && $0.isAvailable })
            ?? availableDevices.first(where: \.isDefault)
    }

    public func microphoneUID(for powerSource: PowerSourceState) -> String? {
        switch powerSource {
        case .charging:
            microphoneWhenChargingUID
        case .battery:
            microphoneOnBatteryUID
        }
    }

    public func setMicrophoneUID(_ uid: String?, for powerSource: PowerSourceState) {
        switch powerSource {
        case .charging:
            microphoneWhenChargingUID = uid
        case .battery:
            microphoneOnBatteryUID = uid
        }
    }

    public func selectedMicrophone(for powerSource: PowerSourceState) -> AudioInputDevice? {
        guard let uid = microphoneUID(for: powerSource) else { return nil }
        return availableDevices.first(where: { $0.id == uid })
    }

    public func refreshAudioInputDevices() {
        deviceManager.refreshDevices()
    }

    public var cleanupConfirmationMessage: String {
        let preview = cleanupPreview
        let cachePreview = localAICacheCleanupPreview

        let audioCount = preview?.audioCount ?? 0
        let cacheCount = cachePreview?.candidateCount ?? 0

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file

        let audioSize = formatter.string(fromByteCount: preview?.totalAudioBytes ?? 0)
        let cacheSize = formatter.string(fromByteCount: cachePreview?.totalBytes ?? 0)

        return String(
            format: "settings.storage.cleanup_confirm_message".localized,
            audioCount,
            audioSize,
            cacheCount,
            cacheSize
        )
    }

    private func setupDeviceObservation() {
        deviceManager.$availableInputDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.mergeAvailableDevices(detectedDevices: devices)
            }
            .store(in: &cancellables)
    }

    private func mergeAvailableDevices(detectedDevices: [AudioInputDevice]) {
        let selectedUIDs = selectedMicrophoneUIDs
        let detectedUIDs = Set(detectedDevices.map(\.id))
        var merged = detectedDevices

        for uid in selectedUIDs where !detectedUIDs.contains(uid) {
            // Preserve unavailable persisted selections so user intent remains visible in pickers.
            merged.append(AudioInputDevice(id: uid, name: "Unknown Device (\(uid))", isAvailable: false))
        }

        availableDevices = merged
    }

    private var selectedMicrophoneUIDs: [String] {
        [microphoneWhenChargingUID, microphoneOnBatteryUID]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func rebuildAvailableDevices() {
        mergeAvailableDevices(detectedDevices: deviceManager.availableInputDevices)
    }

    public func selectRecordingsDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        // Use current path as starting point if valid
        if !recordingsPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: recordingsPath)
        }

        if panel.runModal() == .OK, let url = panel.url {
            recordingsPath = url.path
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            Self.logger.error("Failed to update launch at login: \(error.localizedDescription)")

            // Revert state on failure
            DispatchQueue.main.async { [weak self] in
                self?.launchAtLogin = !enabled
            }
        }
    }

    public func performCleanup() {
        guard !cleanupInProgress else { return }

        cleanupError = nil
        cleanupPreview = nil
        localAICacheCleanupPreview = nil
        cleanupInProgress = true

        Task { [weak self] in
            guard let self else { return }

            do {
                let preview = try await storage.computeRetentionCleanupPreview(olderThanDays: autoDeletePeriodDays)
                let cachePreview = try await localAICacheMaintenance.computeCleanupPreview(olderThanDays: autoDeletePeriodDays)
                cleanupPreview = preview
                localAICacheCleanupPreview = cachePreview
                showCleanupConfirmationDialog = true
            } catch {
                cleanupError = error.localizedDescription
            }

            cleanupInProgress = false
        }
    }

    public func confirmCleanup() {
        guard !cleanupInProgress else { return }
        guard let preview = cleanupPreview else { return }
        let cachePreview = localAICacheCleanupPreview

        cleanupError = nil
        cleanupInProgress = true

        Task { [weak self] in
            guard let self else { return }

            do {
                _ = FluidAIModelManager.shared.unloadDiarizationFromMemoryIfPossible()
                _ = FluidAIModelManager.shared.unloadASRFromMemoryIfPossible()
                _ = try await storage.performRetentionCleanup(preview: preview)
                if let cachePreview {
                    _ = try await localAICacheMaintenance.performCleanup(preview: cachePreview)
                }
                showCleanupSuccessAlert = true
            } catch {
                cleanupError = error.localizedDescription
            }

            cleanupInProgress = false
            cleanupPreview = nil
            localAICacheCleanupPreview = nil
        }
    }
}
