import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

/// Shared quick-add submission path that reuses Dictionary page validation/persistence.
@MainActor
public final class DictionaryQuickAddViewModel: ObservableObject {
    @Published public var selectedWorkflow: DictionaryWorkflow = .vocabulary
    @Published public var termInput = ""
    @Published public var findInput = ""
    @Published public var replaceInput = ""
    @Published public var validationMessage: String?

    private let vocabularyViewModel: VocabularyTermsSettingsViewModel
    private let substitutionViewModel: VocabularySettingsViewModel

    public init(settings: AppSettingsStore = .shared) {
        vocabularyViewModel = VocabularyTermsSettingsViewModel(settings: settings)
        substitutionViewModel = VocabularySettingsViewModel(settings: settings)
    }

    public var canSubmit: Bool {
        switch selectedWorkflow {
        case .vocabulary:
            !termInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .substitutions:
            !findInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public func clearValidation() {
        validationMessage = nil
    }

    /// Returns `true` when at least one term/rule was persisted and the panel may dismiss.
    @discardableResult
    public func submit() -> Bool {
        validationMessage = nil

        switch selectedWorkflow {
        case .vocabulary:
            return submitVocabulary()
        case .substitutions:
            return submitSubstitution()
        }
    }

    private func submitVocabulary() -> Bool {
        vocabularyViewModel.bulkInputText = termInput
        let addedCount = vocabularyViewModel.addTermsFromBulkInput()

        if addedCount > 0 {
            termInput = vocabularyViewModel.bulkInputText
            return true
        }

        if let error = vocabularyViewModel.validationError {
            validationMessage = vocabularyValidationMessage(for: error)
        } else {
            validationMessage = "settings.dictionary.vocabulary.validation.empty".localized
        }
        return false
    }

    private func submitSubstitution() -> Bool {
        guard substitutionViewModel.saveRule(find: findInput, replace: replaceInput) else {
            validationMessage = substitutionValidationMessage(for: substitutionViewModel.editorValidationError)
            return false
        }

        findInput = ""
        replaceInput = ""
        return true
    }

    private func vocabularyValidationMessage(
        for error: VocabularyTermsSettingsViewModel.ValidationError,
    ) -> String {
        switch error {
        case .emptyTerm:
            "settings.dictionary.vocabulary.validation.empty".localized
        case let .duplicatedTerm(term):
            "settings.dictionary.vocabulary.validation.duplicated".localized(with: term)
        }
    }

    private func substitutionValidationMessage(
        for error: VocabularySettingsViewModel.ValidationError?,
    ) -> String {
        switch error {
        case .emptyFind, .none:
            "settings.vocabulary.validation.find_required".localized
        case .duplicatedFind:
            "settings.vocabulary.validation.find_duplicated".localized
        }
    }
}
