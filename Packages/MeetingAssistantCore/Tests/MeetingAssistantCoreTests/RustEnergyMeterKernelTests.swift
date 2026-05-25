@preconcurrency import AVFoundation
@testable import MeetingAssistantCoreAudio
import XCTest

final class RustEnergyMeterKernelTests: XCTestCase {
    func testMakeMeterSnapshot_WhenFFIProvidesRmsPeak_UsesFFIResultForGlobalMeters() throws {
        let buffer = try makeMonoBuffer(samples: [0.2, 0.3, 0.4, 0.5])
        let ffi = RustAudioKernelFFI(
            versionImpl: { 1 },
            computeRmsPeakImpl: { _, _, outResult in
                let pointer = outResult!.assumingMemoryBound(to: AKRmsPeakResult.self)
                pointer.pointee = AKRmsPeakResult(rms_linear: 0.5, peak_linear: 0.75)
                return RustAudioKernelFFI.ResultCode.ok.rawValue
            }
        )
        let kernel = RustEnergyMeterKernel(ffi: ffi)

        let snapshot = try XCTUnwrap(kernel.makeMeterSnapshot(from: buffer, barCount: 2))

        XCTAssertEqual(snapshot.averagePowerDB, 20.0 * log10(0.5), accuracy: 0.001)
        XCTAssertEqual(snapshot.peakPowerDB, 20.0 * log10(0.75), accuracy: 0.001)
        XCTAssertEqual(snapshot.barPowerDBLevels.count, 2)
    }

    func testMakeMeterSnapshot_WhenFFIFails_FallsBackToSwift() throws {
        let buffer = try makeMonoBuffer(samples: [0.0, 1.0, 0.0, 0.5])
        let swiftSnapshot = try XCTUnwrap(
            SwiftEnergyMeterKernel.shared.makeMeterSnapshot(from: buffer, barCount: 2)
        )

        let ffi = RustAudioKernelFFI(
            versionImpl: { 1 },
            computeRmsPeakImpl: { _, _, _ in
                RustAudioKernelFFI.ResultCode.invalidArgument.rawValue
            }
        )
        let kernel = RustEnergyMeterKernel(ffi: ffi)

        let rustSnapshot = try XCTUnwrap(kernel.makeMeterSnapshot(from: buffer, barCount: 2))

        XCTAssertEqual(rustSnapshot.averagePowerDB, swiftSnapshot.averagePowerDB, accuracy: 0.001)
        XCTAssertEqual(rustSnapshot.peakPowerDB, swiftSnapshot.peakPowerDB, accuracy: 0.001)
        XCTAssertEqual(rustSnapshot.barPowerDBLevels, swiftSnapshot.barPowerDBLevels)
    }

    func testMakeMeterSnapshot_WhenFFISymbolsUnavailable_FallsBackToSwift() throws {
        let buffer = try makeMonoBuffer(samples: [0.1, 0.2, 0.3, 0.4])
        let swiftSnapshot = try XCTUnwrap(
            SwiftEnergyMeterKernel.shared.makeMeterSnapshot(from: buffer, barCount: 2)
        )

        let kernel = RustEnergyMeterKernel(ffi: nil)
        let rustSnapshot = try XCTUnwrap(kernel.makeMeterSnapshot(from: buffer, barCount: 2))

        XCTAssertEqual(rustSnapshot.averagePowerDB, swiftSnapshot.averagePowerDB, accuracy: 0.001)
        XCTAssertEqual(rustSnapshot.peakPowerDB, swiftSnapshot.peakPowerDB, accuracy: 0.001)
        XCTAssertEqual(rustSnapshot.barPowerDBLevels, swiftSnapshot.barPowerDBLevels)
    }

    func testMakeMeterSnapshot_WithStereoInput_FallsBackToSwiftEvenWithFFI() throws {
        let buffer = try makeStereoBuffer(
            left: [0.0, 0.25, 0.0, 0.25],
            right: [0.0, 0.75, 0.0, 0.75]
        )
        let swiftSnapshot = try XCTUnwrap(
            SwiftEnergyMeterKernel.shared.makeMeterSnapshot(from: buffer, barCount: 2)
        )

        let ffi = RustAudioKernelFFI(
            versionImpl: { 1 },
            computeRmsPeakImpl: { _, _, outResult in
                let pointer = outResult!.assumingMemoryBound(to: AKRmsPeakResult.self)
                pointer.pointee = AKRmsPeakResult(rms_linear: 0.0001, peak_linear: 0.0001)
                return RustAudioKernelFFI.ResultCode.ok.rawValue
            }
        )
        let kernel = RustEnergyMeterKernel(ffi: ffi)

        let rustSnapshot = try XCTUnwrap(kernel.makeMeterSnapshot(from: buffer, barCount: 2))

        XCTAssertEqual(rustSnapshot.averagePowerDB, swiftSnapshot.averagePowerDB, accuracy: 0.001)
        XCTAssertEqual(rustSnapshot.peakPowerDB, swiftSnapshot.peakPowerDB, accuracy: 0.001)
    }

    private func makeMonoBuffer(samples: [Float], sampleRate: Double = 48_000) throws -> AVAudioPCMBuffer {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let frameCount = AVAudioFrameCount(samples.count)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else {
            throw NSError(domain: "RustEnergyMeterKernelTests", code: 1)
        }

        for (index, sample) in samples.enumerated() {
            channelData[0][index] = sample
        }
        return buffer
    }

    private func makeStereoBuffer(
        left: [Float],
        right: [Float],
        sampleRate: Double = 48_000
    ) throws -> AVAudioPCMBuffer {
        XCTAssertEqual(left.count, right.count)

        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2))
        let frameCount = AVAudioFrameCount(left.count)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else {
            throw NSError(domain: "RustEnergyMeterKernelTests", code: 2)
        }

        for index in 0..<left.count {
            channelData[0][index] = left[index]
            channelData[1][index] = right[index]
        }
        return buffer
    }
}
