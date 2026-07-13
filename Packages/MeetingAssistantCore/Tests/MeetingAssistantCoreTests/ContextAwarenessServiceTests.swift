import Foundation
@testable import MeetingAssistantCore
import XCTest

@MainActor
final class ContextAwarenessServiceTests: XCTestCase {
    func testIsCaptureBlocked_ReturnsTrueForDefaultSensitiveBundleID() {
        let blocked = ContextAwarenessPrivacy.isCaptureBlocked(
            bundleIdentifier: "com.1password.1password",
            excludedBundleIDs: [],
        )

        XCTAssertTrue(blocked)
    }

    func testIsCaptureBlocked_ReturnsTrueForCustomExcludedBundleID() {
        let blocked = ContextAwarenessPrivacy.isCaptureBlocked(
            bundleIdentifier: "com.example.secureapp",
            excludedBundleIDs: ["com.example.secureapp"],
        )

        XCTAssertTrue(blocked)
    }

    func testIsCaptureBlocked_ReturnsFalseForRegularBundleID() {
        let blocked = ContextAwarenessPrivacy.isCaptureBlocked(
            bundleIdentifier: "com.apple.safari",
            excludedBundleIDs: [],
        )

        XCTAssertFalse(blocked)
    }

    func testRedactSensitiveText_RedactsEmailURLSecretAndLongNumber() {
        let input = """
        Contact me at user@example.com.
        See https://example.com/path.
        Token: sk_abcdefghijklmnopqrstuvwxyz123456.
        Card: 4111 1111 1111 1111.
        """

        let output = ContextAwarenessPrivacy.redactSensitiveText(input)

        XCTAssertEqual(output?.contains("user@example.com"), false)
        XCTAssertEqual(output?.contains("https://example.com/path"), false)
        XCTAssertEqual(output?.contains("sk_abcdefghijklmnopqrstuvwxyz123456"), false)
        XCTAssertEqual(output?.contains("4111 1111 1111 1111"), false)

        XCTAssertEqual(output?.contains("[REDACTED_EMAIL]"), true)
        XCTAssertEqual(output?.contains("[REDACTED_URL]"), true)
        XCTAssertEqual(output?.contains("[REDACTED_SECRET]"), true)
        XCTAssertEqual(output?.contains("[REDACTED_NUMBER]"), true)
    }
}
