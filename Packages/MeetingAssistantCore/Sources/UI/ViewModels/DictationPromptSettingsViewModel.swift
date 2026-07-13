import AppKit
import Combine
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

@MainActor
public final class DictationPromptSettingsViewModel: ObservableObject {
    @Published var settings: AppSettingsStore
    @Published public var showPromptEditor = false
    @Published public var editingPrompt: PostProcessingPrompt?
    @Published public var showDeleteConfirmation = false
    @Published public var promptToDelete: PostProcessingPrompt?

    private var cancellables = Set<AnyCancellable>()

    public init(settings: AppSettingsStore = .shared) {
        self.settings = settings

        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var availablePrompts: [PostProcessingPrompt] {
        settings.dictationAvailablePrompts
    }

    public var selectedPromptId: UUID? {
        settings.dictationSelectedPromptId
    }

    public var effectiveSelectedPromptId: UUID {
        if settings.isDictationPostProcessingDisabled {
            return AppSettingsStore.noPostProcessingPromptId
        }

        return settings.dictationSelectedPromptId ?? PostProcessingPrompt.defaultPrompt.id
    }

    public func selectPrompt(_ id: UUID, forceSelect: Bool = false) {
        let animation: Animation? = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? nil
            : .easeInOut(duration: 0.2)

        withAnimation(animation) {
            if forceSelect {
                settings.dictationSelectedPromptId = id
            } else {
                settings.dictationSelectedPromptId = (settings.dictationSelectedPromptId == id) ? nil : id
            }
        }
    }

    public func handleSavePrompt(_ prompt: PostProcessingPrompt) {
        settings.upsertDictationPrompt(prompt)
        showPromptEditor = false
        editingPrompt = nil
    }

    public func confirmDeletePrompt(_ prompt: PostProcessingPrompt) {
        promptToDelete = prompt
        showDeleteConfirmation = true
    }

    public func executeDelete() {
        if let prompt = promptToDelete {
            settings.deleteDictationPrompt(id: prompt.id)
        }
        showDeleteConfirmation = false
        promptToDelete = nil
    }

    public func prepareCopy(of prompt: PostProcessingPrompt, asDuplicate: Bool) {
        var newTitle = prompt.title
        if asDuplicate {
            newTitle = "\(prompt.title) (\("settings.post_processing.duplicate".localized))"
        }

        let newPrompt = PostProcessingPrompt(
            id: UUID(),
            title: newTitle,
            promptText: prompt.promptText,
            isActive: prompt.isActive,
            icon: prompt.icon,
            description: prompt.description,
            isPredefined: false,
        )

        editingPrompt = newPrompt
        showPromptEditor = true
    }
}
