import MeetingAssistantCoreCommon
import SwiftUI

public struct SettingsSearchResult: Identifiable, Equatable, Sendable {
    public let id: String
    public let section: SettingsSection
    public let destination: SettingsDestination
    public let title: String
    public let detail: String
}

enum SettingsSearchIndex {
    static func results(for rawQuery: String) -> [SettingsSearchResult] {
        let query = normalized(rawQuery)
        guard !query.isEmpty else { return [] }

        return searchableKeys.compactMap { key -> ScoredResult? in
            guard let destination = destination(forLocalizationKey: key) else { return nil }
            let section = destination.section

            let localized = key.localized
            guard localized != key else { return nil }

            let score = score(for: query, localizedText: localized, localizationKey: key)
            guard score > 0 else { return nil }

            return ScoredResult(
                score: score,
                result: SettingsSearchResult(
                    id: key,
                    section: section,
                    destination: destination,
                    title: localized,
                    detail: section.title,
                ),
            )
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }

            if lhs.result.section != rhs.result.section {
                return lhs.result.section.rawValue < rhs.result.section.rawValue
            }

            return lhs.result.title.localizedCaseInsensitiveCompare(rhs.result.title) == .orderedAscending
        }
        .map(\.result)
    }

    static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func section(forLocalizationKey key: String) -> SettingsSection? {
        destination(forLocalizationKey: key)?.section
    }

    static func destination(forLocalizationKey key: String) -> SettingsDestination? {
        if audioKeysWithinGeneralNamespace.contains(key) {
            return SettingsSection.audio.destination
        }

        if key.hasPrefix("settings.permissions.") || key.hasPrefix("permissions.") {
            return SettingsSection.permissions.destination
        }

        if meetingCapabilityKeys.contains(key) {
            return SettingsSection.meetings.destination
        }

        if integrationCapabilityKeys.contains(key) {
            return SettingsSection.integrations.destination
        }

        if protectedAppsKeys.contains(key) {
            return SettingsDestination(section: .system, systemRoute: .protectedApps)
        }

        if modeOwnedContextKeys.contains(key) {
            return SettingsSection.dictation.destination
        }

        if key.hasPrefix("settings.general.") {
            return SettingsSection.general.destination
        }

        return SettingsSearchRouteManifest.destination(for: key)
    }

    private static func score(for query: String, localizedText: String, localizationKey: String) -> Int {
        let normalizedLocalized = normalized(localizedText)
        let normalizedKey = normalized(localizationKey.replacingOccurrences(of: ".", with: " "))

        if normalizedLocalized == query {
            return 220
        }

        var score = 0

        if normalizedLocalized.hasPrefix(query) {
            score = max(score, 180)
        }

        if normalizedLocalized.contains(query) {
            score = max(score, 140)
        }

        if normalizedKey.contains(query) {
            score = max(score, 100)
        }

        if let section = section(forLocalizationKey: localizationKey), normalized(section.title).contains(query) {
            score = max(score, 90)
        }

        return score
    }

    private struct ScoredResult {
        let score: Int
        let result: SettingsSearchResult
    }

    private static let modeOwnedContextKeys: Set<String> = [
        "settings.context_awareness.accessibility_text",
        "settings.context_awareness.accessibility_text_desc",
        "settings.context_awareness.clipboard",
        "settings.context_awareness.clipboard_desc",
        "settings.context_awareness.redact_sensitive_data",
        "settings.context_awareness.redact_sensitive_data_desc",
        "settings.context_awareness.window_ocr",
        "settings.context_awareness.window_ocr_desc",
        "settings.styles.editor.context_sources",
    ]

    private static let protectedAppsKeys: Set<String> = [
        "settings.context_awareness.always_excluded_badge",
        "settings.context_awareness.excluded_apps_add",
        "settings.context_awareness.excluded_apps_empty",
        "settings.context_awareness.excluded_apps_remove",
        "settings.context_awareness.protect_sensitive_apps",
        "settings.context_awareness.protect_sensitive_apps_desc",
    ]

    private static let meetingCapabilityKeys: Set<String> = [
        "settings.capabilities.meeting_transcription",
        "settings.capabilities.meeting_transcription_desc",
    ]

    private static let integrationCapabilityKeys: Set<String> = [
        "settings.capabilities.assistant_integrations",
        "settings.capabilities.assistant_integrations_desc",
        "settings.integrations.header_desc",
        "settings.section.integrations",
    ]

    private static let audioKeysWithinGeneralNamespace: Set<String> = [
        "settings.general.audio_devices",
        "settings.general.audio_devices_desc",
        "settings.general.audio_devices_empty",
        "settings.general.audio_ducking_note",
        "settings.general.audio_ducking_percent",
        "settings.general.audio_format",
        "settings.general.audio_input_mode.custom_device",
        "settings.general.audio_input_mode.custom_device_desc",
        "settings.general.audio_input_mode.system_default",
        "settings.general.audio_input_mode.system_default_desc",
        "settings.general.audio_processing",
        "settings.general.auto_increase_microphone_volume",
        "settings.general.auto_increase_microphone_volume_tooltip",
        "settings.general.available_devices",
        "settings.general.current_device",
        "settings.general.current_device_desc",
        "settings.general.current_device_empty_desc",
        "settings.general.device_active",
        "settings.general.device_default",
        "settings.general.device_not_selected",
        "settings.general.device_not_selected_desc",
        "settings.general.device_unavailable",
        "settings.general.device_unavailable_desc",
        "settings.general.microphone_on_battery",
        "settings.general.microphone_on_battery_desc",
        "settings.general.microphone_when_charging",
        "settings.general.microphone_when_charging_desc",
        "settings.general.power_based_microphone_desc",
        "settings.general.recording_media_handling",
        "settings.general.recording_media_handling_desc",
        "settings.general.recording_media_handling_pause_note",
        "settings.general.refresh",
        "settings.general.remove_silence_before_processing",
        "settings.general.remove_silence_before_processing_desc",
        "settings.general.remove_silence_before_processing_note",
        "settings.general.sound_feedback",
        "settings.general.sound_feedback.enabled",
        "settings.general.sound_feedback.enabled_desc",
        "settings.general.sound_feedback.preview",
        "settings.general.sound_feedback.start_sound",
        "settings.general.sound_feedback.stop_sound",
    ]
}
