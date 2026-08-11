import Foundation
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
extension RecordingManagerTests {
    func testModeConfigurationIsStableDuringSession() async throws {
        let manager = try XCTUnwrap(manager)
        let settings = AppSettingsStore.shared
        let originalStyles = settings.dictationStyles
        let originalAutoCopy = settings.autoCopyTranscriptionToClipboard
        let originalReplacementRules = settings.vocabularyReplacementRules
        defer {
            settings.dictationStyles = originalStyles
            settings.autoCopyTranscriptionToClipboard = originalAutoCopy
            settings.vocabularyReplacementRules = originalReplacementRules
        }
        let snapshottedReplacementRules = [VocabularyReplacementRule(find: "captured", replace: "stable")]
        settings.vocabularyReplacementRules = snapshottedReplacementRules

        let snapshottedPolicy = DictationTextHandlingPolicy(
            autoCopyToClipboard: true,
            autoPasteToActiveApp: false,
            smartSpacingAndCapitalization: true,
            smartParagraphs: false,
        )
        let snapshottedTranscription = DictationTranscriptionConfiguration(
            selection: TranscriptionProviderSelection(provider: .groq, selectedModel: "whisper-large-v3"),
            inputLanguageCode: "pt-BR",
        )
        var styles = settings.dictationStyles
        let defaultIndex = try XCTUnwrap(styles.firstIndex(where: \.isDefault))
        styles[defaultIndex] = makeDictationStyle(
            styles[defaultIndex],
            textHandlingPolicy: snapshottedPolicy,
            transcriptionConfiguration: snapshottedTranscription,
        )
        settings.dictationStyles = styles

        await manager.startRecording(source: .microphone)
        XCTAssertTrue(manager.isRecording)

        var mutatedStyles = settings.dictationStyles
        let mutatedIndex = try XCTUnwrap(mutatedStyles.firstIndex(where: \.isDefault))
        mutatedStyles[mutatedIndex] = makeDictationStyle(
            mutatedStyles[mutatedIndex],
            textHandlingPolicy: DictationTextHandlingPolicy(
                autoCopyToClipboard: false,
                autoPasteToActiveApp: true,
                smartSpacingAndCapitalization: false,
                smartParagraphs: true,
            ),
            transcriptionConfiguration: DictationTranscriptionConfiguration(
                selection: .default,
                inputLanguageCode: "en",
            ),
        )
        settings.dictationStyles = mutatedStyles
        settings.autoCopyTranscriptionToClipboard = false
        settings.vocabularyReplacementRules = [VocabularyReplacementRule(find: "captured", replace: "mutated")]

        let meeting = try XCTUnwrap(manager.currentMeeting)
        let session = manager.makeTranscriptionSessionSnapshot(meeting)

        XCTAssertEqual(session.dictationTextHandlingPolicy, snapshottedPolicy)
        XCTAssertEqual(session.dictationTranscriptionConfiguration, snapshottedTranscription)
        XCTAssertEqual(session.vocabularySnapshot.replacementRules, snapshottedReplacementRules)

        await manager.cancelRecording()
    }
}

private func makeDictationStyle(
    _ style: DictationStyle,
    textHandlingPolicy: DictationTextHandlingPolicy,
    transcriptionConfiguration: DictationTranscriptionConfiguration,
) -> DictationStyle {
    DictationStyle(
        id: style.id,
        name: style.name,
        iconSymbol: style.iconSymbol,
        promptInstructions: style.promptInstructions,
        postProcessingEnabled: style.postProcessingEnabled,
        forceMarkdownOutput: style.forceMarkdownOutput,
        replaceBasePrompt: style.replaceBasePrompt,
        outputLanguage: style.outputLanguage,
        targets: [],
        contextSourcePolicy: style.contextSourcePolicy,
        enhancementsSelection: style.enhancementsSelection,
        isDefault: true,
        textHandlingPolicy: textHandlingPolicy,
        transcriptionConfiguration: transcriptionConfiguration,
    )
}
