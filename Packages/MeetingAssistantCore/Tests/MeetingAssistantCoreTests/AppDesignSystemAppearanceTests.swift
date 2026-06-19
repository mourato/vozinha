import AppKit
@testable import MeetingAssistantCoreUI
import XCTest

final class AppDesignSystemAppearanceTests: XCTestCase {
    func testIsDarkAppearanceRecognizesAquaVariants() {
        XCTAssertFalse(AppDesignSystem.Colors.isDarkAppearance(NSAppearance(named: .aqua)!))
        XCTAssertTrue(AppDesignSystem.Colors.isDarkAppearance(NSAppearance(named: .darkAqua)!))
    }

    func testResolveColorRunsProviderInsideRequestedAppearance() {
        let darkAppearance = NSAppearance(named: .darkAqua)!
        let lightAppearance = NSAppearance(named: .aqua)!

        let darkResolved = AppDesignSystem.Colors.resolveColor(in: darkAppearance) {
            AppDesignSystem.Colors.isDarkAppearance(NSAppearance.currentDrawing())
                ? NSColor.black
                : NSColor.white
        }

        let lightResolved = AppDesignSystem.Colors.resolveColor(in: lightAppearance) {
            AppDesignSystem.Colors.isDarkAppearance(NSAppearance.currentDrawing())
                ? NSColor.black
                : NSColor.white
        }

        XCTAssertEqual(darkResolved, NSColor.black)
        XCTAssertEqual(lightResolved, NSColor.white)
    }
}
