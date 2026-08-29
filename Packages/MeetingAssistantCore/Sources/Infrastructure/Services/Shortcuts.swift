import Foundation
import KeyboardShortcuts

public extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording")
    static let assistantCommand = Self("assistantCommand")
    static let startMeeting = Self("startMeeting")
    static let dictationToggle = Self("dictationToggle")
    static let meetingToggle = Self("meetingToggle")
    static let meetingNotesToggle = Self(
        "meetingNotesToggle",
        default: .init(.n, modifiers: [.control, .option]),
    )

    static func assistantIntegration(_ integrationId: UUID) -> Self {
        Self("assistantIntegration.\(integrationId.uuidString)")
    }
}
