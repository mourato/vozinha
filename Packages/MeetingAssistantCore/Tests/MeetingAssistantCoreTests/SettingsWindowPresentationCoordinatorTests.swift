import AppKit
@testable import MeetingAssistantCoreInfrastructure
import XCTest

@MainActor
final class SettingsWindowPresenterTests: XCTestCase {

    func testOpenSettingsActivatesAndOpensWhenAlreadyRegular() {
        let harness = PresentationHarness(policy: .regular)

        harness.coordinator.registerOpenWindowHandler {
            harness.events.append(.openWindow)
        }
        harness.coordinator.openSettings()

        XCTAssertEqual(harness.events, [.activate, .openWindow, .focusWindow])
        XCTAssertEqual(harness.policy, .regular)
    }

    func testOpenSettingsPromotesAccessoryBeforeOpening() {
        let harness = PresentationHarness(policy: .accessory)

        harness.coordinator.registerOpenWindowHandler {
            harness.events.append(.openWindow)
        }
        harness.coordinator.openSettings()

        XCTAssertEqual(harness.events, [.setRegular, .activate, .openWindow, .focusWindow])
        XCTAssertEqual(harness.policy, .regular)
    }

    func testCloseRestoresAccessoryWhenDockPreferenceIsOff() {
        let harness = PresentationHarness(policy: .regular)

        harness.coordinator.settingsWindowDidClose(
            showInDock: false,
            hasOtherVisibleNormalWindow: false
        )

        XCTAssertEqual(harness.events, [.setAccessory])
        XCTAssertEqual(harness.policy, .accessory)
    }

    func testCloseDoesNotRestoreAccessoryWhenDockPreferenceIsOn() {
        let harness = PresentationHarness(policy: .regular)

        harness.coordinator.settingsWindowDidClose(
            showInDock: true,
            hasOtherVisibleNormalWindow: false
        )

        XCTAssertEqual(harness.events, [])
        XCTAssertEqual(harness.policy, .regular)
    }

    func testCloseDoesNotRestoreAccessoryWhenAnotherNormalWindowIsVisible() {
        let harness = PresentationHarness(policy: .regular)

        harness.coordinator.settingsWindowDidClose(
            showInDock: false,
            hasOtherVisibleNormalWindow: true
        )

        XCTAssertEqual(harness.events, [])
        XCTAssertEqual(harness.policy, .regular)
    }

    func testApplicationReopenRequestsSettingsWhenRegularWithNoVisibleWindows() {
        let harness = PresentationHarness(policy: .regular)

        harness.coordinator.registerOpenWindowHandler {
            harness.events.append(.openWindow)
        }
        let handled = harness.coordinator.handleApplicationReopen(hasVisibleWindows: false)

        XCTAssertTrue(handled)
        XCTAssertEqual(harness.events, [.activate, .openWindow, .focusWindow])
    }

    func testApplicationReopenDoesNotRequestSettingsWhenVisibleWindowExists() {
        let harness = PresentationHarness(policy: .regular)

        harness.coordinator.registerOpenWindowHandler {
            harness.events.append(.openWindow)
        }
        let handled = harness.coordinator.handleApplicationReopen(hasVisibleWindows: true)

        XCTAssertFalse(handled)
        XCTAssertEqual(harness.events, [])
    }
}

@MainActor
private final class PresentationHarness {
    enum Event: Equatable {
        case setRegular
        case setAccessory
        case activate
        case openWindow
        case focusWindow
    }

    var policy: NSApplication.ActivationPolicy
    var events: [Event] = []
    lazy var coordinator = SettingsWindowPresentationCoordinator(
        activationPolicy: { [weak self] in
            self?.policy ?? .accessory
        },
        setActivationPolicy: { [weak self] policy in
            self?.policy = policy
            switch policy {
            case .regular:
                self?.events.append(.setRegular)
            case .accessory:
                self?.events.append(.setAccessory)
            case .prohibited:
                break
            @unknown default:
                break
            }
        },
        activateApp: { [weak self] in
            self?.events.append(.activate)
        },
        focusSettingsWindow: { [weak self] in
            self?.events.append(.focusWindow)
        }
    )

    init(policy: NSApplication.ActivationPolicy) {
        self.policy = policy
    }
}
