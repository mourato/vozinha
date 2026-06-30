import Foundation

public protocol VocabularyReplaceableSegment {
    var id: UUID { get }
    var speaker: String { get }
    var text: String { get }
    var startTime: Double { get }
    var endTime: Double { get }
    init(id: UUID, speaker: String, text: String, startTime: Double, endTime: Double)
}

extension Transcription.Segment: VocabularyReplaceableSegment {}
extension DomainTranscriptionSegment: VocabularyReplaceableSegment {}
