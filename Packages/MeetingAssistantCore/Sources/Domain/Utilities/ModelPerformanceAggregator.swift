import Foundation

public enum ModelPerformanceAggregator {

    public static func computeAnalysis(transcriptions: [Transcription]) -> ModelPerformanceAnalysis {
        let totalTranscripts = transcriptions.count
        let totalWithData = transcriptions.count(where: { $0.transcriptionDuration > 0 })
        let totalAudioDuration = transcriptions.reduce(0) { $0 + $1.meeting.duration }
        let totalProcessed = transcriptions.count(where: { $0.isPostProcessed && $0.postProcessingDuration > 0 })

        let transcriptionStats = processStats(
            for: transcriptions,
            modelNameKeyPath: \.modelName,
            durationKeyPath: \.transcriptionDuration,
            audioDurationKeyPath: \.meeting.duration
        )

        let enhancementStats = processStats(
            for: transcriptions,
            modelNameKeyPath: \.postProcessingModel,
            durationKeyPath: \.postProcessingDuration,
            audioDurationKeyPath: \.meeting.duration
        )

        return ModelPerformanceAnalysis(
            totalTranscripts: totalTranscripts,
            totalWithData: totalWithData,
            totalAudioDuration: totalAudioDuration,
            totalProcessed: totalProcessed,
            transcriptionModels: transcriptionStats,
            enhancementModels: enhancementStats
        )
    }

    static func processStats(
        for transcriptions: [Transcription],
        modelNameKeyPath: KeyPath<Transcription, String>,
        durationKeyPath: KeyPath<Transcription, Double>,
        audioDurationKeyPath: KeyPath<Transcription, TimeInterval>? = nil
    ) -> [ModelPerformanceStat] {
        computeStats(
            for: transcriptions,
            extractModelName: { $0[keyPath: modelNameKeyPath] },
            extractDuration: durationKeyPath,
            extractAudioDuration: audioDurationKeyPath
        )
    }

    static func processStats(
        for transcriptions: [Transcription],
        modelNameKeyPath: KeyPath<Transcription, String?>,
        durationKeyPath: KeyPath<Transcription, Double>,
        audioDurationKeyPath: KeyPath<Transcription, TimeInterval>? = nil
    ) -> [ModelPerformanceStat] {
        computeStats(
            for: transcriptions,
            extractModelName: { $0[keyPath: modelNameKeyPath] ?? "Unknown" },
            extractDuration: durationKeyPath,
            extractAudioDuration: audioDurationKeyPath
        )
    }

    private static func computeStats(
        for transcriptions: [Transcription],
        extractModelName: (Transcription) -> String,
        extractDuration: KeyPath<Transcription, Double>,
        extractAudioDuration: KeyPath<Transcription, TimeInterval>?
    ) -> [ModelPerformanceStat] {
        let relevant = transcriptions.filter { $0[keyPath: extractDuration] > 0 }
        let grouped = Dictionary(grouping: relevant) { extractModelName($0) }

        return grouped.map { modelName, items in
            let fileCount = items.count
            let totalProcessingTime = items.reduce(0) { $0 + $1[keyPath: extractDuration] }
            let avgProcessingTime = totalProcessingTime / Double(fileCount)

            let totalAudioDuration: TimeInterval
            if let extractAudioDuration {
                totalAudioDuration = items.reduce(0) { $0 + $1[keyPath: extractAudioDuration] }
            } else {
                totalAudioDuration = items.reduce(0) { $0 + $1.meeting.duration }
            }
            let avgAudioDuration = totalAudioDuration / Double(fileCount)

            var speedFactor = 0.0
            if let extractAudioDuration {
                let ratios = items.compactMap { item -> Double? in
                    let audio = item[keyPath: extractAudioDuration]
                    let proc = item[keyPath: extractDuration]
                    guard proc > 0, audio > 0 else { return nil }
                    return audio / proc
                }
                if !ratios.isEmpty {
                    speedFactor = ratios.reduce(0, +) / Double(ratios.count)
                }
            }

            return ModelPerformanceStat(
                name: modelName,
                fileCount: fileCount,
                totalProcessingTime: totalProcessingTime,
                avgProcessingTime: avgProcessingTime,
                avgAudioDuration: avgAudioDuration,
                speedFactor: speedFactor
            )
        }
        .sorted { $0.avgProcessingTime < $1.avgProcessingTime }
    }
}
