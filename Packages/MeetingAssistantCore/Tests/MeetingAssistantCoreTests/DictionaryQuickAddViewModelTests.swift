@testable import MeetingAssistantCore
import XCTest

@MainActor
final class DictionaryQuickAddViewModelTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testVocabularySubmitMatchesPageBulkAddSemantics() {
        let pageViewModel = VocabularyTermsSettingsViewModel(settings: settings)
        pageViewModel.bulkInputText = " SwiftUI , Metal, CoreML "
        let pageAdded = pageViewModel.addTermsFromBulkInput()
        let pageTerms = settings.vocabularyTerms.map(\.term)

        settings.resetToDefaults()

        let quickAddViewModel = DictionaryQuickAddViewModel(settings: settings)
        quickAddViewModel.selectedWorkflow = .vocabulary
        quickAddViewModel.termInput = " SwiftUI , Metal, CoreML "
        let submitted = quickAddViewModel.submit()

        XCTAssertEqual(pageAdded, 3)
        XCTAssertTrue(submitted)
        XCTAssertEqual(settings.vocabularyTerms.map(\.term), pageTerms)
        XCTAssertEqual(Set(settings.vocabularyTerms.map(\.term)), Set(["CoreML", "Metal", "SwiftUI"]))
    }

    func testVocabularySubmitRejectsDuplicatesWithoutPersisting() {
        settings.vocabularyTerms = [VocabularyTerm(term: "SwiftUI", definition: "")]
        let viewModel = DictionaryQuickAddViewModel(settings: settings)
        viewModel.selectedWorkflow = .vocabulary
        viewModel.termInput = "swiftui"

        XCTAssertFalse(viewModel.submit())
        XCTAssertEqual(settings.vocabularyTerms.map(\.term), ["SwiftUI"])
        XCTAssertNotNil(viewModel.validationMessage)
    }

    func testSubstitutionSubmitMatchesPageSaveSemantics() {
        let pageViewModel = VocabularySettingsViewModel(settings: settings)
        XCTAssertTrue(pageViewModel.saveRule(find: "foo, Foo ", replace: " bar "))
        let pageRules = settings.vocabularyReplacementRules

        settings.resetToDefaults()

        let quickAddViewModel = DictionaryQuickAddViewModel(settings: settings)
        quickAddViewModel.selectedWorkflow = .substitutions
        quickAddViewModel.findInput = "foo, Foo "
        quickAddViewModel.replaceInput = " bar "

        XCTAssertTrue(quickAddViewModel.submit())
        XCTAssertEqual(settings.vocabularyReplacementRules.count, pageRules.count)
        XCTAssertEqual(
            settings.vocabularyReplacementRules.first?.normalizedFindVariants,
            pageRules.first?.normalizedFindVariants,
        )
        XCTAssertEqual(
            settings.vocabularyReplacementRules.first?.replace,
            pageRules.first?.replace,
        )
    }

    func testSubstitutionSubmitRejectsDuplicateFind() {
        settings.vocabularyReplacementRules = [
            VocabularyReplacementRule(find: "alpha", replace: "beta"),
        ]
        let viewModel = DictionaryQuickAddViewModel(settings: settings)
        viewModel.selectedWorkflow = .substitutions
        viewModel.findInput = "ALPHA"
        viewModel.replaceInput = "gamma"

        XCTAssertFalse(viewModel.submit())
        XCTAssertEqual(settings.vocabularyReplacementRules.count, 1)
        XCTAssertNotNil(viewModel.validationMessage)
    }

    func testEmptyReplacementIsAllowed() {
        let viewModel = DictionaryQuickAddViewModel(settings: settings)
        viewModel.selectedWorkflow = .substitutions
        viewModel.findInput = "remove-me"
        viewModel.replaceInput = ""

        XCTAssertTrue(viewModel.submit())
        XCTAssertEqual(settings.vocabularyReplacementRules.first?.replace, "")
    }
}
