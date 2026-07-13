import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - General Settings Tab

/// Main tab for core application settings like language, appearance, and storage.
public struct GeneralSettingsTab: View {
    @State private var viewModel = GeneralSettingsViewModel()
    @StateObject private var recordingCancelShortcutViewModel = RecordingCancelShortcutSettingsViewModel()
    @State private var shortcutDoubleTapIntervalInput = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let showsHeader: Bool
    private let headerTitleKey: String
    private let headerDescriptionKey: String
    private let openModels: (() -> Void)?
    private let openDictionary: (() -> Void)?
    private let openSound: (() -> Void)?
    private let openProtectedApps: (() -> Void)?
    private let openPermissions: (() -> Void)?

    public init(
        showsHeader: Bool = true,
        headerTitleKey: String = "settings.general.title",
        headerDescriptionKey: String = "settings.general.language_desc",
        openModels: (() -> Void)? = nil,
        openDictionary: (() -> Void)? = nil,
        openSound: (() -> Void)? = nil,
        openProtectedApps: (() -> Void)? = nil,
        openPermissions: (() -> Void)? = nil,
    ) {
        self.showsHeader = showsHeader
        self.headerTitleKey = headerTitleKey
        self.headerDescriptionKey = headerDescriptionKey
        self.openModels = openModels
        self.openDictionary = openDictionary
        self.openSound = openSound
        self.openProtectedApps = openProtectedApps
        self.openPermissions = openPermissions
    }

    public var body: some View {
        SettingsScrollableContent {
            if showsHeader {
                SettingsSectionHeader(
                    title: headerTitleKey.localized,
                    description: headerDescriptionKey.localized,
                )
            }

            systemDrilldownsSection

            // Application Behavior
            SettingsListGroup("settings.general.app_behavior".localized, icon: "app.badge") {
                DSToggleRow(
                    "settings.general.launch_at_login".localized,
                    isOn: $viewModel.launchAtLogin,
                )

                DSToggleRow(
                    "settings.general.show_in_dock".localized,
                    description: "settings.general.show_in_dock_desc".localized,
                    isOn: $viewModel.showInDock,
                )

                DSToggleRow(
                    "settings.general.show_settings_on_launch".localized,
                    isOn: $viewModel.showSettingsOnLaunch,
                )

                HStack(alignment: .center, spacing: 12) {
                    SettingsTitleWithPopover(
                        title: "settings.general.shortcut_double_tap_interval".localized,
                        helperMessage: "settings.general.shortcut_double_tap_interval_desc".localized,
                    )

                    Spacer()

                    HStack(spacing: 8) {
                        TextField("", text: $shortcutDoubleTapIntervalInput)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 84)
                            .onChange(of: shortcutDoubleTapIntervalInput) { _, newValue in
                                applyShortcutDoubleTapIntervalInput(newValue)
                            }
                            .onSubmit {
                                syncShortcutDoubleTapIntervalInputFromModel()
                            }

                        Text("ms")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    SettingsTitleWithPopover(
                        title: "settings.general.cancel_recording_shortcut".localized,
                        helperMessage: "settings.general.cancel_recording_shortcut_desc".localized,
                    )

                    Spacer()

                    DSModifierShortcutEditor(
                        shortcut: $recordingCancelShortcutViewModel.cancelRecordingShortcutDefinition,
                        conflictMessage: recordingCancelShortcutViewModel.cancelRecordingShortcutConflictMessage,
                        showsTitle: false,
                        maxInputWidth: AppDesignSystem.Layout.maxCompactTextFieldWidth,
                    )
                }
            }

            // Appearance
            SettingsListGroup("settings.general.appearance".localized, icon: "paintbrush.fill") {
                HStack {
                    Text("settings.general.language".localized)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    DSMenuPicker(selection: $viewModel.selectedLanguage) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                }

                HStack {
                    Text("settings.general.appearance.theme".localized)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Picker("", selection: $viewModel.appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }
            }

            recordingIndicatorSection

            storageSection

            if let openProtectedApps, openModels == nil, openDictionary == nil, openSound == nil {
                SettingsListGroup("settings.context_awareness.protect_sensitive_apps".localized, icon: "lock.shield") {
                    SettingsListDrillDownButtonRow(
                        title: "settings.context_awareness.protect_sensitive_apps".localized,
                        subtitle: "settings.context_awareness.protect_sensitive_apps_desc".localized,
                        accessibilityHint: "settings.context_awareness.protect_sensitive_apps".localized,
                        action: openProtectedApps,
                    )
                }
            }

            if let openPermissions, openModels == nil, openDictionary == nil, openSound == nil {
                SettingsListGroup("settings.section.permissions".localized, icon: "checkmark.shield") {
                    SettingsListDrillDownButtonRow(
                        title: "settings.section.permissions".localized,
                        subtitle: "settings.permissions.description".localized,
                        accessibilityHint: "settings.system.permissions.accessibility_hint".localized,
                        action: openPermissions,
                    )
                }
            }
        }
        .confirmationDialog(
            "settings.storage.cleanup_confirm_title".localized,
            isPresented: $viewModel.showCleanupConfirmationDialog,
            titleVisibility: .visible,
        ) {
            Button("settings.storage.cleanup_confirm_delete".localized, role: .destructive) {
                viewModel.confirmCleanup()
            }
            Button("settings.storage.cleanup_confirm_cancel".localized, role: .cancel) {}
        } message: {
            Text(viewModel.cleanupConfirmationMessage)
        }
        .alert("settings.general.storage".localized, isPresented: $viewModel.showCleanupSuccessAlert) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            Text("settings.storage.cleanup_success".localized)
        }
        .alert("common.error".localized, isPresented: Binding(
            get: { viewModel.cleanupError != nil },
            set: {
                if !$0 {
                    viewModel.cleanupError = nil
                }
            },
        )) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            if let error = viewModel.cleanupError {
                Text(error)
            }
        }
        .alert("settings.general.launch_at_login.error_title".localized, isPresented: Binding(
            get: { viewModel.launchAtLoginError != nil },
            set: {
                if !$0 {
                    viewModel.dismissLaunchAtLoginError()
                }
            },
        )) {
            Button("settings.general.launch_at_login.retry".localized) {
                viewModel.retryLaunchAtLogin()
            }
            Button("common.ok".localized, role: .cancel) {
                viewModel.dismissLaunchAtLoginError()
            }
        } message: {
            if let error = viewModel.launchAtLoginError {
                Text(error.messageKey.localized)
            }
        }
        .onAppear {
            syncShortcutDoubleTapIntervalInputFromModel()
            normalizeStorageRetentionSelection()
        }
    }

    @ViewBuilder
    private var systemDrilldownsSection: some View {
        if let openModels, let openDictionary, let openSound, let openPermissions {
            SettingsListGroup("settings.section.settings".localized, icon: "gearshape.2") {
                SettingsListDrillDownButtonRow(
                    title: "settings.section.models".localized,
                    subtitle: "settings.models.description".localized,
                    accessibilityHint: "settings.section.models".localized,
                    action: openModels,
                )

                SettingsListDrillDownButtonRow(
                    title: "settings.section.vocabulary".localized,
                    subtitle: "settings.vocabulary.description".localized,
                    accessibilityHint: "settings.section.vocabulary".localized,
                    action: openDictionary,
                )

                SettingsListDrillDownButtonRow(
                    title: "settings.section.audio".localized,
                    subtitle: "settings.general.audio_devices_desc".localized,
                    accessibilityHint: "settings.section.audio".localized,
                    action: openSound,
                )

                SettingsListDrillDownButtonRow(
                    title: "settings.section.permissions".localized,
                    subtitle: "settings.permissions.description".localized,
                    accessibilityHint: "settings.system.permissions.accessibility_hint".localized,
                    action: openPermissions,
                )
            }
        }

        if let openProtectedApps, openModels != nil {
            SettingsListGroup("settings.context_awareness.protect_sensitive_apps".localized, icon: "lock.shield") {
                SettingsListDrillDownButtonRow(
                    title: "settings.context_awareness.protect_sensitive_apps".localized,
                    subtitle: "settings.context_awareness.protect_sensitive_apps_desc".localized,
                    accessibilityHint: "settings.context_awareness.protect_sensitive_apps".localized,
                    action: openProtectedApps,
                )
            }
        }
    }

    private var recordingIndicatorSection: some View {
        SettingsListGroup("settings.general.recording_indicator".localized, icon: "record.circle") {
            DSToggleRow(
                "settings.general.recording_indicator.enabled".localized,
                description: "settings.general.recording_indicator.enabled_desc".localized,
                isOn: $viewModel.recordingIndicatorEnabled.animated(),
            )

            if viewModel.recordingIndicatorEnabled {
                HStack {
                    Text("settings.general.recording_indicator.style".localized)
                        .font(.body)

                    Spacer()

                    Picker("", selection: $viewModel.recordingIndicatorStyle) {
                        ForEach(RecordingIndicatorStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                HStack {
                    Text("settings.general.recording_indicator.position".localized)
                        .font(.body)

                    Spacer()

                    Picker("", selection: $viewModel.recordingIndicatorPosition) {
                        ForEach(RecordingIndicatorPosition.allCases, id: \.self) { pos in
                            Text(pos.displayName).tag(pos)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                HStack(spacing: 12) {
                    SettingsTitleWithPopover(
                        title: "settings.general.recording_indicator.animation_speed".localized,
                        helperMessage: "settings.general.recording_indicator.animation_speed_desc".localized,
                    )

                    Spacer()

                    Picker("", selection: $viewModel.recordingIndicatorAnimationSpeed) {
                        ForEach(RecordingIndicatorAnimationSpeed.allCases, id: \.self) { speed in
                            Text(speed.displayName).tag(speed)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                .transition(SettingsMotion.sectionTransition(reduceMotion: reduceMotion))
            }
        }
    }

    private var storageSection: some View {
        DSGroup("settings.general.storage".localized, icon: "folder.fill") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    SettingsTitleWithPopover(
                        title: "settings.general.auto_delete".localized,
                        helperMessage: "settings.general.auto_delete_desc".localized,
                    )

                    Spacer()

                    DSMenuPicker(selection: storageRetentionBinding, width: AppDesignSystem.Layout.smallPickerWidth) {
                        ForEach(StorageRetentionOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                HStack {
                    Button {
                        viewModel.performCleanup()
                    } label: {
                        Text(cleanupNowTitle)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.autoDeleteTranscriptions || viewModel.cleanupInProgress)

                    Spacer()
                }
            }
        }
    }

    private var storageRetentionBinding: Binding<StorageRetentionOption> {
        Binding(
            get: {
                StorageRetentionOption(
                    autoDeleteEnabled: viewModel.autoDeleteTranscriptions,
                    days: viewModel.autoDeletePeriodDays,
                )
            },
            set: { option in
                viewModel.autoDeleteTranscriptions = option.days != nil
                if let days = option.days {
                    viewModel.autoDeletePeriodDays = days
                }
            },
        )
    }

    private var cleanupNowTitle: String {
        guard viewModel.autoDeleteTranscriptions else {
            return "settings.storage.cleanup_now_disabled".localized
        }

        return String(
            format: "settings.storage.cleanup_now".localized,
            viewModel.autoDeletePeriodDays,
        )
    }

    private func applyShortcutDoubleTapIntervalInput(_ rawValue: String) {
        let digitsOnly = rawValue.filter(\.isNumber)
        if digitsOnly != rawValue {
            shortcutDoubleTapIntervalInput = digitsOnly
            return
        }

        guard !digitsOnly.isEmpty, let value = Double(digitsOnly) else { return }
        let validRange = AppSettingsStore.shortcutDoubleTapIntervalRangeMilliseconds
        let clampedValue = min(max(value, validRange.lowerBound), validRange.upperBound)

        viewModel.shortcutDoubleTapIntervalMilliseconds = clampedValue
        let normalizedValue = "\(Int(clampedValue))"
        if shortcutDoubleTapIntervalInput != normalizedValue {
            shortcutDoubleTapIntervalInput = normalizedValue
        }
    }

    private func syncShortcutDoubleTapIntervalInputFromModel() {
        shortcutDoubleTapIntervalInput = "\(Int(viewModel.shortcutDoubleTapIntervalMilliseconds))"
    }

    private func normalizeStorageRetentionSelection() {
        guard viewModel.autoDeleteTranscriptions else { return }
        guard StorageRetentionOption.supports(days: viewModel.autoDeletePeriodDays) else {
            viewModel.autoDeletePeriodDays = StorageRetentionOption.oneMonth.rawValue
            return
        }
    }
}

private enum StorageRetentionOption: Int, CaseIterable, Identifiable {
    case oneWeek = 7
    case twoWeeks = 14
    case oneMonth = 30
    case threeMonths = 90
    case sixMonths = 180
    case disabled = 0

    var id: Int {
        rawValue
    }

    init(autoDeleteEnabled: Bool, days: Int) {
        guard autoDeleteEnabled else {
            self = .disabled
            return
        }

        self = Self.allCases.first { $0.days == days } ?? .oneMonth
    }

    static func supports(days: Int) -> Bool {
        allCases.contains { $0.days == days }
    }

    var days: Int? {
        self == .disabled ? nil : rawValue
    }

    var title: String {
        switch self {
        case .oneWeek:
            "settings.storage.retention.one_week".localized
        case .twoWeeks:
            "settings.storage.retention.two_weeks".localized
        case .oneMonth:
            "settings.storage.retention.one_month".localized
        case .threeMonths:
            "settings.storage.retention.three_months".localized
        case .sixMonths:
            "settings.storage.retention.six_months".localized
        case .disabled:
            "settings.storage.retention.disabled".localized
        }
    }
}

#Preview {
    GeneralSettingsTab()
}
