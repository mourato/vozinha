import Darwin
import Foundation

struct RustAudioKernelFFI {
    enum ResultCode: Int32 {
        case ok = 0
        case nullPointer = 1
        case invalidArgument = 2
    }

    struct RmsPeakResult {
        let rmsLinear: Float
        let peakLinear: Float
    }

    typealias VersionFunction = @convention(c) () -> UInt32
    typealias ComputeRmsPeakFunction = @convention(c) (
        UnsafePointer<Float>?,
        Int,
        UnsafeMutablePointer<AKRmsPeakResult>
    ) -> AKResultCode

    private let versionImpl: VersionFunction
    private let computeRmsPeakImpl: ComputeRmsPeakFunction

    init(
        versionImpl: @escaping VersionFunction,
        computeRmsPeakImpl: @escaping ComputeRmsPeakFunction
    ) {
        self.versionImpl = versionImpl
        self.computeRmsPeakImpl = computeRmsPeakImpl
    }

    func version() -> UInt32 {
        versionImpl()
    }

    func computeRmsPeak(samples: [Float]) -> RmsPeakResult? {
        guard !samples.isEmpty else { return nil }

        var ffiResult = AKRmsPeakResult(rms_linear: 0, peak_linear: 0)
        let ffiCode = samples.withUnsafeBufferPointer { buffer in
            computeRmsPeakImpl(buffer.baseAddress, buffer.count, &ffiResult)
        }

        guard ResultCode(rawValue: ffiCode.code) == .ok else {
            return nil
        }

        return RmsPeakResult(
            rmsLinear: ffiResult.rms_linear,
            peakLinear: ffiResult.peak_linear
        )
    }
}

struct AKResultCode {
    let code: Int32
}

struct AKRmsPeakResult {
    var rms_linear: Float
    var peak_linear: Float
}

extension RustAudioKernelFFI {
    static func loadFromProcessSymbols() -> RustAudioKernelFFI? {
        guard let versionSymbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "ak_version"),
              let rmsPeakSymbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "ak_compute_rms_peak_f32")
        else {
            return nil
        }

        let versionImpl = unsafeBitCast(versionSymbol, to: VersionFunction.self)
        let computeRmsPeakImpl = unsafeBitCast(rmsPeakSymbol, to: ComputeRmsPeakFunction.self)

        return RustAudioKernelFFI(
            versionImpl: versionImpl,
            computeRmsPeakImpl: computeRmsPeakImpl
        )
    }
}
