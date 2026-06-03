import MeetingAssistantCoreCommon
import SwiftUI

public struct SettingsSearchResult: Identifiable, Equatable, Sendable {
    public let id: String
    public let section: SettingsSection
    public let title: String
    public let detail: String
}

enum SettingsSearchIndex {
    static func results(for rawQuery: String) -> [SettingsSearchResult] {
        let query = normalized(rawQuery)
        guard !query.isEmpty else { return [] }

        return searchableKeys.compactMap { key -> ScoredResult? in
            guard let section = section(forLocalizationKey: key) else { return nil }

            let localized = key.localized
            guard localized != key else { return nil }

            let score = score(for: query, localizedText: localized, localizationKey: key)
            guard score > 0 else { return nil }

            return ScoredResult(
                score: score,
                result: SettingsSearchResult(
                    id: key,
                    section: section,
                    title: localized,
                    detail: section.title
                )
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
        if audioKeysWithinGeneralNamespace.contains(key) {
            return .audio
        }

        if key.hasPrefix("settings.general.") {
            return .general
        }

        for mapping in prefixMappings where key.hasPrefix(mapping.prefix) {
            return mapping.section
        }

        return exactMappings[key]
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

    private struct PrefixSectionMapping {
        let prefix: String
        let section: SettingsSection
    }

    private static let prefixMappings: [PrefixSectionMapping] = [
        .init(prefix: "metrics.", section: .metrics),
        .init(prefix: "settings.section.dictation", section: .dictation),
        .init(prefix: "settings.dictation.", section: .dictation),
        .init(prefix: "settings.shortcuts.header_desc", section: .dictation),
        .init(prefix: "settings.shortcuts.dictation", section: .dictation),
        .init(prefix: "settings.capabilities.", section: .dictation),
        .init(prefix: "settings.section.assistant", section: .assistant),
        .init(prefix: "settings.assistant.", section: .assistant),
        .init(prefix: "settings.integrations.", section: .assistant),
        .init(prefix: "settings.section.meetings", section: .meetings),
        .init(prefix: "settings.meetings.", section: .meetings),
        .init(prefix: "settings.shortcuts.meeting", section: .meetings),
        .init(prefix: "settings.models.meeting_transcription.", section: .meetings),
        .init(prefix: "settings.service.transcription_provider.meeting_diarization_warning.", section: .meetings),
        .init(prefix: "settings.section.history", section: .transcriptions),
        .init(prefix: "settings.transcriptions.", section: .transcriptions),
        .init(prefix: "settings.models.routing.", section: .dictation),
        .init(prefix: "settings.service.transcription_provider.provider", section: .dictation),
        .init(prefix: "settings.service.transcription_provider.input_language", section: .dictation),
        .init(prefix: "settings.section.rules_per_app", section: .dictation),
        .init(prefix: "settings.rules_per_app", section: .dictation),
        .init(prefix: "settings.styles.", section: .dictation),
        .init(prefix: "settings.service.model", section: .meetings),
        .init(prefix: "settings.service.diarization_model_name", section: .meetings),
        .init(prefix: "settings.service.", section: .models),
        .init(prefix: "transcription.qa.", section: .transcriptions),
        .init(prefix: "settings.section.models", section: .models),
        .init(prefix: "settings.models.", section: .models),
        .init(prefix: "settings.section.vocabulary", section: .vocabulary),
        .init(prefix: "settings.vocabulary.", section: .vocabulary),
        .init(prefix: "settings.section.ai", section: .enhancements),
        .init(prefix: "settings.context_awareness.", section: .enhancements),
        .init(prefix: "settings.post_processing.", section: .enhancements),
        .init(prefix: "settings.enhancements.", section: .enhancements),
        .init(prefix: "prompt.instructions_hint", section: .enhancements),
        .init(prefix: "settings.section.audio", section: .audio),
        .init(prefix: "settings.section.permissions", section: .permissions),
        .init(prefix: "settings.permissions.", section: .permissions),
        .init(prefix: "permissions.", section: .permissions),
        .init(prefix: "settings.shortcuts.health.", section: .permissions),
        .init(prefix: "settings.storage.", section: .general),
    ]

    private static let exactMappings: [String: SettingsSection] = [
        "settings.section.metrics": .metrics,
    ]

    private static let audioKeysWithinGeneralNamespace: Set<String> = [
        "settings.general.audio_devices",
        "settings.general.audio_devices_desc",
        "settings.general.audio_devices_empty",
        "settings.general.audio_ducking_note",
        "settings.general.audio_ducking_percent",
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
