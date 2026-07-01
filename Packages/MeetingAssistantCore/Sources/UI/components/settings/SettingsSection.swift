import MeetingAssistantCoreCommon

// MARK: - Settings Section Enum

public enum SettingsSection: String, CaseIterable, Identifiable, Sendable {
    case metrics
    case dictation
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

    public var id: String {
        rawValue
    }

    public static let primarySections: [SettingsSection] = [
        .dictation,
        .meetings,
        .assistant,
        .integrations,
        .transcriptions,
        .metrics,
    ]

    public static let settingsSections: [SettingsSection] = [
        .models,
        .enhancements,
        .vocabulary,
        .audio,
        .permissions,
        .general,
    ]

    public var title: String {
        switch self {
        case .metrics: "settings.section.metrics".localized
        case .general: "settings.section.general".localized
        case .dictation: "settings.section.dictation".localized
        case .meetings: "settings.section.meetings".localized
        case .audio: "settings.section.audio".localized
        case .assistant: "settings.section.assistant".localized
        case .integrations: "settings.section.integrations".localized
        case .transcriptions: "settings.section.history".localized
        case .models: "settings.section.models".localized
        case .vocabulary: "settings.section.vocabulary".localized
        case .enhancements: "settings.section.ai".localized
        case .permissions: "settings.section.permissions".localized
        }
    }

    public var icon: String {
        switch self {
        case .metrics: "chart.pie.fill"
        case .general: "gearshape.2"
        case .dictation: "microphone"
        case .meetings: "bubble.left.and.text.bubble.right"
        case .audio: "speaker.wave.2"
        case .assistant: "sparkle"
        case .integrations: "puzzlepiece.extension"
        case .transcriptions: "clock"
        case .models: "cpu"
        case .vocabulary: "character.book.closed"
        case .enhancements: "sparkles"
        case .permissions: "checkmark.shield"
        }
    }

}
