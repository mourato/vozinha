import Combine
import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure

@MainActor
public final class DictionaryQuickAddShortcutSettingsViewModel: ObservableObject {
    private let settings = AppSettingsStore.shared
    private var cancellables = Set<AnyCancellable>()
    private var isApplyingShortcutChange = false

    @Published public var dictionaryQuickAddShortcutDefinition: ShortcutDefinition?
    @Published public var dictionaryQuickAddShortcutConflictMessage: String?

    public init() {
        dictionaryQuickAddShortcutDefinition = settings.dictionaryQuickAddShortcutDefinition
        dictionaryQuickAddShortcutConflictMessage = nil
        setupBindings()
    }

    private func setupBindings() {
        $dictionaryQuickAddShortcutDefinition
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.handleShortcutDefinitionChange(newValue)
            }
            .store(in: &cancellables)
    }

    private func handleShortcutDefinitionChange(_ newValue: ShortcutDefinition?) {
        guard !isApplyingShortcutChange else {
            return
        }

        guard let newValue else {
            settings.dictionaryQuickAddShortcutDefinition = nil
            dictionaryQuickAddShortcutConflictMessage = nil
            return
        }

        guard let normalizedValue = ShortcutDefinitionNormalizer.normalized(newValue) else {
            revertChange(with: "settings.shortcuts.modifier.primary_key_required".localized)
            return
        }

        guard GlobalHotkeyMapper.descriptor(for: normalizedValue) != nil else {
            revertChange(with: "settings.general.cancel_recording_shortcut_unsupported".localized)
            return
        }

        let candidate = ShortcutBinding(
            actionID: .dictionaryQuickAdd,
            actionDisplayName: "settings.dictionary.quick_add.shortcut".localized,
            shortcut: normalizedValue,
        )

        if let conflict = settings.shortcutConflict(for: candidate) {
            revertChange(with: conflictMessage(for: conflict))
            return
        }

        settings.dictionaryQuickAddShortcutDefinition = normalizedValue
        dictionaryQuickAddShortcutConflictMessage = nil
    }

    private func revertChange(with message: String) {
        isApplyingShortcutChange = true
        dictionaryQuickAddShortcutDefinition = settings.dictionaryQuickAddShortcutDefinition
        dictionaryQuickAddShortcutConflictMessage = message
        isApplyingShortcutChange = false
    }

    private func conflictMessage(for conflict: ShortcutConflict) -> String {
        switch conflict.reason {
        case .systemReserved:
            "settings.shortcuts.modifier.system_reserved".localized
        case .layerLeaderKeyCollision,
             .identicalSignature,
             .effectiveModifierOverlap,
             .sideSpecificVsAgnosticOverlap,
             .assistantIntegrationConcurrentActivation:
            "settings.shortcuts.modifier.conflict".localized(with: conflict.conflicting.actionDisplayName)
        }
    }
}
