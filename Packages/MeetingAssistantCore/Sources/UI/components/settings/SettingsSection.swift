import MeetingAssistantCoreCommon

public struct SettingsDestination: Equatable, Sendable {
    public let section: SettingsSection
    public let activityRoute: ActivitySettingsRoute?
    public let activityPendingSheet: ActivityPendingSheet?
    public let systemRoute: SystemSettingsRoute?
    public let modesSubroute: DictationStyleRoute?
    public let expandProtectedApps: Bool

    public init(
        section: SettingsSection,
        activityRoute: ActivitySettingsRoute? = nil,
        activityPendingSheet: ActivityPendingSheet? = nil,
        systemRoute: SystemSettingsRoute? = nil,
        modesSubroute: DictationStyleRoute? = nil,
        expandProtectedApps: Bool = false,
    ) {
        self.section = section
        self.activityRoute = activityRoute
        self.activityPendingSheet = activityPendingSheet
        self.systemRoute = systemRoute
        self.modesSubroute = modesSubroute
        self.expandProtectedApps = expandProtectedApps
    }
}

// MARK: - Settings Section Enum

public enum SettingsSection: String, CaseIterable, Identifiable, Sendable {
    case metrics
    case dictation
    case modes
    case assistant
    case integrations
    case meetings
    case transcriptions
    case general
    case models
    case vocabulary
    case enhancements
    case audio
    case permissions
    case activity
    case intelligence
    case system

    public var id: String {
        rawValue
    }

    public static let primarySections: [SettingsSection] = [
        .activity,
        .modes,
        .meetings,
    ]

    public static let settingsSections: [SettingsSection] = [
        .system,
    ]

    public static var visibleSections: [SettingsSection] {
        [
            .activity,
            .modes,
            .meetings,
            .system,
        ]
    }

    public var isLegacyRedirect: Bool {
        switch self {
        case .metrics, .transcriptions, .models, .enhancements, .vocabulary, .permissions, .general, .intelligence, .audio, .dictation, .assistant, .integrations:
            true
        case .activity, .modes, .meetings, .system:
            false
        }
    }

    public var visibleSection: SettingsSection {
        destination.section
    }

    public var destination: SettingsDestination {
        switch self {
        case .metrics:
            SettingsDestination(
                section: .activity,
                activityRoute: .root,
                activityPendingSheet: .performance,
            )
        case .transcriptions:
            SettingsDestination(section: .activity, activityRoute: .history)
        case .models:
            SettingsDestination(section: .system, systemRoute: .models)
        case .vocabulary:
            SettingsDestination(section: .system, systemRoute: .dictionary)
        case .enhancements:
            SettingsDestination(section: .modes)
        case .permissions:
            SettingsDestination(section: .system)
        case .general:
            SettingsDestination(section: .system)
        case .audio:
            SettingsDestination(section: .system, systemRoute: .sound)
        case .intelligence:
            SettingsDestination(section: .system, systemRoute: .models)
        case .dictation:
            SettingsDestination(section: .modes)
        case .assistant:
            SettingsDestination(section: .modes, modesSubroute: .assistant)
        case .integrations:
            SettingsDestination(section: .modes, modesSubroute: .integrations)
        case .activity, .modes, .meetings, .system:
            SettingsDestination(section: self)
        }
    }

    public static func resolvedVisibleSection(for rawValue: String) -> SettingsSection? {
        resolvedDestination(for: rawValue)?.section
    }

    public static func resolvedDestination(for rawValue: String) -> SettingsDestination? {
        SettingsSection(rawValue: rawValue)?.destination
    }

    public var title: String {
        switch self {
        case .metrics: "settings.section.metrics".localized
        case .general: "settings.section.general".localized
        case .dictation: "settings.section.dictation".localized
        case .modes: "settings.section.modes".localized
        case .meetings: "settings.section.meetings".localized
        case .audio: "settings.section.audio".localized
        case .assistant: "settings.section.assistant".localized
        case .integrations: "settings.section.integrations".localized
        case .transcriptions: "settings.section.history".localized
        case .models: "settings.section.models".localized
        case .vocabulary: "settings.section.vocabulary".localized
        case .enhancements: "settings.section.ai".localized
        case .permissions: "settings.section.permissions".localized
        case .activity: "settings.section.activity".localized
        case .intelligence: "settings.section.intelligence".localized
        case .system: "settings.section.settings".localized
        }
    }

    public var icon: String {
        switch self {
        case .metrics: "chart.pie.fill"
        case .general: "gearshape.2"
        case .dictation: "microphone"
        case .modes: "mic.fill"
        case .meetings: "bubble.left.and.text.bubble.right"
        case .audio: "speaker.wave.2"
        case .assistant: "sparkle"
        case .integrations: "puzzlepiece.extension"
        case .transcriptions: "clock"
        case .models: "cpu"
        case .vocabulary: "character.book.closed"
        case .enhancements: "sparkles"
        case .permissions: "checkmark.shield"
        case .activity: "chart.pie.fill"
        case .intelligence: "sparkles"
        case .system: "gearshape.2"
        }
    }

}
