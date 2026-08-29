import Combine
import KeyboardShortcuts
import MeetingAssistantCore

@MainActor
final class MeetingNotesPaneShortcutController {
    private let paneController: MeetingNotesPaneController
    private let settings: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(
        paneController: MeetingNotesPaneController,
        settings: AppSettingsStore = .shared,
    ) {
        self.paneController = paneController
        self.settings = settings
    }

    func start() {
        KeyboardShortcuts.onKeyDown(for: .meetingNotesToggle) { [weak self] in
            Task { @MainActor in
                self?.handleHotkey()
            }
        }

        settings.$meetingNotesHotkeyEnabled
            .sink { [weak self] enabled in
                if enabled {
                    KeyboardShortcuts.enable(.meetingNotesToggle)
                } else {
                    KeyboardShortcuts.disable(.meetingNotesToggle)
                }
            }
            .store(in: &cancellables)

        if settings.meetingNotesHotkeyEnabled {
            KeyboardShortcuts.enable(.meetingNotesToggle)
        } else {
            KeyboardShortcuts.disable(.meetingNotesToggle)
        }
    }

    private func handleHotkey() {
        guard settings.meetingNotesHotkeyEnabled else { return }
        paneController.toggle()
    }
}
