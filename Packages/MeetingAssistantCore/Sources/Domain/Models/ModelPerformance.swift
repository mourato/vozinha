import Foundation
import MeetingAssistantCoreCommon

public struct ModelPerformanceStat: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let name: String
    public let fileCount: Int
    public let totalProcessingTime: TimeInterval
    public let avgProcessingTime: TimeInterval
    public let avgAudioDuration: TimeInterval
    public let speedFactor: Double

    public init(
        name: String,
        fileCount: Int,
        totalProcessingTime: TimeInterval,
        avgProcessingTime: TimeInterval,
        avgAudioDuration: TimeInterval,
        speedFactor: Double
    ) {
        self.name = name
        self.fileCount = fileCount
        self.totalProcessingTime = totalProcessingTime
        self.avgProcessingTime = avgProcessingTime
        self.avgAudioDuration = avgAudioDuration
        self.speedFactor = speedFactor
    }
}

public struct ModelPerformanceAnalysis: Equatable, Sendable {
    public let totalTranscripts: Int
    public let totalWithData: Int
    public let totalAudioDuration: TimeInterval
    public let totalProcessed: Int
    public let transcriptionModels: [ModelPerformanceStat]
    public let enhancementModels: [ModelPerformanceStat]

    public init(
        totalTranscripts: Int,
        totalWithData: Int,
        totalAudioDuration: TimeInterval,
        totalProcessed: Int,
        transcriptionModels: [ModelPerformanceStat],
        enhancementModels: [ModelPerformanceStat]
    ) {
        self.totalTranscripts = totalTranscripts
        self.totalWithData = totalWithData
        self.totalAudioDuration = totalAudioDuration
        self.totalProcessed = totalProcessed
        self.transcriptionModels = transcriptionModels
        self.enhancementModels = enhancementModels
    }

    public static let empty = ModelPerformanceAnalysis(
        totalTranscripts: 0,
        totalWithData: 0,
        totalAudioDuration: 0,
        totalProcessed: 0,
        transcriptionModels: [],
        enhancementModels: []
    )
}

public enum PerformanceFilter: String, CaseIterable, Sendable {
    case all
    case dictation
    case meeting

    public var displayName: String {
        switch self {
        case .all: "metrics.performance.filter.all".localized
        case .dictation: "metrics.performance.filter.dictation".localized
        case .meeting: "metrics.performance.filter.meeting".localized
        }
    }
}
