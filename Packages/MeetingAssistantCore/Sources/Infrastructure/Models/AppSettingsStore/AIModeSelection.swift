import Foundation
import MeetingAssistantCoreDomain

public extension AppSettingsStore {
    /// Updates the selected model for the current AI provider.
    /// This properly triggers the @Published didSet to persist changes.
    func updateSelectedModel(_ model: String) {
        var config = aiConfiguration
        config.selectedModel = model
        aiConfiguration = config
    }

    /// Updates the AI configuration for a specific provider.
    /// Properly triggers the @Published didSet to persist changes.
    func updateAIConfiguration(provider: AIProvider, baseURL: String? = nil, selectedModel: String? = nil) {
        var config = aiConfiguration
        config.provider = provider
        if let baseURL {
            config.baseURL = baseURL
        }
        if let selectedModel {
            config.selectedModel = selectedModel
        }
        aiConfiguration = config
    }

    func enhancementsRegistration(for id: UUID?) -> EnhancementsProviderRegistration? {
        guard let id else { return nil }
        return enhancementsProviderRegistrations.first(where: { $0.id == id })
    }

    func enhancementsRegistration(for provider: AIProvider) -> EnhancementsProviderRegistration? {
        enhancementsProviderRegistrations.first(where: { $0.provider == provider })
    }

    func enhancementsRegistrations(for provider: AIProvider) -> [EnhancementsProviderRegistration] {
        enhancementsProviderRegistrations.filter { $0.provider == provider }
    }

    func canAddEnhancementsProviderRegistration(_ provider: AIProvider) -> Bool {
        provider == .custom || enhancementsRegistration(for: provider) == nil
    }

    func suggestedCustomEnhancementsProviderName() -> String {
        let customCount = enhancementsProviderRegistrations.count(where: { $0.provider == .custom })
        let nextIndex = customCount + 1
        return "settings.enhancements.provider.custom.default_name".localized(with: nextIndex)
    }

    @discardableResult
    func addEnhancementsProviderRegistration(
        provider: AIProvider,
        displayName: String? = nil,
        baseURLOverride: String? = nil,
        iconSystemName: String? = nil,
    ) -> EnhancementsProviderRegistration? {
        guard canAddEnhancementsProviderRegistration(provider) else { return nil }

        let registration = EnhancementsProviderRegistration(
            provider: provider,
            displayName: displayName ?? defaultRegistrationDisplayName(for: provider),
            baseURLOverride: provider == .custom ? baseURLOverride : nil,
            iconSystemName: provider == .custom ? iconSystemName : nil,
        )

        var updated = enhancementsProviderRegistrations
        updated.append(registration)
        enhancementsProviderRegistrations = updated

        if enhancementsAISelection.registrationID == nil,
           enhancementsAISelection.provider == provider
        {
            enhancementsAISelection.registrationID = registration.id
        }

        if enhancementsDictationAISelection.registrationID == nil,
           enhancementsDictationAISelection.provider == provider
        {
            enhancementsDictationAISelection.registrationID = registration.id
        }

        return registration
    }

    func updateEnhancementsProviderRegistration(_ registration: EnhancementsProviderRegistration) {
        guard let index = enhancementsProviderRegistrations.firstIndex(where: { $0.id == registration.id }) else {
            return
        }

        var normalized = registration
        normalized.touchUpdatedAt()

        var updated = enhancementsProviderRegistrations
        updated[index] = normalized

        if normalized.isBuiltInSingleton {
            var seenBuiltInProviders = Set<AIProvider>()
            updated = updated.filter { candidate in
                if candidate.id == normalized.id {
                    seenBuiltInProviders.insert(candidate.provider)
                    return true
                }

                if candidate.provider == .custom {
                    return true
                }

                guard !seenBuiltInProviders.contains(candidate.provider) else {
                    return false
                }

                seenBuiltInProviders.insert(candidate.provider)
                return true
            }
        }

        enhancementsProviderRegistrations = updated
    }

    func removeEnhancementsProviderRegistration(id: UUID) {
        guard let removed = enhancementsProviderRegistrations.first(where: { $0.id == id }) else {
            return
        }

        enhancementsProviderRegistrations.removeAll { $0.id == id }
        enhancementsProviderSelectedModelsByRegistration.removeValue(forKey: id.uuidString)
        try? KeychainManager.deleteAPIKey(for: id)

        if !enhancementsProviderRegistrations.contains(where: { $0.provider == removed.provider }) {
            enhancementsProviderSelectedModels.removeValue(forKey: removed.provider.rawValue)
        }

        if enhancementsAISelection.registrationID == id {
            enhancementsAISelection.registrationID = nil
            enhancementsAISelection.selectedModel = ""
        }

        if enhancementsDictationAISelection.registrationID == id {
            enhancementsDictationAISelection.registrationID = nil
            enhancementsDictationAISelection.selectedModel = ""
        }
    }

    func migrateEnhancementsProviderRegistrationAPIKeysIfNeeded() {
        let firstCustomRegistrationID = enhancementsProviderRegistrations
            .first(where: { $0.provider == .custom })?
            .id

        for registration in enhancementsProviderRegistrations {
            if registration.provider.usesRegistrationScopedEnhancementsCredential {
                if KeychainManager.existsAPIKey(for: registration.id) {
                    continue
                }

                if registration.id != firstCustomRegistrationID {
                    continue
                }

                guard let legacyProviderKey = try? KeychainManager.retrieveAPIKey(for: registration.provider) else {
                    continue
                }

                let apiKey = legacyProviderKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !apiKey.isEmpty else { continue }

                try? KeychainManager.storeAPIKey(apiKey, for: registration.id)
                continue
            }

            let registrationKey = (try? KeychainManager.retrieveAPIKey(for: registration.id))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !registrationKey.isEmpty else { continue }

            if !KeychainManager.existsAPIKey(for: registration.provider) {
                let providerKey = KeychainManager.apiKeyKey(for: registration.provider)
                try? KeychainManager.store(registrationKey, for: providerKey)
            }

            try? KeychainManager.deleteAPIKey(for: registration.id)
        }
    }

    func enhancementsAPIKey(for mode: IntelligenceKernelMode) -> String? {
        if let key = enhancementsAPIKeyInternal(for: mode) {
            return key
        }
        return enhancementsAPIKeyInternal(for: siblingEnhancementsMode(for: mode))
    }

    func enhancementsAPIKey(for selection: EnhancementsAISelection) -> String? {
        let selectedRegistration = enhancementsRegistration(for: selection.registrationID)

        if let registrationID = selection.registrationID,
           let registrationKey = try? KeychainManager.retrieveAPIKey(for: registrationID)
        {
            let trimmed = registrationKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        let providerForFallback = selectedRegistration?.provider ?? selection.provider
        if let providerKey = try? KeychainManager.retrieveAPIKey(for: providerForFallback) {
            let trimmed = providerKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }

    private func enhancementsAPIKeyInternal(for mode: IntelligenceKernelMode) -> String? {
        let selection = enhancementsSelection(for: mode)
        let selectedRegistration = enhancementsRegistration(for: selection.registrationID)

        if let registrationID = selection.registrationID,
           let registrationKey = try? KeychainManager.retrieveAPIKey(for: registrationID)
        {
            let trimmed = registrationKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        let providerForFallback = selectedRegistration?.provider ?? selection.provider
        if let providerKey = try? KeychainManager.retrieveAPIKey(for: providerForFallback) {
            let trimmed = providerKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }

    func enhancementsProviderDisplayName(for selection: EnhancementsAISelection) -> String {
        enhancementsRegistration(for: selection.registrationID)?.displayName ?? selection.provider.displayName
    }

    private func defaultRegistrationDisplayName(for provider: AIProvider) -> String {
        if provider == .custom {
            return suggestedCustomEnhancementsProviderName()
        }
        return provider.displayName
    }

    func updateEnhancementsProvider(_ provider: AIProvider) {
        var selection = enhancementsAISelection
        let targetRegistrationID = enhancementsRegistration(for: provider)?.id
        guard selection.provider != provider || selection.registrationID != targetRegistrationID else { return }
        selection.provider = provider
        selection.registrationID = targetRegistrationID
        selection.selectedModel = enhancementsSelectedModel(for: provider)
        enhancementsAISelection = selection
    }

    func updateEnhancementsSelectedModel(_ model: String) {
        var selection = enhancementsAISelection
        let normalizedModel = normalizedEnhancementsModelID(model, for: selection.provider)
        selection.selectedModel = normalizedModel
        enhancementsAISelection = selection
        setEnhancementsProviderSelectedModel(normalizedModel, for: selection.provider)
        if let registrationID = selection.registrationID {
            setEnhancementsProviderSelectedModel(normalizedModel, for: registrationID)
        }
    }

    func updateEnhancementsDictationProvider(_ provider: AIProvider) {
        var selection = enhancementsDictationAISelection
        let targetRegistrationID = enhancementsRegistration(for: provider)?.id
        guard selection.provider != provider || selection.registrationID != targetRegistrationID else { return }
        selection.provider = provider
        selection.registrationID = targetRegistrationID
        selection.selectedModel = enhancementsSelectedModel(for: provider)
        enhancementsDictationAISelection = selection
    }

    func updateEnhancementsDictationSelectedModel(_ model: String) {
        var selection = enhancementsDictationAISelection
        let normalizedModel = normalizedEnhancementsModelID(model, for: selection.provider)
        selection.selectedModel = normalizedModel
        enhancementsDictationAISelection = selection
        setEnhancementsProviderSelectedModel(normalizedModel, for: selection.provider)
        if let registrationID = selection.registrationID {
            setEnhancementsProviderSelectedModel(normalizedModel, for: registrationID)
        }
    }

    func updateEnhancementsSelection(
        provider: AIProvider,
        model: String,
        for mode: IntelligenceKernelMode,
    ) {
        let registrationID = enhancementsRegistration(for: provider)?.id
        updateEnhancementsSelection(
            provider: provider,
            registrationID: registrationID,
            model: model,
            for: mode,
        )
    }

    func updateEnhancementsSelection(
        registrationID: UUID,
        model: String,
        for mode: IntelligenceKernelMode,
    ) {
        guard let registration = enhancementsRegistration(for: registrationID) else { return }
        updateEnhancementsSelection(
            provider: registration.provider,
            registrationID: registration.id,
            model: model,
            for: mode,
        )
    }

    private func updateEnhancementsSelection(
        provider: AIProvider,
        registrationID: UUID?,
        model: String,
        for mode: IntelligenceKernelMode,
    ) {
        let normalizedModel = normalizedEnhancementsModelID(model, for: provider)
        switch mode {
        case .meeting:
            enhancementsAISelection = EnhancementsAISelection(
                provider: provider,
                selectedModel: normalizedModel,
                registrationID: registrationID,
            )
        case .dictation, .assistant:
            enhancementsDictationAISelection = EnhancementsAISelection(
                provider: provider,
                selectedModel: normalizedModel,
                registrationID: registrationID,
            )
        }
        setEnhancementsProviderSelectedModel(normalizedModel, for: provider)
        if let registrationID {
            setEnhancementsProviderSelectedModel(normalizedModel, for: registrationID)
        }
    }

    func updateEnhancementsProviderSelectedModel(_ model: String, for provider: AIProvider) {
        setEnhancementsProviderSelectedModel(normalizedEnhancementsModelID(model, for: provider), for: provider)
    }

    func updateEnhancementsProviderSelectedModel(_ model: String, for registrationID: UUID) {
        guard let registration = enhancementsRegistration(for: registrationID) else { return }
        let normalizedModel = normalizedEnhancementsModelID(model, for: registration.provider)
        setEnhancementsProviderSelectedModel(normalizedModel, for: registration.provider)
        setEnhancementsProviderSelectedModel(normalizedModel, for: registrationID)
    }

    func enhancementsSelectedModel(for provider: AIProvider) -> String {
        if let registrationID = enhancementsRegistration(for: provider)?.id {
            let modelByRegistration = enhancementsProviderSelectedModelsByRegistration[registrationID.uuidString] ?? ""
            if !modelByRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return normalizedEnhancementsModelID(modelByRegistration, for: provider)
            }
        }

        let model = enhancementsProviderSelectedModels[provider.rawValue] ?? ""
        return normalizedEnhancementsModelID(model, for: provider)
    }

    func enhancementsSelectedModel(for registrationID: UUID) -> String {
        guard let registration = enhancementsRegistration(for: registrationID) else { return "" }
        let model = enhancementsProviderSelectedModelsByRegistration[registrationID.uuidString] ?? ""
        let normalizedModel = normalizedEnhancementsModelID(model, for: registration.provider)
        if !normalizedModel.isEmpty {
            return normalizedModel
        }
        return enhancementsSelectedModel(for: registration.provider)
    }

    func isEnhancementsRegistrationSelected(
        _ registration: EnhancementsProviderRegistration,
        for mode: IntelligenceKernelMode,
    ) -> Bool {
        let selection = enhancementsSelection(for: mode)
        if let selectedRegistrationID = selection.registrationID {
            return selectedRegistrationID == registration.id
        }

        guard selection.provider == registration.provider else { return false }
        return enhancementsRegistration(for: registration.provider)?.id == registration.id
    }

    /// Resolves the runtime configuration for Enhancements (post-processing + Q&A).
    var resolvedEnhancementsAIConfiguration: AIConfiguration {
        resolvedEnhancementsAIConfiguration(for: .meeting)
    }

    func resolvedEnhancementsAIConfiguration(for mode: IntelligenceKernelMode) -> AIConfiguration {
        let config = resolveEnhancementsAIConfigurationInternal(for: mode)
        let hasModel = !config.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasModel, let baseURL = URL(string: config.baseURL), baseURL.scheme != nil {
            return config
        }
        let siblingMode = siblingEnhancementsMode(for: mode)
        let siblingConfig = resolveEnhancementsAIConfigurationInternal(for: siblingMode)
        let siblingHasModel = !siblingConfig.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard siblingHasModel else { return config }
        return siblingConfig
    }

    func resolvedEnhancementsAIConfiguration(for selection: EnhancementsAISelection) -> AIConfiguration {
        resolveEnhancementsAIConfigurationInternal(for: selection)
    }

    private func resolveEnhancementsAIConfigurationInternal(for mode: IntelligenceKernelMode) -> AIConfiguration {
        resolveEnhancementsAIConfigurationInternal(for: enhancementsSelection(for: mode))
    }

    private func resolveEnhancementsAIConfigurationInternal(for selection: EnhancementsAISelection) -> AIConfiguration {
        let registration = enhancementsRegistration(for: selection.registrationID)
        let provider = registration?.provider ?? selection.provider
        let baseURL: String = if let registration {
            registration.resolvedBaseURL
        } else if provider == .custom {
            aiConfiguration.baseURL
        } else {
            provider.defaultBaseURL
        }

        let selectionModel = selection.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedModel: String = if !selectionModel.isEmpty {
            normalizedEnhancementsModelID(selectionModel, for: provider)
        } else if let registrationID = selection.registrationID {
            enhancementsSelectedModel(for: registrationID)
        } else {
            enhancementsSelectedModel(for: provider)
        }

        return AIConfiguration(
            provider: provider,
            baseURL: baseURL,
            selectedModel: selectedModel,
        )
    }

    var enhancementsInferenceReadinessIssue: EnhancementsInferenceReadinessIssue? {
        enhancementsInferenceReadinessIssue(for: .meeting, apiKeyExists: nil)
    }

    var isEnhancementsInferenceReady: Bool {
        enhancementsInferenceReadinessIssue == nil
    }

    func isEnhancementsInferenceReady(for mode: IntelligenceKernelMode) -> Bool {
        enhancementsInferenceReadinessIssue(for: mode, apiKeyExists: nil) == nil
    }

    func enhancementsInferenceReadinessIssue(
        apiKeyExists: ((AIProvider) -> Bool)?,
    ) -> EnhancementsInferenceReadinessIssue? {
        enhancementsInferenceReadinessIssue(for: .meeting, apiKeyExists: apiKeyExists)
    }

    func enhancementsInferenceReadinessIssue(
        for mode: IntelligenceKernelMode,
        apiKeyExists: ((AIProvider) -> Bool)?,
        registrationAPIKeyExists: ((UUID) -> Bool)? = nil,
    ) -> EnhancementsInferenceReadinessIssue? {
        if let issue = checkEnhancementsInferenceReadiness(
            for: mode,
            apiKeyExists: apiKeyExists,
            registrationAPIKeyExists: registrationAPIKeyExists,
        ) {
            let siblingMode = siblingEnhancementsMode(for: mode)
            if let siblingIssue = checkEnhancementsInferenceReadiness(
                for: siblingMode,
                apiKeyExists: apiKeyExists,
                registrationAPIKeyExists: registrationAPIKeyExists,
            ) {
                return issue
            }
        }
        return nil
    }

    func enhancementsInferenceReadinessIssue(
        for selection: EnhancementsAISelection,
        apiKeyExists: ((AIProvider) -> Bool)?,
        registrationAPIKeyExists: ((UUID) -> Bool)? = nil,
    ) -> EnhancementsInferenceReadinessIssue? {
        checkEnhancementsInferenceReadiness(
            for: selection,
            apiKeyExists: apiKeyExists,
            registrationAPIKeyExists: registrationAPIKeyExists,
        )
    }

    private func checkEnhancementsInferenceReadiness(
        for mode: IntelligenceKernelMode,
        apiKeyExists: ((AIProvider) -> Bool)?,
        registrationAPIKeyExists: ((UUID) -> Bool)? = nil,
    ) -> EnhancementsInferenceReadinessIssue? {
        checkEnhancementsInferenceReadiness(
            for: enhancementsSelection(for: mode),
            apiKeyExists: apiKeyExists,
            registrationAPIKeyExists: registrationAPIKeyExists,
        )
    }

    private func checkEnhancementsInferenceReadiness(
        for selection: EnhancementsAISelection,
        apiKeyExists: ((AIProvider) -> Bool)?,
        registrationAPIKeyExists: ((UUID) -> Bool)? = nil,
    ) -> EnhancementsInferenceReadinessIssue? {
        let config = resolvedEnhancementsAIConfiguration(for: selection)
        let selectedRegistration = enhancementsRegistration(for: selection.registrationID)
        let provider = selectedRegistration?.provider ?? selection.provider
        let hasKey: Bool = if let registrationID = selectedRegistration?.id {
            if registrationAPIKeyExists?(registrationID) ?? KeychainManager.existsAPIKey(for: registrationID) {
                true
            } else {
                apiKeyExists?(provider) ?? KeychainManager.existsAPIKey(for: provider)
            }
        } else {
            apiKeyExists?(provider) ?? KeychainManager.existsAPIKey(for: provider)
        }
        let hasModel = !config.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard Self.isValidHTTPURLString(config.baseURL) else {
            return .invalidBaseURL
        }

        guard hasKey else {
            return .missingAPIKey
        }

        guard hasModel else {
            return .missingModel
        }

        return nil
    }

    private func siblingEnhancementsMode(for mode: IntelligenceKernelMode) -> IntelligenceKernelMode {
        switch mode {
        case .meeting: .dictation
        case .dictation, .assistant: .meeting
        }
    }

    func enhancementsSelection(for mode: IntelligenceKernelMode) -> EnhancementsAISelection {
        switch mode {
        case .meeting:
            enhancementsAISelection
        case .dictation, .assistant:
            enhancementsDictationAISelection
        }
    }

    func normalizedEnhancementsModelID(_ model: String, for provider: AIProvider) -> String {
        Self.normalizedEnhancementsModelID(model, for: provider)
    }

    static func normalizedEnhancementsModelID(_ model: String, for provider: AIProvider) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard provider == .google else { return trimmed }
        return normalizedGoogleEnhancementsModelID(trimmed)
    }

    func backfillEnhancementsSelectionModelsIfNeeded() {
        let normalizedRegistrations = Self.normalizedEnhancementsProviderRegistrationsForBackfill(
            enhancementsProviderRegistrations,
        )
        var updatedProviderSelectedModels = enhancementsProviderSelectedModels
        var updatedProviderSelectedModelsByRegistration = enhancementsProviderSelectedModelsByRegistration

        let updatedMeetingSelection = Self.withBackfilledEnhancementsModel(
            for: enhancementsAISelection,
            providerSelectedModels: &updatedProviderSelectedModels,
            providerSelectedModelsByRegistration: &updatedProviderSelectedModelsByRegistration,
            registrations: normalizedRegistrations,
            legacyConfiguration: aiConfiguration,
        )
        let updatedDictationSelection = Self.withBackfilledEnhancementsModel(
            for: enhancementsDictationAISelection,
            providerSelectedModels: &updatedProviderSelectedModels,
            providerSelectedModelsByRegistration: &updatedProviderSelectedModelsByRegistration,
            registrations: normalizedRegistrations,
            legacyConfiguration: aiConfiguration,
        )

        guard normalizedRegistrations != enhancementsProviderRegistrations
            || updatedMeetingSelection != enhancementsAISelection
            || updatedDictationSelection != enhancementsDictationAISelection
            || updatedProviderSelectedModels != enhancementsProviderSelectedModels
            || updatedProviderSelectedModelsByRegistration != enhancementsProviderSelectedModelsByRegistration
        else {
            return
        }

        enhancementsProviderRegistrations = normalizedRegistrations
        enhancementsAISelection = updatedMeetingSelection
        enhancementsDictationAISelection = updatedDictationSelection
        enhancementsProviderSelectedModels = updatedProviderSelectedModels
        enhancementsProviderSelectedModelsByRegistration = updatedProviderSelectedModelsByRegistration

        Self.persistBackfilledProviderRegistrations(enhancementsProviderRegistrations)
        Self.persistBackfilledEnhancementsSelection(enhancementsAISelection)
        Self.persistBackfilledDictationSelection(enhancementsDictationAISelection)
        Self.persistBackfilledProviderModels(enhancementsProviderSelectedModels)
        Self.persistBackfilledProviderModelsByRegistration(enhancementsProviderSelectedModelsByRegistration)
    }

    func setEnhancementsProviderSelectedModel(_ model: String, for provider: AIProvider) {
        let normalizedModel = normalizedEnhancementsModelID(model, for: provider)
        var updated = enhancementsProviderSelectedModels
        if normalizedModel.isEmpty {
            updated.removeValue(forKey: provider.rawValue)
        } else {
            updated[provider.rawValue] = normalizedModel
        }
        enhancementsProviderSelectedModels = updated

        if let registrationID = enhancementsRegistration(for: provider)?.id {
            setEnhancementsProviderSelectedModel(normalizedModel, for: registrationID)
        }
    }

    func setEnhancementsProviderSelectedModel(_ model: String, for registrationID: UUID) {
        guard let registration = enhancementsRegistration(for: registrationID) else { return }
        let normalizedModel = normalizedEnhancementsModelID(model, for: registration.provider)

        var updated = enhancementsProviderSelectedModelsByRegistration
        if normalizedModel.isEmpty {
            updated.removeValue(forKey: registrationID.uuidString)
        } else {
            updated[registrationID.uuidString] = normalizedModel
        }
        enhancementsProviderSelectedModelsByRegistration = updated
    }
}

private extension AppSettingsStore {
    static let enhancementsSelectionStorageKey = "enhancementsAISelection"
    static let enhancementsDictationSelectionStorageKey = "enhancementsDictationAISelection"
    static let enhancementsProviderModelsStorageKey = "enhancementsProviderSelectedModels"
    static let enhancementsProviderRegistrationsStorageKey = "enhancementsProviderRegistrations"
    static let enhancementsProviderModelsByRegistrationStorageKey = "enhancementsProviderSelectedModelsByRegistration"

    static func persistBackfilledEnhancementsSelection(_ selection: EnhancementsAISelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: enhancementsSelectionStorageKey)
    }

    static func persistBackfilledDictationSelection(_ selection: EnhancementsAISelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: enhancementsDictationSelectionStorageKey)
    }

    static func persistBackfilledProviderModels(_ models: [String: String]) {
        guard let data = try? JSONEncoder().encode(models) else { return }
        UserDefaults.standard.set(data, forKey: enhancementsProviderModelsStorageKey)
    }

    static func persistBackfilledProviderRegistrations(_ registrations: [EnhancementsProviderRegistration]) {
        guard let data = try? JSONEncoder().encode(registrations) else { return }
        UserDefaults.standard.set(data, forKey: enhancementsProviderRegistrationsStorageKey)
    }

    static func persistBackfilledProviderModelsByRegistration(_ models: [String: String]) {
        guard let data = try? JSONEncoder().encode(models) else { return }
        UserDefaults.standard.set(data, forKey: enhancementsProviderModelsByRegistrationStorageKey)
    }

    static func normalizedGoogleEnhancementsModelID(_ model: String) -> String {
        let withoutPrefix: String = if model.hasPrefix("models/") {
            String(model.dropFirst("models/".count))
        } else {
            model
        }

        switch withoutPrefix.lowercased() {
        case "gemini-2.0-flash-001":
            return "gemini-2.0-flash"
        default:
            return withoutPrefix
        }
    }

    static func withBackfilledEnhancementsModel(
        for selection: EnhancementsAISelection,
        providerSelectedModels: inout [String: String],
        providerSelectedModelsByRegistration: inout [String: String],
        registrations: [EnhancementsProviderRegistration],
        legacyConfiguration: AIConfiguration,
    ) -> EnhancementsAISelection {
        let registration = if let registrationID = selection.registrationID {
            registrations.first(where: { $0.id == registrationID })
        } else {
            registrations.first(where: { $0.provider == selection.provider })
        }

        let provider = registration?.provider ?? selection.provider
        let providerKey = provider.rawValue
        let normalizedSelectedModel = normalizedEnhancementsModelID(
            selection.selectedModel,
            for: provider,
        )

        if !normalizedSelectedModel.isEmpty {
            providerSelectedModels[providerKey] = normalizedSelectedModel
            if let registration {
                providerSelectedModelsByRegistration[registration.id.uuidString] = normalizedSelectedModel
            }
            return EnhancementsAISelection(
                provider: provider,
                selectedModel: normalizedSelectedModel,
                registrationID: registration?.id,
            )
        }

        if let registration,
           let registrationModel = providerSelectedModelsByRegistration[registration.id.uuidString].map({
               normalizedEnhancementsModelID($0, for: provider)
           }),
           !registrationModel.isEmpty
        {
            providerSelectedModels[providerKey] = registrationModel
            return EnhancementsAISelection(
                provider: provider,
                selectedModel: registrationModel,
                registrationID: registration.id,
            )
        }

        if let providerModel = providerSelectedModels[providerKey].map({
            normalizedEnhancementsModelID($0, for: provider)
        }),
            !providerModel.isEmpty
        {
            providerSelectedModels[providerKey] = providerModel
            if let registration {
                providerSelectedModelsByRegistration[registration.id.uuidString] = providerModel
            }
            return EnhancementsAISelection(
                provider: provider,
                selectedModel: providerModel,
                registrationID: registration?.id,
            )
        }

        let normalizedLegacyModel = normalizedEnhancementsModelID(
            legacyConfiguration.selectedModel,
            for: provider,
        )
        if legacyConfiguration.provider == provider,
           !normalizedLegacyModel.isEmpty
        {
            providerSelectedModels[providerKey] = normalizedLegacyModel
            if let registration {
                providerSelectedModelsByRegistration[registration.id.uuidString] = normalizedLegacyModel
            }
            return EnhancementsAISelection(
                provider: provider,
                selectedModel: normalizedLegacyModel,
                registrationID: registration?.id,
            )
        }

        providerSelectedModels.removeValue(forKey: providerKey)
        if let registration {
            providerSelectedModelsByRegistration.removeValue(forKey: registration.id.uuidString)
        }
        return EnhancementsAISelection(
            provider: provider,
            selectedModel: "",
            registrationID: registration?.id,
        )
    }

    static func normalizedEnhancementsProviderRegistrationsForBackfill(
        _ registrations: [EnhancementsProviderRegistration],
    ) -> [EnhancementsProviderRegistration] {
        var seenIDs = Set<UUID>()
        var seenBuiltInProviders = Set<AIProvider>()
        var normalized: [EnhancementsProviderRegistration] = []
        normalized.reserveCapacity(registrations.count)

        for var registration in registrations {
            guard seenIDs.insert(registration.id).inserted else { continue }
            registration.normalizeInPlace()

            if registration.isBuiltInSingleton,
               !seenBuiltInProviders.insert(registration.provider).inserted
            {
                continue
            }

            normalized.append(registration)
        }

        return normalized
    }
}
