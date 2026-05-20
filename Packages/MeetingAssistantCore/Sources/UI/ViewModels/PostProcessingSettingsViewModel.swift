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
public class PostProcessingSettingsViewModel: ObservableObject {
    @Published var settings: AppSettingsStore
    @Published public var showPromptEditor = false
    @Published public var editingPrompt: PostProcessingPrompt?
    @Published public var showDeleteConfirmation = false
    @Published public var promptToDelete: PostProcessingPrompt?
    @Published public var showSystemPromptEditor = false

    private var cancellables = Set<AnyCancellable>()

    public init(settings: AppSettingsStore = .shared) {
        self.settings = settings

        // Forward settings changes to this ViewModel's observers to ensure UI refreshes
        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public func handleSavePrompt(_ prompt: PostProcessingPrompt) {
        if settings.userPrompts.contains(where: { $0.id == prompt.id }) {
            settings.updatePrompt(prompt)
        } else {
            settings.addPrompt(prompt)
        }
        showPromptEditor = false
        editingPrompt = nil
    }

    public func confirmDeletePrompt(_ prompt: PostProcessingPrompt) {
        promptToDelete = prompt
        showDeleteConfirmation = true
    }

    public func executeDelete() {
        if let prompt = promptToDelete {
            settings.deletePrompt(id: prompt.id)
        }
        showDeleteConfirmation = false
        promptToDelete = nil
    }

    public func resetSystemPrompt() {
        settings.resetSystemPrompt()
    }

    public func prepareCopy(of prompt: PostProcessingPrompt, asDuplicate: Bool) {
        var newTitle = prompt.title
        if asDuplicate {
            newTitle = "\(prompt.title) (\("settings.post_processing.duplicate".localized))"
        }

        // Use original ID if NOT duplicating, otherwise force a new ID.
        // Also make it non-predefined so it can be edited.
        let newPrompt = PostProcessingPrompt(
            id: asDuplicate ? UUID() : prompt.id,
            title: newTitle,
            promptText: prompt.promptText,
            isActive: prompt.isActive,
            icon: prompt.icon,
            description: prompt.description,
            isPredefined: false
        )
        editingPrompt = newPrompt
        showPromptEditor = true
    }

    public func handleSaveSystemPrompt(_ newPrompt: String) {
        settings.systemPrompt = newPrompt
        showSystemPromptEditor = false
    }

    public func selectPrompt(_ id: UUID, forceSelect: Bool = false) {
        let animation: Animation? = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? nil
            : .easeInOut(duration: 0.2)

        withAnimation(animation) {
            if forceSelect {
                self.settings.selectedPromptId = id
            } else {
                self.settings.selectedPromptId = (self.settings.selectedPromptId == id) ? nil : id
            }
        }
    }
}
