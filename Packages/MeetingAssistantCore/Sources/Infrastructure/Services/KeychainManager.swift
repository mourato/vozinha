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

    // MARK: - Keys

    /// Known keys for Keychain storage.
    public enum Key: String {
        case aiAPIKey = "ai_api_key"
        case aiAPIKeyOpenAI = "ai_api_key_openai"
        case aiAPIKeyAnthropic = "ai_api_key_anthropic"
        case aiAPIKeyGroq = "ai_api_key_groq"
        case aiAPIKeyGoogle = "ai_api_key_google"
        case aiAPIKeyCustom = "ai_api_key_custom"
        case transcriptionAPIKeyElevenLabs = "transcription_api_key_elevenlabs"
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

    // MARK: - Public API

    /// Store a string securely in the Keychain.
    /// - Parameters:
    ///   - value: The string value to store.
    ///   - key: The key to store the value under.
    /// - Throws: `KeychainError` if storage fails.
    static func store(_ value: String, for key: Key) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.unableToConvertToData
        }

        let query = baseQuery(for: key, serviceIdentifier: serviceIdentifier)

        // Delete existing item if present (including legacy services).
        SecItemDelete(query as CFDictionary)
        for legacyServiceIdentifier in legacyServiceIdentifiers {
            let legacyQuery = baseQuery(for: key, serviceIdentifier: legacyServiceIdentifier)
            SecItemDelete(legacyQuery as CFDictionary)
        }

        // Add new item
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Retrieve a string from the Keychain.
    /// - Parameter key: The key to retrieve the value for.
    /// - Returns: The stored string value, or `nil` if not found.
    /// - Throws: `KeychainError` if retrieval fails for reasons other than item not found.
    static func retrieve(for key: Key) throws -> String? {
        if let value = try retrieve(for: key, serviceIdentifier: serviceIdentifier) {
            return value
        }

        for legacyServiceIdentifier in legacyServiceIdentifiers {
            guard let legacyValue = try retrieve(for: key, serviceIdentifier: legacyServiceIdentifier) else {
                continue
            }

            try store(legacyValue, for: key)
            try delete(for: key, serviceIdentifier: legacyServiceIdentifier)
            return legacyValue
        }

        return nil
    }

    /// Delete a value from the Keychain.
    /// - Parameter key: The key to delete.
    /// - Throws: `KeychainError` if deletion fails.
    static func delete(for key: Key) throws {
        try delete(for: key, serviceIdentifier: serviceIdentifier)
        for legacyServiceIdentifier in legacyServiceIdentifiers {
            try delete(for: key, serviceIdentifier: legacyServiceIdentifier)
        }
    }

    /// Check if a value exists in the Keychain.
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists, `false` otherwise.
    static func exists(for key: Key) -> Bool {
        if exists(for: key, serviceIdentifier: serviceIdentifier) {
            return true
        }
        return legacyServiceIdentifiers.contains { exists(for: key, serviceIdentifier: $0) }
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

        // Legacy fallback
        if let legacyValue = try retrieve(for: .aiAPIKey), !legacyValue.isEmpty {
            try store(legacyValue, for: providerKey)
            try delete(for: .aiAPIKey)
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
        if exists(for: providerKey) {
            return true
        }
        return exists(for: .aiAPIKey)
    }

    public static func storeTranscriptionAPIKey(_ value: String, for provider: TranscriptionProvider) throws {
        switch provider {
        case .local:
            return
        case .groq:
            try store(value, for: .aiAPIKeyGroq)
        case .elevenLabs:
            try store(value, for: .transcriptionAPIKeyElevenLabs)
        }
    }

    public static func retrieveTranscriptionAPIKey(for provider: TranscriptionProvider) throws -> String? {
        switch provider {
        case .local:
            return nil
        case .groq:
            return try retrieveAPIKey(for: .groq)
        case .elevenLabs:
            return try retrieve(for: .transcriptionAPIKeyElevenLabs)
        }
    }

    public static func existsTranscriptionAPIKey(for provider: TranscriptionProvider) -> Bool {
        switch provider {
        case .local:
            return true
        case .groq:
            return existsAPIKey(for: .groq)
        case .elevenLabs:
            return exists(for: .transcriptionAPIKeyElevenLabs)
        }
    }

    public static func deleteTranscriptionAPIKey(for provider: TranscriptionProvider) throws {
        switch provider {
        case .local:
            return
        case .groq:
            try delete(for: .aiAPIKeyGroq)
        case .elevenLabs:
            try delete(for: .transcriptionAPIKeyElevenLabs)
        }
    }

    public static func registrationAPIKeyAccount(for registrationID: UUID) -> String {
        "\(providerRegistrationAccountPrefix)\(registrationID.uuidString.lowercased())"
    }

    public static func storeAPIKey(_ value: String, for registrationID: UUID) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.unableToConvertToData
        }

        let account = registrationAPIKeyAccount(for: registrationID)
        let query = baseQuery(account: account, serviceIdentifier: serviceIdentifier)

        SecItemDelete(query as CFDictionary)
        for legacyServiceIdentifier in legacyServiceIdentifiers {
            let legacyQuery = baseQuery(account: account, serviceIdentifier: legacyServiceIdentifier)
            SecItemDelete(legacyQuery as CFDictionary)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public static func retrieveAPIKey(for registrationID: UUID) throws -> String? {
        let account = registrationAPIKeyAccount(for: registrationID)

        if let value = try retrieve(account: account, serviceIdentifier: serviceIdentifier), !value.isEmpty {
            return value
        }

        for legacyServiceIdentifier in legacyServiceIdentifiers {
            guard let legacyValue = try retrieve(account: account, serviceIdentifier: legacyServiceIdentifier),
                  !legacyValue.isEmpty
            else {
                continue
            }

            try storeAPIKey(legacyValue, for: registrationID)
            try delete(account: account, serviceIdentifier: legacyServiceIdentifier)
            return legacyValue
        }

        return nil
    }

    public static func retrieveAPIKeys(for registrationIDs: [UUID]) throws -> [UUID: String] {
        var valuesByRegistrationID: [UUID: String] = [:]

        for registrationID in registrationIDs {
            let normalizedAPIKey = try retrieveAPIKey(for: registrationID)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                let apiKey = normalizedAPIKey,
                !apiKey.isEmpty
            else {
                continue
            }
            valuesByRegistrationID[registrationID] = apiKey
        }

        return valuesByRegistrationID
    }

    public static func existsAPIKey(for registrationID: UUID) -> Bool {
        let account = registrationAPIKeyAccount(for: registrationID)
        if exists(account: account, serviceIdentifier: serviceIdentifier) {
            return true
        }
        return legacyServiceIdentifiers.contains {
            exists(account: account, serviceIdentifier: $0)
        }
    }

    public static func deleteAPIKey(for registrationID: UUID) throws {
        let account = registrationAPIKeyAccount(for: registrationID)
        try delete(account: account, serviceIdentifier: serviceIdentifier)
        for legacyServiceIdentifier in legacyServiceIdentifiers {
            try delete(account: account, serviceIdentifier: legacyServiceIdentifier)
        }
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

    public static func mapAPIKeyItems(
        _ items: [[String: Any]],
        allowedProviders: [AIProvider]
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
}
