import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Recording Control State

extension RecordingManager {
    func clearActiveTranscriptionSnapshot() {
        activeTranscriptionConfiguration = nil
        activeVocabularySnapshot = nil
    }

    func makeTranscriptionSessionSnapshot(_ meeting: Meeting) -> TranscriptionSessionSnapshot {
        let kernelMode = postProcessingKernelMode(
            for: meeting,
            capturePurposeOverride: meeting.capturePurpose,
        )
        return TranscriptionSessionSnapshot(
            id: meeting.id,
            meeting: meeting,
            recordingSource: recordingSource,
            kernelMode: kernelMode,
            postProcessingContext: postProcessingContext,
            postProcessingContextItems: postProcessingContextItems,
            meetingNotesContent: MeetingNotesContent(
                plainText: currentMeetingNotesText,
                richTextRTFData: currentMeetingNotesRichTextData,
            ),
            dictationSessionOutputLanguageOverride: dictationSessionOutputLanguageOverride,
            dictationStartBundleIdentifier: dictationStartBundleIdentifier,
            dictationStartURL: dictationStartURL,
            dictationStyleID: activeDictationStyleSnapshot?.id,
            dictationTextHandlingPolicy: activeDictationStyleSnapshot?.textHandlingPolicy,
            dictationTranscriptionConfiguration: activeDictationStyleSnapshot?.transcriptionConfiguration,
            transcriptionConfiguration: activeTranscriptionConfiguration,
            dictationEnhancementsSelection: activeDictationStyleSnapshot?.enhancementsSelection,
            postProcessingEnhancementsSelection: AppSettingsStore.shared.enhancementsSelection(for: kernelMode),
            dictationPostProcessingEnabled: activeDictationStyleSnapshot?.postProcessingEnabled,
            dictationStyle: activeDictationStyleSnapshot,
            vocabularySnapshot: activeVocabularySnapshot ?? VocabularySnapshot.current(from: .shared),
        )
    }
}

// MARK: - Dictation Language

public extension RecordingManager {
    var effectiveDictationOutputLanguageForCurrentRecording: DictationOutputLanguage {
        if let override = dictationSessionOutputLanguageOverride {
            return override
        }

        let settings = AppSettingsStore.shared
        return matchingDictationAppRule(settings: settings)?.outputLanguage ?? .original
    }

    func setDictationSessionOutputLanguageOverride(_ language: DictationOutputLanguage?) {
        dictationSessionOutputLanguageOverride = language
    }
}

// MARK: - VocabularySnapshot Factory

@MainActor
extension VocabularySnapshot {
    /// Creates a snapshot from the current `AppSettingsStore` values.
    static func current(from settings: AppSettingsStore) -> VocabularySnapshot {
        VocabularySnapshot(
            terms: settings.vocabularyTerms,
            replacementRules: settings.vocabularyReplacementRules,
        )
    }
}
