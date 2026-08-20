import Foundation
import MeetingAssistantCoreDomain

extension TranscriptionSettingsViewModel {
    func sortedSegments(_ segments: [Transcription.Segment]) -> [Transcription.Segment] {
        segments.sorted(by: Self.segmentSortComparator)
    }
}
