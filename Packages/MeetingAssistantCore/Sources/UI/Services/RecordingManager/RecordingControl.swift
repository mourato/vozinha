import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Recording Control State

extension RecordingManager {
    func makeTranscriptionSessionSnapshot(_ meeting: Meeting) -> TranscriptionSessionSnapshot {
        TranscriptionSessionSnapshot(
            id: meeting.id,
            meeting: meeting,
            recordingSource: recordingSource,
            kernelMode: postProcessingKernelMode(
                for: meeting,
                capturePurposeOverride: meeting.capturePurpose,
            ),
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
            dictationEnhancementsSelection: activeDictationStyleSnapshot?.enhancementsSelection,
            dictationPostProcessingEnabled: activeDictationStyleSnapshot?.postProcessingEnabled,
            dictationStyle: activeDictationStyleSnapshot,
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
