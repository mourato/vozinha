@testable import MeetingAssistantCore
import XCTest

final class VocabularyReplacementRuleTests: XCTestCase {
    func testNormalizedVariants_TrimsDeduplicatesAndDropsEmptyEntries() {
        let variants = VocabularyReplacementRule.normalizedVariants(
            from: " raycast, reycast , , recast, Raycast ",
        )

        XCTAssertEqual(variants, ["raycast", "reycast", "recast"])
    }

    func testApply_WhenRuleHasMultipleVariants_ReplacesAllMatches() {
        let output = VocabularyReplacementRule.apply(
            rules: [
                VocabularyReplacementRule(find: "raycast, reycast, recast", replace: "Raycast"),
            ],
            to: "Raycast works better than reycast, and recast too.",
        )

        XCTAssertEqual(output, "Raycast works better than Raycast, and Raycast too.")
    }

    func testApply_WhenVariantsContainSpaces_RemainsWholeWordAndCaseInsensitive() {
        let output = VocabularyReplacementRule.apply(
            rules: [
                VocabularyReplacementRule(find: "eleven labs, elevan labs, elaven labs", replace: "ElevenLabs"),
            ],
            to: "ELEVEN LABS is not the same as eleven labsy, but elevan labs should match.",
        )

        XCTAssertEqual(output, "ElevenLabs is not the same as eleven labsy, but ElevenLabs should match.")
    }

    func testApply_WhenReplacementIsEmpty_RemovesAllMatchedVariants() {
        let output = VocabularyReplacementRule.apply(
            rules: [
                VocabularyReplacementRule(find: "um, uh", replace: ""),
            ],
            to: "um I think uh this works",
        )

        XCTAssertEqual(output, " I think  this works")
    }
}
