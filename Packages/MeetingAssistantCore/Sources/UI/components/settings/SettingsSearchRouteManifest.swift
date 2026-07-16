import MeetingAssistantCoreCommon

// MARK: - Settings Search Route Manifest

enum SettingsSearchRouteManifest {
    struct PrefixRoute {
        let prefix: String
        let destination: SettingsDestination

        init(prefix: String, section: SettingsSection) {
            self.prefix = prefix
            destination = section.destination
        }
    }

    static let exactRoutes: [String: SettingsDestination] = [
        "settings.section.metrics": SettingsSection.metrics.destination,
    ]

    static let prefixRoutes: [PrefixRoute] = [
        .init(prefix: "metrics.", section: .metrics),
        .init(prefix: "settings.section.activity", section: .activity),
        .init(prefix: "settings.section.dictation", section: .modes),
        .init(prefix: "settings.section.modes", section: .modes),
        .init(prefix: "settings.dictation.", section: .modes),
        .init(prefix: "settings.shortcuts.header_desc", section: .system),
        .init(prefix: "settings.shortcuts.dictation", section: .system),
        .init(prefix: "settings.section.assistant", section: .assistant),
        .init(prefix: "settings.assistant.", section: .assistant),
        .init(prefix: "settings.integrations.", section: .integrations),
        .init(prefix: "settings.section.meetings", section: .meetings),
        .init(prefix: "settings.meetings.", section: .meetings),
        .init(prefix: "settings.shortcuts.meeting", section: .meetings),
        .init(prefix: "settings.models.meeting_transcription.", section: .meetings),
        .init(prefix: "settings.service.transcription_provider.meeting_diarization_warning.", section: .meetings),
        .init(prefix: "settings.section.history", section: .transcriptions),
        .init(prefix: "settings.transcriptions.", section: .transcriptions),
        .init(prefix: "settings.models.routing.", section: .modes),
        .init(prefix: "settings.service.transcription_provider.provider", section: .modes),
        .init(prefix: "settings.service.transcription_provider.input_language", section: .modes),
        .init(prefix: "settings.dictation.modes_and_prompts.", section: .modes),
        .init(prefix: "settings.dictation.modes.", section: .modes),
        .init(prefix: "settings.section.rules_per_app", section: .modes),
        .init(prefix: "settings.rules_per_app", section: .modes),
        .init(prefix: "settings.styles.", section: .modes),
        .init(prefix: "settings.service.model", section: .meetings),
        .init(prefix: "settings.service.diarization_model_name", section: .meetings),
        .init(prefix: "settings.service.", section: .models),
        .init(prefix: "transcription.qa.", section: .transcriptions),
        .init(prefix: "settings.section.models", section: .models),
        .init(prefix: "settings.models.", section: .models),
        .init(prefix: "settings.section.vocabulary", section: .vocabulary),
        .init(prefix: "settings.vocabulary.", section: .vocabulary),
        .init(prefix: "settings.section.ai", section: .modes),
        .init(prefix: "settings.context_awareness.", section: .system),
        .init(prefix: "settings.text_context.", section: .system),
        .init(prefix: "settings.post_processing.", section: .modes),
        .init(prefix: "settings.enhancements.meeting_intelligence_model", section: .meetings),
        .init(prefix: "settings.enhancements.qa_enabled_desc", section: .meetings),
        .init(prefix: "settings.enhancements.selector.meeting.", section: .meetings),
        .init(prefix: "settings.enhancements.selector.dictation.", section: .modes),
        .init(prefix: "settings.enhancements.provider_models.", section: .models),
        .init(prefix: "settings.enhancements.provider.", section: .models),
        .init(prefix: "settings.enhancements.providers.", section: .models),
        .init(prefix: "settings.enhancements.badge.", section: .models),
        .init(prefix: "settings.enhancements.model_selector.", section: .models),
        .init(prefix: "settings.enhancements.test_and_save", section: .models),
        .init(prefix: "settings.enhancements.", section: .models),
        .init(prefix: "prompt.instructions_hint", section: .modes),
        .init(prefix: "settings.section.audio", section: .audio),
        .init(prefix: "settings.section.permissions", section: .permissions),
        .init(prefix: "settings.system.", section: .system),
        .init(prefix: "settings.shortcuts.health.", section: .system),
        .init(prefix: "settings.storage.", section: .system),
    ]

    static func destination(for key: String) -> SettingsDestination? {
        if let exactDestination = exactRoutes[key] {
            return exactDestination
        }

        return prefixRoutes
            .filter { key.hasPrefix($0.prefix) }
            .max { lhs, rhs in
                if lhs.prefix.count != rhs.prefix.count {
                    return lhs.prefix.count < rhs.prefix.count
                }
                return lhs.prefix < rhs.prefix
            }?
            .destination
    }
}
