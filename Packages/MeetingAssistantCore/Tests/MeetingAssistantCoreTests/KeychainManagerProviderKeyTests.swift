@testable import MeetingAssistantCore
import XCTest

final class KeychainManagerProviderKeyTests: XCTestCase {
    func testGoogleProviderMapsToDedicatedKeychainSlot() {
        XCTAssertEqual(KeychainManager.apiKeyKey(for: .google), .aiAPIKeyGoogle)
    }
}
