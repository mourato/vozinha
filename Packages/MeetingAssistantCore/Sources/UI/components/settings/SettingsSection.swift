import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

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
    case rulesPerApp
    case vocabulary
    case enhancements
    case audio
    case permissions

    public var id: String {
        rawValue
    }

    public static let primarySections: [SettingsSection] = [
        .metrics,
        .dictation,
        .assistant,
        .meetings,
        .transcriptions,
    ]

    public static let settingsSections: [SettingsSection] = [
        .general,
        .models,
        .rulesPerApp,
        .vocabulary,
        .enhancements,
        .audio,
        .permissions,
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
        case .rulesPerApp: "settings.section.rules_per_app".localized
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
        case .rulesPerApp: "slider.horizontal.3"
        case .vocabulary: "character.book.closed"
        case .enhancements: "sparkles"
        case .permissions: "checkmark.shield"
        }
    }

    public var sidebarIconBackgroundColor: Color {
        switch self {
        case .metrics: .accentColor
        case .dictation: .accentColor
        case .assistant: .accentColor
        case .integrations: .accentColor
        case .meetings: .accentColor
        case .transcriptions: .accentColor
        case .general: .accentColor
        case .models: .accentColor
        case .rulesPerApp: .accentColor
        case .vocabulary: .accentColor
        case .enhancements: .accentColor
        case .audio: .accentColor
        case .permissions: .accentColor
        }
    }
}
