@testable import MeetingAssistantCoreAudio
import XCTest

@MainActor
final class AudioLevelMonitorTests: XCTestCase {
    func testDefaultSamplingInterval_IsApproximatelySixtyHertz() {
        let monitor = AudioLevelMonitor()

        XCTAssertEqual(monitor.effectiveSamplingInterval, 0.017, accuracy: 0.0_001)
    }

    func testIngestLevels_NormalizesDecibelsLinearly() {
        let monitor = AudioLevelMonitor(samplingInterval: 0.03)

        monitor.ingestLevels(averageDB: -60, peakDB: -60)
        XCTAssertEqual(monitor.audioMeter.averagePower, 0.0, accuracy: 0.001)
        XCTAssertEqual(monitor.audioMeter.peakPower, 0.0, accuracy: 0.001)

        monitor.ingestLevels(averageDB: -30, peakDB: -30)
        XCTAssertEqual(monitor.audioMeter.averagePower, 0.5, accuracy: 0.001)
        XCTAssertEqual(monitor.audioMeter.peakPower, 0.5, accuracy: 0.001)

        monitor.ingestLevels(averageDB: 0, peakDB: 0)
        XCTAssertEqual(monitor.audioMeter.averagePower, 1.0, accuracy: 0.001)
        XCTAssertEqual(monitor.audioMeter.peakPower, 1.0, accuracy: 0.001)
    }

    func testIngestLevels_BuildsCanonicalEnvelopeAndProjectedLevels() {
        let monitor = AudioLevelMonitor(samplingInterval: 0.05)

        for level in [-34.0, -28.0, -18.0, -12.0, -20.0, -26.0] {
            monitor.ingestLevels(averageDB: Float(level), peakDB: Float(level + 4), deltaTime: 0.05)
        }

        XCTAssertEqual(monitor.canonicalEnvelopeLevels.count, 48)
        XCTAssertFalse(monitor.instantBarLevels.isEmpty)
        XCTAssertEqual(monitor.recentAverageLevels, monitor.instantBarLevels)

        let projectedLevels = monitor.displayLevels(for: 18)
        XCTAssertEqual(projectedLevels.count, 18)
        XCTAssertGreaterThan(projectedLevels.max() ?? 0.0, 0.2)
    }

    func testDisplayLevels_ProducesQuasiSymmetricProfile() {
        let monitor = AudioLevelMonitor(samplingInterval: 0.05)

        for level in [-42.0, -30.0, -16.0, -8.0, -14.0, -24.0, -36.0] {
            monitor.ingestLevels(averageDB: Float(level), peakDB: Float(level + 3), deltaTime: 0.05)
        }

        let projectedLevels = monitor.displayLevels(for: 9)
        XCTAssertEqual(projectedLevels.count, 9)

        let mirroredPairs = zip(projectedLevels.prefix(4), projectedLevels.suffix(4).reversed())
        for pair in mirroredPairs {
            XCTAssertLessThan(abs(pair.0 - pair.1), 0.16)
        }

        XCTAssertGreaterThan(projectedLevels[4], projectedLevels[0])
    }

    func testIngestLevels_UsesFastAttackAndSlowDecay() {
        let monitor = AudioLevelMonitor(samplingInterval: 0.05)

        monitor.ingestLevels(averageDB: -10, peakDB: -6, deltaTime: 0.05)
        let firstPeak = monitor.canonicalEnvelopeLevels.last ?? 0.0

        for _ in 0..<6 {
            monitor.ingestLevels(averageDB: -55, peakDB: -50, deltaTime: 0.05)
        }
        let afterDrop = monitor.canonicalEnvelopeLevels.last ?? 0.0

        XCTAssertGreaterThan(firstPeak, 0.5)
        XCTAssertGreaterThan(afterDrop, 0.05)
        XCTAssertLessThan(afterDrop, firstPeak)
    }

    func testIngestLevels_CollapsesNearSilence() {
        let monitor = AudioLevelMonitor(samplingInterval: 0.05)

        for _ in 0..<20 {
            monitor.ingestLevels(averageDB: -58, peakDB: -56, deltaTime: 0.05)
        }

        XCTAssertLessThan(monitor.canonicalEnvelopeLevels.max() ?? 1.0, 0.15)
        XCTAssertLessThan(monitor.displayLevels(for: 18).max() ?? 1.0, 0.15)
    }

    func testIngestLevels_ShowsSilenceWarningAfterConfiguredDuration() {
        let monitor = AudioLevelMonitor(samplingInterval: 1.0)

        for _ in 0..<3 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80, deltaTime: 1.0)
            XCTAssertFalse(monitor.isSilenceWarningVisible)
        }

        monitor.ingestLevels(averageDB: -80, peakDB: -80, deltaTime: 1.0)
        XCTAssertTrue(monitor.isSilenceWarningVisible)
    }

    func testIngestLevels_DoesNotShowSilenceWarningOutsideStartupWindow() {
        let monitor = AudioLevelMonitor(samplingInterval: 1.0)

        for _ in 0..<10 {
            monitor.ingestLevels(averageDB: -6, peakDB: -6, deltaTime: 1.0)
        }

        for _ in 0..<8 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80, deltaTime: 1.0)
        }

        XCTAssertFalse(monitor.isSilenceWarningVisible)
    }

    func testDismissSilenceWarning_DoesNotRetriggerInSameSession() {
        let monitor = AudioLevelMonitor(samplingInterval: 1.0)

        for _ in 0..<4 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80, deltaTime: 1.0)
        }
        XCTAssertTrue(monitor.isSilenceWarningVisible)

        monitor.dismissSilenceWarning()
        XCTAssertFalse(monitor.isSilenceWarningVisible)

        for _ in 0..<8 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80, deltaTime: 1.0)
        }
        XCTAssertFalse(monitor.isSilenceWarningVisible)
    }

    func testStopMonitoring_ResetsEnvelopeAndSilenceWarningSessionState() {
        let monitor = AudioLevelMonitor(samplingInterval: 1.0)

        monitor.ingestLevels(averageDB: -20, peakDB: -10, deltaTime: 1.0)
        XCTAssertFalse(monitor.canonicalEnvelopeLevels.isEmpty)

        for _ in 0..<4 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80, deltaTime: 1.0)
        }
        XCTAssertTrue(monitor.isSilenceWarningVisible)

        monitor.stopMonitoring()
        XCTAssertTrue(monitor.canonicalEnvelopeLevels.isEmpty)

        for _ in 0..<4 {
            monitor.ingestLevels(averageDB: -80, peakDB: -80, deltaTime: 1.0)
        }
        XCTAssertTrue(monitor.isSilenceWarningVisible)
    }
}
