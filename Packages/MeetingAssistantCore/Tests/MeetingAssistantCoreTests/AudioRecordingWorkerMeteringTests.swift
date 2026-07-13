import AVFoundation
@testable import MeetingAssistantCoreAudio
import XCTest

final class AudioRecordingWorkerMeteringTests: XCTestCase {
    func testMakeMeterSnapshot_ComputesPerBucketPeakFromCurrentBuffer() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8))
        buffer.frameLength = 8

        guard let channelData = buffer.floatChannelData else {
            return XCTFail("Expected float channel data")
        }

        for frame in 0..<8 {
            channelData[0][frame] = 0
        }
        channelData[0][0] = 1
        channelData[0][4] = 0.5

        let snapshot = AudioRecordingWorker.makeMeterSnapshot(from: buffer, barCount: 2)
        let unwrapped = try XCTUnwrap(snapshot)

        XCTAssertEqual(unwrapped.barPowerDBLevels.count, 2)
        XCTAssertEqual(unwrapped.peakPowerDB, 0.0, accuracy: 0.001)

        XCTAssertGreaterThan(unwrapped.barPowerDBLevels[0], -0.5)
        XCTAssertLessThan(unwrapped.barPowerDBLevels[1], -5.5)
        XCTAssertGreaterThan(unwrapped.barPowerDBLevels[1], -6.5)

        XCTAssertLessThan(unwrapped.averagePowerDB, -8.0)
        XCTAssertGreaterThan(unwrapped.averagePowerDB, -12.5)
        XCTAssertEqual(unwrapped.deltaTime, 8.0 / 48_000.0, accuracy: 0.000_001)
    }

    func testMakeMeterSnapshot_PreservesIndependentBucketsWithoutRMSSmoothing() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8))
        buffer.frameLength = 8

        guard let channelData = buffer.floatChannelData else {
            return XCTFail("Expected float channel data")
        }

        for frame in 0..<8 {
            channelData[0][frame] = 0
        }
        channelData[0][0] = 1
        channelData[0][7] = 0.25

        let snapshot = try XCTUnwrap(AudioRecordingWorker.makeMeterSnapshot(from: buffer, barCount: 2))

        XCTAssertGreaterThan(snapshot.barPowerDBLevels[0], -0.5)
        XCTAssertLessThan(snapshot.barPowerDBLevels[1], -11.5)
        XCTAssertGreaterThan(snapshot.barPowerDBLevels[1], -12.5)
    }

    func testMakeMeterSnapshot_WithZeroBarCount_ReturnsOnlyGlobalMeters() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4))
        buffer.frameLength = 4
        buffer.floatChannelData?[0][0] = 0.25
        buffer.floatChannelData?[0][1] = 0.25
        buffer.floatChannelData?[0][2] = 0.25
        buffer.floatChannelData?[0][3] = 0.25

        let snapshot = try XCTUnwrap(AudioRecordingWorker.makeMeterSnapshot(from: buffer, barCount: 0))

        XCTAssertTrue(snapshot.barPowerDBLevels.isEmpty)
        XCTAssertLessThan(snapshot.averagePowerDB, 0.0)
        XCTAssertGreaterThan(snapshot.peakPowerDB, -13.0)
        XCTAssertEqual(snapshot.deltaTime, 4.0 / 48_000.0, accuracy: 0.000_001)
    }

    func testMakeMeterSnapshot_WithInvalidSampleRate_ReturnsNil() throws {
        let format = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 0, channels: 1, interleaved: false))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4))
        buffer.frameLength = 4

        XCTAssertNil(AudioRecordingWorker.makeMeterSnapshot(from: buffer, barCount: 2))
    }
}
