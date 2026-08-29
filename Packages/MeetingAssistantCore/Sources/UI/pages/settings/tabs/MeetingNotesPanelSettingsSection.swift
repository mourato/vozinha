import KeyboardShortcuts
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

struct MeetingNotesPanelSettingsSection: View {
    @ObservedObject var settings: AppSettingsStore

    var body: some View {
        Section {
            Toggle("settings.meetings.notes_panel.hotkey_enabled".localized, isOn: $settings.meetingNotesHotkeyEnabled)
                .toggleStyle(.switch)

            if settings.meetingNotesHotkeyEnabled {
                DSShortcutRecorderRow(label: "settings.meetings.notes_panel.shortcut".localized) {
                    KeyboardShortcuts.Recorder(for: .meetingNotesToggle)
                }
            }

            Toggle("settings.meetings.notes_panel.translucent".localized, isOn: $settings.meetingNotesTranslucentPanel)
                .toggleStyle(.switch)
            Toggle("settings.meetings.notes_panel.all_spaces".localized, isOn: $settings.meetingNotesShowOnAllSpaces)
                .toggleStyle(.switch)
            Toggle("settings.meetings.notes_panel.hide_from_capture".localized, isOn: $settings.meetingNotesHideFromScreenCapture)
                .toggleStyle(.switch)
            Toggle("settings.meetings.notes_panel.auto_height".localized, isOn: $settings.meetingNotesAutoSizeHeight)
                .toggleStyle(.switch)

            Picker("settings.meetings.notes_panel.text_size".localized, selection: $settings.meetingNotesTextSize) {
                ForEach(Array(AppSettingsStore.meetingNotesTextSizeRange), id: \.self) { size in
                    Text("\(size)").tag(size)
                }
            }
            .pickerStyle(.menu)
        } header: {
            SettingsFormSectionHeader(title: "settings.meetings.notes_panel.title".localized, icon: "note.text")
        } footer: {
            Text("settings.meetings.notes_panel.desc".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
#Preview {
    Form {
        MeetingNotesPanelSettingsSection(settings: .shared)
    }
    .frame(width: 620)
}
#endif
