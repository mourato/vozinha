import Combine
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

@MainActor
public class ServiceSettingsViewModel: ObservableObject {
    @Published public var transcriptionStatus: ConnectionStatus = .unknown
    @Published public var modelState: FluidAIModelManager.ModelState = .unloaded
    @Published public var isASRInstalled: Bool = false
    @Published public var isDiarizationLoaded: Bool = false
    @Published public var asrLastErrorMessage: String?
    @Published public var transcriptionAPIKeyInput: String = ""
    @Published public var transcriptionAPIKeyErrorMessage: String?

    private let transcriptionClient: TranscriptionClient
    private let settings: AppSettingsStore
    private let keychain: KeychainProvider
    private var cancellables = Set<AnyCancellable>()

    public init(
        transcriptionClient: TranscriptionClient = .shared,
        settings: AppSettingsStore = .shared,
        keychain: KeychainProvider = DefaultKeychainProvider()
    ) {
        self.transcriptionClient = transcriptionClient
        self.settings = settings
        self.keychain = keychain

        modelState = FluidAIModelManager.shared.modelState
        isASRInstalled = FluidAIModelManager.shared.isASRInstalled
        isDiarizationLoaded = FluidAIModelManager.shared.isDiarizationLoaded
        asrLastErrorMessage = FluidAIModelManager.shared.lastError

        FluidAIModelManager.shared.$modelState
            .receive(on: DispatchQueue.main)
            .assign(to: \.modelState, on: self)
            .store(in: &cancellables)

        FluidAIModelManager.shared.$isASRInstalled
            .receive(on: DispatchQueue.main)
            .assign(to: \.isASRInstalled, on: self)
            .store(in: &cancellables)

        FluidAIModelManager.shared.$isDiarizationLoaded
            .receive(on: DispatchQueue.main)
            .assign(to: \.isDiarizationLoaded, on: self)
            .store(in: &cancellables)

        FluidAIModelManager.shared.$lastError
            .receive(on: DispatchQueue.main)
            .assign(to: \.asrLastErrorMessage, on: self)
            .store(in: &cancellables)

        settings.$modelResidencyTimeout
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        settings.$transcriptionInputLanguageHint
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        refreshInstalledModelStates()
    }

    public func testConnection() {
        transcriptionStatus = .testing

        Task {
            do {
                var isHealthy = try await self.transcriptionClient.healthCheck()

                // If unhealthy, attempt an explicit warmup/load so Verify can recover
                // from unloaded/error model states instead of only reporting failure.
                if !isHealthy {
                    try await self.transcriptionClient.warmupModel()
                    isHealthy = try await self.transcriptionClient.healthCheck()
                }

                if isHealthy {
                    self.transcriptionStatus = .success
                } else {
                    let message = FluidAIModelManager.shared.lastError?.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.transcriptionStatus = .failure((message?.isEmpty == false) ? message : nil)
                }
            } catch {
                let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                self.transcriptionStatus = .failure(message.isEmpty ? nil : message)
            }
        }
    }

    public func deleteASRModels() {
        Task {
            FluidAIModelManager.shared.deleteASRModels()
        }
    }

    public func downloadASRModels() {
        Task {
            await FluidAIModelManager.shared.loadModels()
        }
    }

    public func downloadDiarizationModels() {
        Task {
            await FluidAIModelManager.shared.loadDiarizationModels()
        }
    }

    public func deleteDiarizationModels() {
        Task {
            FluidAIModelManager.shared.deleteDiarizationModels()
        }
    }

    public func refreshInstalledModelStates() {
        FluidAIModelManager.shared.refreshInstalledModelStates()
    }

    public func downloadMeetingLocalCohereModel() {
        Task {
            await FluidAIModelManager.shared.loadModels(
                for: MeetingAssistantCoreInfrastructure.TranscriptionProvider.cohereLocalModelID
            )
            await MainActor.run {
                self.objectWillChange.send()
            }
        }
    }

    public var selectedDictationProvider: MeetingAssistantCoreInfrastructure.TranscriptionProvider {
        settings.transcriptionDictationSelection.provider
    }

    public var selectedDictationProviderRawValue: String {
        selectedDictationProvider.rawValue
    }

    public var selectedDictationModel: String {
        settings.transcriptionDictationSelection.selectedModel
    }

    public var availableDictationProviders: [MeetingAssistantCoreInfrastructure.TranscriptionProvider] {
        MeetingAssistantCoreInfrastructure.TranscriptionProvider.allCases
    }

    public var availableDictationModels: [String] {
        switch selectedDictationProvider {
        case .local:
            MeetingAssistantCoreInfrastructure.TranscriptionProvider.localPresetModelIDs
        case .groq:
            MeetingAssistantCoreInfrastructure.TranscriptionProvider.groqPresetModelIDs
        case .elevenLabs:
            MeetingAssistantCoreInfrastructure.TranscriptionProvider.elevenLabsPresetModelIDs
        }
    }

    public var availableInputLanguageHints: [TranscriptionInputLanguageHint] {
        TranscriptionInputLanguageHint.allCases
    }

    public var selectedInputLanguageHintRawValue: String {
        settings.transcriptionInputLanguageHint.rawValue
    }

    public var meetingLocalModelDisplayName: String {
        displayName(forModelID: settings.resolvedTranscriptionSelection(for: .meeting).selectedModel)
    }

    public var shouldShowMeetingDiarizationAutoDisableWarning: Bool {
        let meetingModelID = settings.resolvedTranscriptionSelection(for: .meeting).selectedModel
        return settings.isDiarizationEnabled
            && !settings.localModelSupportsDiarization(modelID: meetingModelID)
    }

    public var isMeetingLocalCohereSelected: Bool {
        settings.resolvedTranscriptionSelection(for: .meeting).selectedModel
            == MeetingAssistantCoreInfrastructure.TranscriptionProvider.cohereLocalModelID
    }

    public var isMeetingLocalCohereInstalled: Bool {
        FluidAIModelManager.shared.isASRModelInstalled(
            localModelID: MeetingAssistantCoreInfrastructure.TranscriptionProvider.cohereLocalModelID
        )
    }

    public var isASRDownloadInProgress: Bool {
        modelState == .downloading || modelState == .loading
    }

    public var cohereDownloadErrorMessage: String? {
        guard isMeetingLocalCohereSelected else { return nil }
        guard !isMeetingLocalCohereInstalled else { return nil }
        guard modelState == .error else { return nil }
        let message = asrLastErrorMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (message?.isEmpty == false) ? message : nil
    }

    public var modelResidencyTimeoutOptions: [AppSettingsStore.ModelResidencyTimeoutOption] {
        AppSettingsStore.ModelResidencyTimeoutOption.allCases
    }

    public var modelResidencyTimeout: AppSettingsStore.ModelResidencyTimeoutOption {
        get {
            settings.modelResidencyTimeout
        }
        set {
            settings.modelResidencyTimeout = newValue
        }
    }

    public var shouldShowRemoteTranscriptionAPIKeyActions: Bool {
        selectedDictationProvider.usesRemoteInference
    }

    public var shouldShowInlineTranscriptionAPIKeyInput: Bool {
        selectedDictationProvider == .elevenLabs && !isDictationProviderReady
    }

    public var selectedRemoteProviderGetAPIKeyURL: URL? {
        switch selectedDictationProvider {
        case .local:
            nil
        case .groq:
            AIProvider.groq.apiKeyURL
        case .elevenLabs:
            URL(string: "https://elevenlabs.io/app/settings/api-keys")
        }
    }

    public var selectedRemoteProviderDisplayName: String {
        switch selectedDictationProvider {
        case .local:
            "settings.service.transcription_provider.option.local".localized
        case .groq:
            "settings.service.transcription_provider.option.groq".localized
        case .elevenLabs:
            "settings.service.transcription_provider.option.elevenlabs".localized
        }
    }

    public var isDictationProviderReady: Bool {
        switch selectedDictationProvider {
        case .local:
            true
        case .groq:
            keychain.existsAPIKey(for: .groq)
        case .elevenLabs:
            keychain.existsTranscriptionAPIKey(for: .elevenLabs)
        }
    }

    public var hasPendingTranscriptionAPIKeyInput: Bool {
        !transcriptionAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func updateDictationProvider(rawValue: String) {
        guard let provider = MeetingAssistantCoreInfrastructure.TranscriptionProvider(rawValue: rawValue) else {
            return
        }
        settings.updateTranscriptionDictationProvider(provider)
        transcriptionAPIKeyErrorMessage = nil
        loadTranscriptionAPIKeyInputForCurrentProvider()
        objectWillChange.send()
    }

    public func updateDictationModel(_ model: String) {
        settings.updateTranscriptionDictationModel(model)
        objectWillChange.send()
    }

    public func updateTranscriptionInputLanguageHint(rawValue: String) {
        guard let hint = TranscriptionInputLanguageHint(rawValue: rawValue) else { return }
        settings.transcriptionInputLanguageHint = hint
        objectWillChange.send()
    }

    public func saveTranscriptionAPIKey() {
        let trimmed = transcriptionAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            transcriptionAPIKeyErrorMessage = "settings.service.transcription_provider.api_key.error.empty".localized
            return
        }

        do {
            try keychain.storeTranscriptionAPIKey(trimmed, for: selectedDictationProvider)
            transcriptionAPIKeyInput = ""
            transcriptionAPIKeyErrorMessage = nil
            objectWillChange.send()
        } catch {
            transcriptionAPIKeyErrorMessage = error.localizedDescription
        }
    }

    public func removeTranscriptionAPIKey() {
        do {
            try keychain.deleteTranscriptionAPIKey(for: selectedDictationProvider)
            transcriptionAPIKeyInput = ""
            transcriptionAPIKeyErrorMessage = nil
            objectWillChange.send()
        } catch {
            transcriptionAPIKeyErrorMessage = error.localizedDescription
        }
    }

    public func displayName(forModelID modelID: String) -> String {
        if let localModel = MeetingAssistantCoreInfrastructure.LocalTranscriptionModel(rawValue: modelID) {
            switch localModel {
            case .parakeetTdt06BV3:
                "settings.service.transcription_provider.model_option.local.parakeet".localized
            case .cohereTranscribe032026CoreML6Bit:
                "settings.service.transcription_provider.model_option.local.cohere".localized
            }
        } else if modelID == "scribe_v1" {
            "settings.service.transcription_provider.model_option.elevenlabs.scribe_v1".localized
        } else if modelID == "scribe_v2" {
            "settings.service.transcription_provider.model_option.elevenlabs.scribe_v2".localized
        } else {
            modelID
        }
    }

    private func loadTranscriptionAPIKeyInputForCurrentProvider() {
        transcriptionAPIKeyInput = ""
        transcriptionAPIKeyErrorMessage = nil
    }
}
