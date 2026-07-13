import Foundation
import MeetingAssistantCoreCommon
import Security

/// Secure storage for sensitive data using macOS Keychain.
/// Provides type-safe API for storing and retrieving secrets.
public protocol KeychainProvider: Sendable {
    func store(_ value: String, for key: KeychainManager.Key) throws
    func retrieve(for key: KeychainManager.Key) throws -> String?
    func delete(for key: KeychainManager.Key) throws
    func exists(for key: KeychainManager.Key) -> Bool
    func retrieveAPIKey(for provider: AIProvider) throws -> String?
    func retrieveAPIKeys(for providers: [AIProvider]) throws -> [AIProvider: String]
    func existsAPIKey(for provider: AIProvider) -> Bool
    func storeAPIKey(_ value: String, for registrationID: UUID) throws
    func retrieveAPIKey(for registrationID: UUID) throws -> String?
    func retrieveAPIKeys(for registrationIDs: [UUID]) throws -> [UUID: String]
    func existsAPIKey(for registrationID: UUID) -> Bool
    func deleteAPIKey(for registrationID: UUID) throws
    func storeTranscriptionAPIKey(_ value: String, for provider: TranscriptionProvider) throws
    func retrieveTranscriptionAPIKey(for provider: TranscriptionProvider) throws -> String?
    func existsTranscriptionAPIKey(for provider: TranscriptionProvider) -> Bool
    func deleteTranscriptionAPIKey(for provider: TranscriptionProvider) throws
}

public extension KeychainProvider {
    func retrieveAPIKeys(for providers: [AIProvider]) throws -> [AIProvider: String] {
        var valuesByProvider: [AIProvider: String] = [:]

        for provider in providers {
            guard let apiKey = try retrieveAPIKey(for: provider)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !apiKey.isEmpty
            else {
                continue
            }
            valuesByProvider[provider] = apiKey
        }

        return valuesByProvider
    }

    func storeAPIKey(_ value: String, for registrationID: UUID) throws {
        try KeychainManager.storeAPIKey(value, for: registrationID)
    }

    func retrieveAPIKey(for registrationID: UUID) throws -> String? {
        try KeychainManager.retrieveAPIKey(for: registrationID)
    }

    func retrieveAPIKeys(for registrationIDs: [UUID]) throws -> [UUID: String] {
        try KeychainManager.retrieveAPIKeys(for: registrationIDs)
    }

    func existsAPIKey(for registrationID: UUID) -> Bool {
        KeychainManager.existsAPIKey(for: registrationID)
    }

    func deleteAPIKey(for registrationID: UUID) throws {
        try KeychainManager.deleteAPIKey(for: registrationID)
    }

    func storeTranscriptionAPIKey(_ value: String, for provider: TranscriptionProvider) throws {
        try KeychainManager.storeTranscriptionAPIKey(value, for: provider)
    }

    func retrieveTranscriptionAPIKey(for provider: TranscriptionProvider) throws -> String? {
        try KeychainManager.retrieveTranscriptionAPIKey(for: provider)
    }

    func existsTranscriptionAPIKey(for provider: TranscriptionProvider) -> Bool {
        KeychainManager.existsTranscriptionAPIKey(for: provider)
    }

    func deleteTranscriptionAPIKey(for provider: TranscriptionProvider) throws {
        try KeychainManager.deleteTranscriptionAPIKey(for: provider)
    }
}

public struct DefaultKeychainProvider: KeychainProvider {
    public init() {}
    public func store(_ value: String, for key: KeychainManager.Key) throws {
        try KeychainManager.store(value, for: key)
    }

    public func retrieve(for key: KeychainManager.Key) throws -> String? {
        try KeychainManager.retrieve(for: key)
    }

    public func delete(for key: KeychainManager.Key) throws {
        try KeychainManager.delete(for: key)
    }

    public func exists(for key: KeychainManager.Key) -> Bool {
        KeychainManager.exists(for: key)
    }

    public func retrieveAPIKey(for provider: AIProvider) throws -> String? {
        try KeychainManager.retrieveAPIKey(for: provider)
    }

    public func retrieveAPIKeys(for providers: [AIProvider]) throws -> [AIProvider: String] {
        try KeychainManager.retrieveAPIKeys(for: providers)
    }

    public func existsAPIKey(for provider: AIProvider) -> Bool {
        KeychainManager.existsAPIKey(for: provider)
    }

    public func storeAPIKey(_ value: String, for registrationID: UUID) throws {
        try KeychainManager.storeAPIKey(value, for: registrationID)
    }

    public func retrieveAPIKey(for registrationID: UUID) throws -> String? {
        try KeychainManager.retrieveAPIKey(for: registrationID)
    }

    public func retrieveAPIKeys(for registrationIDs: [UUID]) throws -> [UUID: String] {
        try KeychainManager.retrieveAPIKeys(for: registrationIDs)
    }

    public func existsAPIKey(for registrationID: UUID) -> Bool {
        KeychainManager.existsAPIKey(for: registrationID)
    }

    public func deleteAPIKey(for registrationID: UUID) throws {
        try KeychainManager.deleteAPIKey(for: registrationID)
    }

    public func storeTranscriptionAPIKey(_ value: String, for provider: TranscriptionProvider) throws {
        try KeychainManager.storeTranscriptionAPIKey(value, for: provider)
    }

    public func retrieveTranscriptionAPIKey(for provider: TranscriptionProvider) throws -> String? {
        try KeychainManager.retrieveTranscriptionAPIKey(for: provider)
    }

    public func existsTranscriptionAPIKey(for provider: TranscriptionProvider) -> Bool {
        KeychainManager.existsTranscriptionAPIKey(for: provider)
    }

    public func deleteTranscriptionAPIKey(for provider: TranscriptionProvider) throws {
        try KeychainManager.deleteTranscriptionAPIKey(for: provider)
    }
}

public enum KeychainManager {

    // MARK: - Constants

    private static let serviceIdentifier = AppIdentity.keychainServiceIdentifier
    private static let legacyServiceIdentifiers = AppIdentity.legacyKeychainServiceIdentifiers
    private static let providerRegistrationAccountPrefix = "ai_api_key_registration_"
    private static let consolidatedAccount = "prisma_consolidated_api_keys_v1"

    // MARK: - Cache

    private static let cacheLock = NSRecursiveLock()
    private nonisolated(unsafe) static var _consolidatedCache: ConsolidatedAPIKeys?
    private nonisolated(unsafe) static var testingConsolidatedStore: ConsolidatedAPIKeys?

    public static func invalidateCache() {
        cacheLock.withLock {
            _consolidatedCache = nil
            if AppIdentity.isRunningTests {
                testingConsolidatedStore = nil
            }
        }
    }

    // MARK: - Keys

    /// Known keys for Keychain storage.
    public enum Key: String, CaseIterable {
        case aiAPIKey = "ai_api_key"
        case aiAPIKeyOpenAI = "ai_api_key_openai"
        case aiAPIKeyAnthropic = "ai_api_key_anthropic"
        case aiAPIKeyGroq = "ai_api_key_groq"
        case aiAPIKeyGoogle = "ai_api_key_google"
        case aiAPIKeyCustom = "ai_api_key_custom"
        case transcriptionAPIKeyElevenLabs = "transcription_api_key_elevenlabs"
    }

    // MARK: - Consolidated Storage Model

    struct ConsolidatedAPIKeys: Codable {
        static let currentVersion = 1

        var version: Int = Self.currentVersion
        var providerKeys: [String: String] = [:]
        var transcriptionKeys: [String: String] = [:]
        var registrationKeys: [String: String] = [:]
        var legacyUnifiedKey: String?

        enum CodingKeys: String, CodingKey {
            case version
            case providerKeys
            case transcriptionKeys
            case registrationKeys
            case legacyUnifiedKey
        }

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
            providerKeys = try container.decodeIfPresent([String: String].self, forKey: .providerKeys) ?? [:]
            transcriptionKeys = try container.decodeIfPresent([String: String].self, forKey: .transcriptionKeys) ?? [:]
            registrationKeys = try container.decodeIfPresent([String: String].self, forKey: .registrationKeys) ?? [:]
            legacyUnifiedKey = try container.decodeIfPresent(String.self, forKey: .legacyUnifiedKey)
        }
    }

    // MARK: - Errors

    /// Errors that can occur during Keychain operations.
    public enum KeychainError: LocalizedError {
        case unableToConvertToData
        case unableToConvertFromData
        case itemNotFound
        case unexpectedStatus(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .unableToConvertToData:
                "Unable to convert string to data"
            case .unableToConvertFromData:
                "Unable to convert data to string"
            case .itemNotFound:
                "Item not found in Keychain"
            case let .unexpectedStatus(status):
                "Keychain error: \(status)"
            }
        }
    }

    // MARK: - Consolidated Storage

    private static func loadConsolidated() throws -> ConsolidatedAPIKeys {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let cache = _consolidatedCache {
            return cache
        }

        if AppIdentity.isRunningTests {
            let store = testingConsolidatedStore ?? ConsolidatedAPIKeys()
            testingConsolidatedStore = store
            _consolidatedCache = store
            return store
        }

        do {
            if let existing = try retrieveConsolidatedBlob() {
                if existing.version != ConsolidatedAPIKeys.currentVersion {
                    AppLogger.warning(
                        "Consolidated API keys version mismatch: \(existing.version) != \(ConsolidatedAPIKeys.currentVersion)",
                        category: .security,
                    )
                }
                _consolidatedCache = existing
                return existing
            }
        } catch {
            AppLogger.error(
                "Failed to decode consolidated API keys blob, will re-migrate",
                category: .security,
                error: error,
            )
        }

        let migrated = try migrateToConsolidated()
        _consolidatedCache = migrated
        return migrated
    }

    private static func saveConsolidated(_ keys: ConsolidatedAPIKeys) throws {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if AppIdentity.isRunningTests {
            testingConsolidatedStore = keys
            _consolidatedCache = keys
            return
        }

        let data = try JSONEncoder().encode(keys)
        try storeConsolidatedBlob(data)
        _consolidatedCache = keys
    }

    @discardableResult
    private static func mutateConsolidated(
        _ mutation: (inout ConsolidatedAPIKeys) throws -> Bool,
    ) throws -> Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        var consolidated = try loadConsolidated()
        let shouldSave = try mutation(&consolidated)
        guard shouldSave else { return false }

        try saveConsolidated(consolidated)
        return true
    }

    private static func retrieveConsolidatedBlob() throws -> ConsolidatedAPIKeys? {
        var query = baseQuery(account: consolidatedAccount, serviceIdentifier: serviceIdentifier)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let keys = try? JSONDecoder().decode(ConsolidatedAPIKeys.self, from: data)
            else {
                throw KeychainError.unableToConvertFromData
            }
            return keys
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func storeConsolidatedBlob(_ data: Data) throws {
        let query = baseQuery(account: consolidatedAccount, serviceIdentifier: serviceIdentifier)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            AppLogger.debug("Updated consolidated API keys blob", category: .security)
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus == errSecDuplicateItem {
                AppLogger.warning(
                    "Consolidated API keys add hit duplicate item; retrying update",
                    category: .security,
                )
                let retryStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
                guard retryStatus == errSecSuccess else {
                    AppLogger.error(
                        "Failed to retry consolidated API keys update: \(retryStatus)",
                        category: .security,
                    )
                    throw KeychainError.unexpectedStatus(retryStatus)
                }
                AppLogger.debug("Updated consolidated API keys blob after duplicate add", category: .security)
                return
            }

            guard addStatus == errSecSuccess else {
                AppLogger.error(
                    "Failed to add consolidated API keys blob: \(addStatus)",
                    category: .security,
                )
                throw KeychainError.unexpectedStatus(addStatus)
            }
            AppLogger.debug("Added consolidated API keys blob", category: .security)
        default:
            AppLogger.error(
                "Failed to update consolidated API keys blob: \(updateStatus)",
                category: .security,
            )
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    private static func migrateToConsolidated() throws -> ConsolidatedAPIKeys {
        var keys = ConsolidatedAPIKeys()
        let allServices = [serviceIdentifier] + legacyServiceIdentifiers

        for provider in AIProvider.allCases {
            let key = apiKeyKey(for: provider)
            for serviceId in allServices {
                guard let value = try retrieve(account: key.rawValue, serviceIdentifier: serviceId),
                      !value.isEmpty
                else { continue }
                keys.providerKeys[provider.rawValue] = value
                break
            }
        }

        for serviceId in allServices {
            guard let value = try retrieve(account: Key.transcriptionAPIKeyElevenLabs.rawValue, serviceIdentifier: serviceId),
                  !value.isEmpty
            else { continue }
            keys.transcriptionKeys[TranscriptionProvider.elevenLabs.rawValue] = value
            break
        }

        var hasLegacyKey = false
        for serviceId in allServices {
            if let legacyValue = try retrieve(account: Key.aiAPIKey.rawValue, serviceIdentifier: serviceId),
               !legacyValue.isEmpty
            {
                keys.legacyUnifiedKey = legacyValue
                hasLegacyKey = true
                break
            }
        }

        let hasData = !keys.providerKeys.isEmpty || !keys.transcriptionKeys.isEmpty || hasLegacyKey
        if hasData {
            try saveConsolidated(keys)

            // Best-effort cleanup: old individual keys are no longer needed,
            // but failures don't affect correctness since loadConsolidated
            // will find them on fallback and re-migrate.
            let keysToDelete = Key.allCases.filter { $0 != .aiAPIKey }
            for key in keysToDelete {
                for serviceId in allServices {
                    try? delete(account: key.rawValue, serviceIdentifier: serviceId)
                }
            }
        }

        return keys
    }

    private static func keyValue(in consolidated: ConsolidatedAPIKeys, for key: Key) -> String? {
        switch key {
        case .aiAPIKey:
            consolidated.legacyUnifiedKey
        case .aiAPIKeyOpenAI:
            consolidated.providerKeys[AIProvider.openai.rawValue]
        case .aiAPIKeyAnthropic:
            consolidated.providerKeys[AIProvider.anthropic.rawValue]
        case .aiAPIKeyGroq:
            consolidated.providerKeys[AIProvider.groq.rawValue]
        case .aiAPIKeyGoogle:
            consolidated.providerKeys[AIProvider.google.rawValue]
        case .aiAPIKeyCustom:
            consolidated.providerKeys[AIProvider.custom.rawValue]
        case .transcriptionAPIKeyElevenLabs:
            consolidated.transcriptionKeys[TranscriptionProvider.elevenLabs.rawValue]
        }
    }

    private static func setValue(_ value: String?, in consolidated: inout ConsolidatedAPIKeys, for key: Key) {
        switch key {
        case .aiAPIKey:
            consolidated.legacyUnifiedKey = value
        case .aiAPIKeyOpenAI:
            consolidated.providerKeys[AIProvider.openai.rawValue] = value
        case .aiAPIKeyAnthropic:
            consolidated.providerKeys[AIProvider.anthropic.rawValue] = value
        case .aiAPIKeyGroq:
            consolidated.providerKeys[AIProvider.groq.rawValue] = value
        case .aiAPIKeyGoogle:
            consolidated.providerKeys[AIProvider.google.rawValue] = value
        case .aiAPIKeyCustom:
            consolidated.providerKeys[AIProvider.custom.rawValue] = value
        case .transcriptionAPIKeyElevenLabs:
            consolidated.transcriptionKeys[TranscriptionProvider.elevenLabs.rawValue] = value
        }
    }

    // MARK: - Public API

    /// Store a string securely in the Keychain.
    /// - Parameters:
    ///   - value: The string value to store.
    ///   - key: The key to store the value under.
    /// - Throws: `KeychainError` if storage fails.
    static func store(_ value: String, for key: Key) throws {
        try mutateConsolidated { consolidated in
            guard keyValue(in: consolidated, for: key) != value else { return false }
            setValue(value, in: &consolidated, for: key)
            return true
        }
    }

    /// Retrieve a string from the Keychain.
    /// - Parameter key: The key to retrieve the value for.
    /// - Returns: The stored string value, or `nil` if not found.
    /// - Throws: `KeychainError` if retrieval fails for reasons other than item not found.
    static func retrieve(for key: Key) throws -> String? {
        let consolidated = try loadConsolidated()

        if let value = keyValue(in: consolidated, for: key) {
            return value
        }

        let allServices = [serviceIdentifier] + legacyServiceIdentifiers
        for serviceId in allServices {
            guard let legacyValue = try retrieve(account: key.rawValue, serviceIdentifier: serviceId),
                  !legacyValue.isEmpty
            else { continue }

            try mutateConsolidated { mutableConsolidated in
                setValue(legacyValue, in: &mutableConsolidated, for: key)
                return true
            }
            try delete(account: key.rawValue, serviceIdentifier: serviceId)
            return legacyValue
        }

        return nil
    }

    /// Delete a value from the Keychain.
    /// - Parameter key: The key to delete.
    /// - Throws: `KeychainError` if deletion fails.
    static func delete(for key: Key) throws {
        try mutateConsolidated { consolidated in
            guard keyValue(in: consolidated, for: key) != nil else { return false }
            setValue(nil, in: &consolidated, for: key)
            return true
        }
    }

    /// Check if a value exists in the Keychain.
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists, `false` otherwise.
    static func exists(for key: Key) -> Bool {
        do {
            let consolidated = try loadConsolidated()
            if keyValue(in: consolidated, for: key) != nil {
                return true
            }

            let allServices = [serviceIdentifier] + legacyServiceIdentifiers
            return allServices.contains { exists(account: key.rawValue, serviceIdentifier: $0) }
        } catch {
            return false
        }
    }

    // MARK: - Provider-specific helpers

    public static func apiKeyKey(for provider: AIProvider) -> Key {
        switch provider {
        case .openai:
            .aiAPIKeyOpenAI
        case .anthropic:
            .aiAPIKeyAnthropic
        case .groq:
            .aiAPIKeyGroq
        case .google:
            .aiAPIKeyGoogle
        case .custom:
            .aiAPIKeyCustom
        }
    }

    public static func retrieveAPIKey(for provider: AIProvider) throws -> String? {
        let providerKey = apiKeyKey(for: provider)
        if let value = try retrieve(for: providerKey), !value.isEmpty {
            return value
        }

        // Legacy unified key fallback: migrate to provider-specific slot and
        // delete the old individual entry so the fallback in retrieve(for:)
        // won't re-migrate it on subsequent calls for other providers.
        if let legacyValue = try retrieve(for: .aiAPIKey), !legacyValue.isEmpty {
            try mutateConsolidated { consolidated in
                setValue(legacyValue, in: &consolidated, for: providerKey)
                setValue(nil, in: &consolidated, for: .aiAPIKey)
                return true
            }

            let allServices = [serviceIdentifier] + legacyServiceIdentifiers
            for serviceId in allServices {
                try? delete(account: Key.aiAPIKey.rawValue, serviceIdentifier: serviceId)
            }

            return legacyValue
        }

        return nil
    }

    public static func retrieveAPIKeys(for providers: [AIProvider]) throws -> [AIProvider: String] {
        var valuesByProvider: [AIProvider: String] = [:]

        for provider in providers {
            let normalizedAPIKey = try retrieveAPIKey(for: provider)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                let apiKey = normalizedAPIKey,
                !apiKey.isEmpty
            else {
                continue
            }
            valuesByProvider[provider] = apiKey
        }

        return valuesByProvider
    }

    public static func existsAPIKey(for provider: AIProvider) -> Bool {
        let providerKey = apiKeyKey(for: provider)
        let allServices = [serviceIdentifier] + legacyServiceIdentifiers

        do {
            let consolidated = try loadConsolidated()
            if keyValue(in: consolidated, for: providerKey) != nil {
                return true
            }
            if keyValue(in: consolidated, for: .aiAPIKey) != nil {
                return true
            }
        } catch {
            return allServices.contains { exists(account: providerKey.rawValue, serviceIdentifier: $0) }
                || allServices.contains { exists(account: Key.aiAPIKey.rawValue, serviceIdentifier: $0) }
        }

        return allServices.contains { exists(account: providerKey.rawValue, serviceIdentifier: $0) }
            || allServices.contains { exists(account: Key.aiAPIKey.rawValue, serviceIdentifier: $0) }
    }

    public static func transcriptionAPIKeyKey(for provider: TranscriptionProvider) -> Key? {
        switch provider {
        case .local:
            nil
        case .groq:
            .aiAPIKeyGroq
        case .elevenLabs:
            .transcriptionAPIKeyElevenLabs
        }
    }

    public static func storeTranscriptionAPIKey(_ value: String, for provider: TranscriptionProvider) throws {
        guard let key = transcriptionAPIKeyKey(for: provider) else { return }
        try store(value, for: key)
    }

    public static func retrieveTranscriptionAPIKey(for provider: TranscriptionProvider) throws -> String? {
        guard let key = transcriptionAPIKeyKey(for: provider) else { return nil }
        return key == .aiAPIKeyGroq ? try retrieveAPIKey(for: .groq) : try retrieve(for: key)
    }

    public static func existsTranscriptionAPIKey(for provider: TranscriptionProvider) -> Bool {
        guard let key = transcriptionAPIKeyKey(for: provider) else { return true }
        return key == .aiAPIKeyGroq ? existsAPIKey(for: .groq) : exists(for: key)
    }

    public static func deleteTranscriptionAPIKey(for provider: TranscriptionProvider) throws {
        guard let key = transcriptionAPIKeyKey(for: provider) else { return }
        try delete(for: key)
    }

    public static func registrationAPIKeyAccount(for registrationID: UUID) -> String {
        "\(providerRegistrationAccountPrefix)\(registrationID.uuidString.lowercased())"
    }

    public static func storeAPIKey(_ value: String, for registrationID: UUID) throws {
        let account = registrationAPIKeyAccount(for: registrationID)
        try mutateConsolidated { consolidated in
            guard consolidated.registrationKeys[account] != value else { return false }
            consolidated.registrationKeys[account] = value
            return true
        }

        for serviceId in [serviceIdentifier] + legacyServiceIdentifiers {
            try? delete(account: account, serviceIdentifier: serviceId)
        }
    }

    public static func retrieveAPIKey(for registrationID: UUID) throws -> String? {
        let account = registrationAPIKeyAccount(for: registrationID)

        let consolidated = try loadConsolidated()
        if let value = consolidated.registrationKeys[account], !value.isEmpty {
            return value
        }

        for serviceId in [serviceIdentifier] + legacyServiceIdentifiers {
            guard let legacyValue = try retrieve(account: account, serviceIdentifier: serviceId),
                  !legacyValue.isEmpty
            else {
                continue
            }

            try mutateConsolidated { mutableConsolidated in
                mutableConsolidated.registrationKeys[account] = legacyValue
                return true
            }
            try? delete(account: account, serviceIdentifier: serviceId)
            return legacyValue
        }

        return nil
    }

    public static func retrieveAPIKeys(for registrationIDs: [UUID]) throws -> [UUID: String] {
        let consolidated = try loadConsolidated()
        var mutableConsolidated = consolidated
        var valuesByRegistrationID: [UUID: String] = [:]
        var migratedAccounts: [(account: String, serviceIdentifier: String)] = []

        for registrationID in registrationIDs {
            let account = registrationAPIKeyAccount(for: registrationID)
            let consolidatedValue = mutableConsolidated.registrationKeys[account]
            let legacyValue: String?

            if consolidatedValue == nil {
                legacyValue = try legacyRegistrationAPIKey(for: account, migratedAccounts: &migratedAccounts)
                if let legacyValue, !legacyValue.isEmpty {
                    mutableConsolidated.registrationKeys[account] = legacyValue
                }
            } else {
                legacyValue = nil
            }

            let normalizedAPIKey = (consolidatedValue ?? legacyValue)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                let apiKey = normalizedAPIKey,
                !apiKey.isEmpty
            else {
                continue
            }
            valuesByRegistrationID[registrationID] = apiKey
        }

        if mutableConsolidated.registrationKeys != consolidated.registrationKeys {
            try mutateConsolidated { consolidated in
                for migratedAccount in migratedAccounts {
                    consolidated.registrationKeys[migratedAccount.account] =
                        mutableConsolidated.registrationKeys[migratedAccount.account]
                }
                return true
            }
            for migratedAccount in migratedAccounts {
                try? delete(account: migratedAccount.account, serviceIdentifier: migratedAccount.serviceIdentifier)
            }
        }

        return valuesByRegistrationID
    }

    public static func existsAPIKey(for registrationID: UUID) -> Bool {
        let account = registrationAPIKeyAccount(for: registrationID)
        do {
            let consolidated = try loadConsolidated()
            if consolidated.registrationKeys[account] != nil {
                return true
            }
        } catch {
            return exists(account: account, serviceIdentifier: serviceIdentifier)
                || legacyServiceIdentifiers.contains {
                    exists(account: account, serviceIdentifier: $0)
                }
        }

        if exists(account: account, serviceIdentifier: serviceIdentifier) {
            return true
        }
        return legacyServiceIdentifiers.contains {
            exists(account: account, serviceIdentifier: $0)
        }
    }

    public static func deleteAPIKey(for registrationID: UUID) throws {
        let account = registrationAPIKeyAccount(for: registrationID)
        try mutateConsolidated { consolidated in
            consolidated.registrationKeys.removeValue(forKey: account) != nil
        }

        if AppIdentity.isRunningTests {
            return
        }

        try delete(account: account, serviceIdentifier: serviceIdentifier)
        for legacyServiceIdentifier in legacyServiceIdentifiers {
            try delete(account: account, serviceIdentifier: legacyServiceIdentifier)
        }
    }

    private static func legacyRegistrationAPIKey(
        for account: String,
        migratedAccounts: inout [(account: String, serviceIdentifier: String)],
    ) throws -> String? {
        for serviceId in [serviceIdentifier] + legacyServiceIdentifiers {
            guard let legacyValue = try retrieve(account: account, serviceIdentifier: serviceId),
                  !legacyValue.isEmpty
            else {
                continue
            }

            migratedAccounts.append((account, serviceId))
            return legacyValue
        }

        return nil
    }

    private static func retrieve(for key: Key, serviceIdentifier: String) throws -> String? {
        try retrieve(account: key.rawValue, serviceIdentifier: serviceIdentifier)
    }

    private static func retrieve(account: String, serviceIdentifier: String) throws -> String? {
        var query = baseQuery(account: account, serviceIdentifier: serviceIdentifier)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8)
            else {
                throw KeychainError.unableToConvertFromData
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func delete(for key: Key, serviceIdentifier: String) throws {
        try delete(account: key.rawValue, serviceIdentifier: serviceIdentifier)
    }

    private static func delete(account: String, serviceIdentifier: String) throws {
        let query = baseQuery(account: account, serviceIdentifier: serviceIdentifier)
        let status = SecItemDelete(query as CFDictionary)

        // Treat "not found" as success (nothing to delete)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func exists(for key: Key, serviceIdentifier: String) -> Bool {
        exists(account: key.rawValue, serviceIdentifier: serviceIdentifier)
    }

    private static func exists(account: String, serviceIdentifier: String) -> Bool {
        var query = baseQuery(account: account, serviceIdentifier: serviceIdentifier)
        query[kSecReturnData as String] = false
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private static func baseQuery(for key: Key, serviceIdentifier: String) -> [String: Any] {
        baseQuery(account: key.rawValue, serviceIdentifier: serviceIdentifier)
    }

    private static func baseQuery(account: String, serviceIdentifier: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account,
        ]
    }

}

public extension KeychainManager {
    @available(*, deprecated, message: "Use retrieveAPIKeys(for:) or retrieveAPIKeysMap(allowedProviders:) instead")
    static func mapAPIKeyItems(
        _ items: [[String: Any]],
        allowedProviders: [AIProvider],
    ) -> [AIProvider: String] {
        let accountToProvider = Dictionary(uniqueKeysWithValues: allowedProviders.map {
            (apiKeyKey(for: $0).rawValue, $0)
        })
        var valuesByProvider: [AIProvider: String] = [:]

        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  let provider = accountToProvider[account],
                  let rawData = item[kSecValueData as String] as? Data,
                  let rawValue = String(data: rawData, encoding: .utf8)
            else {
                continue
            }

            let apiKey = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !apiKey.isEmpty else { continue }
            valuesByProvider[provider] = apiKey
        }

        return valuesByProvider
    }

    /// Reads API keys from consolidated storage for the given providers.
    /// This is the consolidated-aware replacement for `mapAPIKeyItems(allowedProviders:)`.
    static func retrieveAPIKeysMap(allowedProviders: [AIProvider]) throws -> [AIProvider: String] {
        let consolidated = try loadConsolidated()
        var valuesByProvider: [AIProvider: String] = [:]

        for provider in allowedProviders {
            let key = apiKeyKey(for: provider)
            let apiKey = keyValue(in: consolidated, for: key)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let apiKey, !apiKey.isEmpty else { continue }
            valuesByProvider[provider] = apiKey
        }

        return valuesByProvider
    }
}
