@preconcurrency import AVFoundation
@testable import MeetingAssistantCoreAudio
import XCTest

final class RustEnergyMeterKernelTests: XCTestCase {
    private var originalRustDylibPath: String?

    override func setUp() {
        super.setUp()
        if let value = getenv("MA_RUST_AUDIO_KERNELS_DYLIB_PATH") {
            originalRustDylibPath = String(cString: value)
        } else {
            originalRustDylibPath = nil
        }
    }

    override func tearDown() {
        if let originalRustDylibPath {
            setenv("MA_RUST_AUDIO_KERNELS_DYLIB_PATH", originalRustDylibPath, 1)
        } else {
            unsetenv("MA_RUST_AUDIO_KERNELS_DYLIB_PATH")
        }
        super.tearDown()
    }

    func testMakeMeterSnapshot_WhenFFIProvidesRmsPeak_UsesFFIResultForGlobalMeters() throws {
        let buffer = try makeMonoBuffer(samples: [0.2, 0.3, 0.4, 0.5])
        let ffi = RustAudioKernelFFI(
            versionImpl: { 1 },
            computeRmsPeakImpl: { _, _, outResult in
                let pointer = outResult!.assumingMemoryBound(to: AKRmsPeakResult.self)
                pointer.pointee = AKRmsPeakResult(rms_linear: 0.5, peak_linear: 0.75)
                return RustAudioKernelFFI.ResultCode.ok.rawValue
            },
        )
        let kernel = RustEnergyMeterKernel(ffi: ffi)

        let snapshot = try XCTUnwrap(kernel.makeMeterSnapshot(from: buffer, barCount: 2))

        XCTAssertEqual(snapshot.averagePowerDB, 20.0 * log10(0.5), accuracy: 0.001)
        XCTAssertEqual(snapshot.peakPowerDB, 20.0 * log10(0.75), accuracy: 0.001)
        XCTAssertEqual(snapshot.barPowerDBLevels.count, 2)
    }

    func testComputeRmsPeak_UsesUnsafeBufferWithoutChangingInputShape() throws {
        let ffi = RustAudioKernelFFI(
            versionImpl: { 1 },
            computeRmsPeakImpl: { samples, count, outResult in
                guard let samples, count == 3 else {
                    return RustAudioKernelFFI.ResultCode.invalidArgument.rawValue
                }
                let pointer = outResult!.assumingMemoryBound(to: AKRmsPeakResult.self)
                pointer.pointee = AKRmsPeakResult(
                    rms_linear: samples[0],
                    peak_linear: samples[count - 1],
                )
                return RustAudioKernelFFI.ResultCode.ok.rawValue
            },
        )

        let samples: [Float] = [0.1, 0.2, 0.3]
        let result = try XCTUnwrap(samples.withUnsafeBufferPointer { buffer in
            ffi.computeRmsPeak(samples: buffer)
        })

        XCTAssertEqual(result.rmsLinear, 0.1, accuracy: 0.001)
        XCTAssertEqual(result.peakLinear, 0.3, accuracy: 0.001)
    }

    func testMakeMeterSnapshot_WhenFFIFails_FallsBackToSwift() throws {
        let buffer = try makeMonoBuffer(samples: [0.0, 1.0, 0.0, 0.5])
        let swiftSnapshot = try XCTUnwrap(
            SwiftEnergyMeterKernel.shared.makeMeterSnapshot(from: buffer, barCount: 2),
        )

        let ffi = RustAudioKernelFFI(
            versionImpl: { 1 },
            computeRmsPeakImpl: { _, _, _ in
                RustAudioKernelFFI.ResultCode.invalidArgument.rawValue
            },
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
            SwiftEnergyMeterKernel.shared.makeMeterSnapshot(from: buffer, barCount: 2),
        )

        let kernel = RustEnergyMeterKernel(ffi: nil)
        let rustSnapshot = try XCTUnwrap(kernel.makeMeterSnapshot(from: buffer, barCount: 2))

        XCTAssertEqual(rustSnapshot.averagePowerDB, swiftSnapshot.averagePowerDB, accuracy: 0.001)
        XCTAssertEqual(rustSnapshot.peakPowerDB, swiftSnapshot.peakPowerDB, accuracy: 0.001)
        XCTAssertEqual(rustSnapshot.barPowerDBLevels, swiftSnapshot.barPowerDBLevels)
    }

    func testLoadFromProcessSymbols_WithBundledRustDylibPath_UsesRustImplementation() throws {
        let buffer = try makeMonoBuffer(samples: [0.2, 0.3, 0.4, 0.5])
        let swiftSnapshot = try XCTUnwrap(
            SwiftEnergyMeterKernel.shared.makeMeterSnapshot(from: buffer, barCount: 2),
        )
        guard let dylibPath = resolveRustDylibPath() else {
            throw XCTSkip("Rust dylib not staged; run build with MA_RUST_AUDIO_KERNELS_BUILD=on")
        }
        setenv("MA_RUST_AUDIO_KERNELS_DYLIB_PATH", dylibPath, 1)

        let ffi = RustAudioKernelFFI.loadFromProcessSymbols()
        XCTAssertNotNil(ffi)

        let kernel = RustEnergyMeterKernel(ffi: ffi)
        let rustSnapshot = try XCTUnwrap(kernel.makeMeterSnapshot(from: buffer, barCount: 2))

        XCTAssertEqual(rustSnapshot.averagePowerDB, swiftSnapshot.averagePowerDB, accuracy: 0.001)
        XCTAssertEqual(rustSnapshot.peakPowerDB, swiftSnapshot.peakPowerDB, accuracy: 0.001)
        XCTAssertEqual(rustSnapshot.barPowerDBLevels, swiftSnapshot.barPowerDBLevels)
    }

    func testMakeMeterSnapshot_WithStereoInput_FallsBackToSwiftEvenWithFFI() throws {
        let buffer = try makeStereoBuffer(
            left: [0.0, 0.25, 0.0, 0.25],
            right: [0.0, 0.75, 0.0, 0.75],
        )
        let swiftSnapshot = try XCTUnwrap(
            SwiftEnergyMeterKernel.shared.makeMeterSnapshot(from: buffer, barCount: 2),
        )

        let ffi = RustAudioKernelFFI(
            versionImpl: { 1 },
            computeRmsPeakImpl: { _, _, outResult in
                let pointer = outResult!.assumingMemoryBound(to: AKRmsPeakResult.self)
                pointer.pointee = AKRmsPeakResult(rms_linear: 0.0_001, peak_linear: 0.0_001)
                return RustAudioKernelFFI.ResultCode.ok.rawValue
            },
        )
        let kernel = RustEnergyMeterKernel(ffi: ffi)

        let rustSnapshot = try XCTUnwrap(kernel.makeMeterSnapshot(from: buffer, barCount: 2))

        XCTAssertEqual(rustSnapshot.averagePowerDB, swiftSnapshot.averagePowerDB, accuracy: 0.001)
        XCTAssertEqual(rustSnapshot.peakPowerDB, swiftSnapshot.peakPowerDB, accuracy: 0.001)
    }

    func testPerformance_MeterSnapshot_SwiftBaseline() throws {
        let buffer = try makeBenchmarkBuffer()

        measure {
            _ = SwiftEnergyMeterKernel.shared.makeMeterSnapshot(from: buffer, barCount: 16)
        }
    }

    func testPerformance_MeterSnapshot_RustPilotInjectedNoCopy() throws {
        let buffer = try makeBenchmarkBuffer()
        let ffi = RustAudioKernelFFI(
            versionImpl: { 1 },
            computeRmsPeakImpl: { _, _, outResult in
                let pointer = outResult!.assumingMemoryBound(to: AKRmsPeakResult.self)
                pointer.pointee = AKRmsPeakResult(rms_linear: 0.5, peak_linear: 0.75)
                return RustAudioKernelFFI.ResultCode.ok.rawValue
            },
        )
        let kernel = RustEnergyMeterKernel(ffi: ffi)

        measure {
            _ = kernel.makeMeterSnapshot(from: buffer, barCount: 16)
        }
    }

    func testPerformance_MeterSnapshot_RustPilotRealDylib() throws {
        guard let dylibPath = resolveRustDylibPath() else {
            throw XCTSkip("Rust dylib not staged; run build with MA_RUST_AUDIO_KERNELS_BUILD=on")
        }
        setenv("MA_RUST_AUDIO_KERNELS_DYLIB_PATH", dylibPath, 1)
        guard let ffi = RustAudioKernelFFI.loadFromProcessSymbols() else {
            throw XCTSkip("Rust dylib does not expose the expected FFI symbols")
        }

        let buffer = try makeBenchmarkBuffer()
        let kernel = RustEnergyMeterKernel(ffi: ffi)

        measure {
            _ = kernel.makeMeterSnapshot(from: buffer, barCount: 16)
        }
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

    private func makeBenchmarkBuffer() throws -> AVAudioPCMBuffer {
        let samples = (0..<4_096).map { index in
            sin(Float(index) * 0.013) * 0.8
        }
        return try makeMonoBuffer(samples: samples)
    }

    private func makeStereoBuffer(
        left: [Float],
        right: [Float],
        sampleRate: Double = 48_000,
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

    private func resolveRustDylibPath() -> String? {
        let rootPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        let directPath = "\(rootPath)/.xcode-build/Build/Products/Debug/Prisma.app/Contents/Frameworks/libaudio_kernels_rust.dylib"
        if FileManager.default.fileExists(atPath: directPath) {
            return directPath
        }

        let xpcPath = "\(rootPath)/.xcode-build/Build/Products/Debug/PrismaAI.xpc/Contents/Frameworks/libaudio_kernels_rust.dylib"
        if FileManager.default.fileExists(atPath: xpcPath) {
            return xpcPath
        }

        return nil
    }
}
