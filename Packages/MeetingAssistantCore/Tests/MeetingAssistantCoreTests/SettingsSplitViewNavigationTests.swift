@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreUI
import SwiftUI
import XCTest

final class SettingsSplitViewNavigationTests: XCTestCase {
    func testPrimarySectionsContainExpectedTabs() {
        let expectedSections: [SettingsSection] = [
            .activity,
            .modes,
            .meetings,
            .history,
            .dictionary,
        ]
        XCTAssertEqual(SettingsSection.primarySections, expectedSections)
    }

    func testSystemSectionIsAvailable() {
        XCTAssertEqual(SettingsSection.settingsSections, [.system])
    }

    func testAllPrimaryAndSystemSectionsHaveValidDestinations() {
        let allSidebarSections = SettingsSection.primarySections + [SettingsSection.system]
        for section in allSidebarSections {
            let destination = section.destination
            XCTAssertEqual(destination.section, section)
            XCTAssertFalse(section.title.isEmpty)
            XCTAssertFalse(section.icon.isEmpty)
            XCTAssertFalse(section.selectedSidebarIcon.isEmpty)
        }
    }

    func testAllSectionsProvideValidBadgeStyling() {
        for section in SettingsSection.allCases {
            _ = section.badgeColor
            _ = section.badgeGradient
        }
    }
}
