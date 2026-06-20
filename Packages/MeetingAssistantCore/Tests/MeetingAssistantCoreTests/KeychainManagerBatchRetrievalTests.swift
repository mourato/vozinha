@testable import MeetingAssistantCore
import Security
import XCTest

final class KeychainManagerBatchRetrievalTests: XCTestCase {
    override func setUp() {
        super.setUp()
        KeychainManager.invalidateCache()
    }

    func testProviderAPIKey_CanOverwriteExistingConsolidatedValue() throws {
        let keychain = DefaultKeychainProvider()
        let key = KeychainManager.apiKeyKey(for: .groq)

        try? keychain.delete(for: key)
        defer { try? keychain.delete(for: key) }

        try keychain.store("sk-groq-initial", for: key)
        try keychain.store("sk-groq-updated", for: key)

        XCTAssertEqual(try keychain.retrieveAPIKey(for: .groq), "sk-groq-updated")
    }

    func testRegistrationAPIKeyAccount_IsStableLowercaseKey() throws {
        let registrationID = try XCTUnwrap(UUID(uuidString: "9E6F0DB4-7B48-4599-A7C5-47CB7C2F368A"))

        XCTAssertEqual(
            KeychainManager.registrationAPIKeyAccount(for: registrationID),
            "ai_api_key_registration_9e6f0db4-7b48-4599-a7c5-47cb7c2f368a"
        )
    }

    func testTranscriptionAPIKeyKey_UsesSharedGroqKey() {
        XCTAssertEqual(KeychainManager.transcriptionAPIKeyKey(for: .groq), .aiAPIKeyGroq)
    }

    func testTranscriptionAPIKeyKey_UsesElevenLabsTranscriptionKey() {
        XCTAssertEqual(
            KeychainManager.transcriptionAPIKeyKey(for: .elevenLabs),
            .transcriptionAPIKeyElevenLabs
        )
    }

    func testTranscriptionAPIKeyKey_ReturnsNilForLocalProvider() {
        XCTAssertNil(KeychainManager.transcriptionAPIKeyKey(for: .local))
    }

    func testRegistrationAPIKeys_StoreRetrieveBatchAndDelete() throws {
        let registrationID = UUID()
        let apiKey = "sk-registration-\(registrationID.uuidString)"
        try? KeychainManager.deleteAPIKey(for: registrationID)
        defer { try? KeychainManager.deleteAPIKey(for: registrationID) }

        try KeychainManager.storeAPIKey(apiKey, for: registrationID)

        XCTAssertTrue(KeychainManager.existsAPIKey(for: registrationID))
        XCTAssertEqual(try KeychainManager.retrieveAPIKey(for: registrationID), apiKey)
        XCTAssertEqual(try KeychainManager.retrieveAPIKeys(for: [registrationID]), [registrationID: apiKey])

        try KeychainManager.deleteAPIKey(for: registrationID)

        XCTAssertFalse(KeychainManager.existsAPIKey(for: registrationID))
        XCTAssertNil(try KeychainManager.retrieveAPIKey(for: registrationID))
        XCTAssertEqual(try KeychainManager.retrieveAPIKeys(for: [registrationID]), [:])
    }

    func testMapAPIKeyItems_MapsKnownProviderAccounts() {
        let items: [[String: Any]] = [
            [
                kSecAttrAccount as String: KeychainManager.Key.aiAPIKeyOpenAI.rawValue,
                kSecValueData as String: Data("sk-openai".utf8),
            ],
            [
                kSecAttrAccount as String: KeychainManager.Key.aiAPIKeyGoogle.rawValue,
                kSecValueData as String: Data("sk-google".utf8),
            ],
        ]

        let mapped = KeychainManager.mapAPIKeyItems(items, allowedProviders: [.openai, .google, .anthropic])

        XCTAssertEqual(mapped[.openai], "sk-openai")
        XCTAssertEqual(mapped[.google], "sk-google")
        XCTAssertNil(mapped[.anthropic])
    }

    func testMapAPIKeyItems_IgnoresUnknownAccounts() {
        let items: [[String: Any]] = [
            [
                kSecAttrAccount as String: "unknown_account",
                kSecValueData as String: Data("ignored".utf8),
            ],
            [
                kSecAttrAccount as String: KeychainManager.Key.aiAPIKeyAnthropic.rawValue,
                kSecValueData as String: Data("sk-anthropic".utf8),
            ],
        ]

        let mapped = KeychainManager.mapAPIKeyItems(items, allowedProviders: [.openai, .anthropic])

        XCTAssertEqual(mapped.count, 1)
        XCTAssertEqual(mapped[.anthropic], "sk-anthropic")
        XCTAssertNil(mapped[.openai])
    }

    func testMapAPIKeyItems_ReturnsEmptyForEmptyInput() {
        let mapped = KeychainManager.mapAPIKeyItems([], allowedProviders: [.openai, .google])
        XCTAssertTrue(mapped.isEmpty)
    }
}
