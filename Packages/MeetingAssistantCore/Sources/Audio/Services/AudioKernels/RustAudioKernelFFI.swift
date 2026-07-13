import Darwin
import Foundation

struct RustAudioKernelFFI: @unchecked Sendable {
    enum ResultCode: Int32 {
        case ok = 0
        case nullPointer = 1
        case invalidArgument = 2
    }

    struct RmsPeakResult {
        let rmsLinear: Float
        let peakLinear: Float
    }

    enum LoadSource: String {
        case processSymbols
        case environmentOverride
        case bundledFrameworks
        case unavailable

        var diagnosticsValue: String {
            switch self {
            case .processSymbols:
                "process_symbols"
            case .environmentOverride:
                "environment_override"
            case .bundledFrameworks:
                "bundled_frameworks"
            case .unavailable:
                "unavailable"
            }
        }
    }

    struct LoadResult {
        let ffi: RustAudioKernelFFI?
        let source: LoadSource
        let libraryPath: String?
    }

    private struct LibraryCandidate {
        let path: String
        let source: LoadSource
    }

    typealias VersionFunction = @convention(c) () -> UInt32
    typealias ComputeRmsPeakFunction = @convention(c) (
        UnsafePointer<Float>?,
        Int,
        UnsafeMutableRawPointer?,
    ) -> Int32

    private let versionImpl: VersionFunction
    private let computeRmsPeakImpl: ComputeRmsPeakFunction

    init(
        versionImpl: @escaping VersionFunction,
        computeRmsPeakImpl: @escaping ComputeRmsPeakFunction,
    ) {
        self.versionImpl = versionImpl
        self.computeRmsPeakImpl = computeRmsPeakImpl
    }

    func version() -> UInt32 {
        versionImpl()
    }

    func computeRmsPeak(samples: [Float]) -> RmsPeakResult? {
        guard !samples.isEmpty else { return nil }

        return samples.withUnsafeBufferPointer { buffer in
            computeRmsPeak(samples: buffer)
        }
    }

    func computeRmsPeak(samples: UnsafeBufferPointer<Float>) -> RmsPeakResult? {
        guard !samples.isEmpty else { return nil }

        var ffiResult = AKRmsPeakResult(rms_linear: 0, peak_linear: 0)
        let ffiCode = withUnsafeMutablePointer(to: &ffiResult) { resultPointer in
            computeRmsPeakImpl(samples.baseAddress, samples.count, UnsafeMutableRawPointer(resultPointer))
        }

        guard ResultCode(rawValue: ffiCode) == .ok else {
            return nil
        }

        return RmsPeakResult(
            rmsLinear: ffiResult.rms_linear,
            peakLinear: ffiResult.peak_linear,
        )
    }
}

struct AKRmsPeakResult {
    var rms_linear: Float
    var peak_linear: Float
}

extension RustAudioKernelFFI {
    static func loadForRuntime() -> LoadResult {
        if let ffi = loadFromSymbols(symbolHandle: UnsafeMutableRawPointer(bitPattern: -2)) {
            return .init(
                ffi: ffi,
                source: .processSymbols,
                libraryPath: nil,
            )
        }

        if let loadResult = loadFromBundledDynamicLibrary() {
            return loadResult
        }

        return .init(
            ffi: nil,
            source: .unavailable,
            libraryPath: nil,
        )
    }

    static func loadFromProcessSymbols() -> RustAudioKernelFFI? {
        loadForRuntime().ffi
    }

    private static func loadFromSymbols(symbolHandle: UnsafeMutableRawPointer?) -> RustAudioKernelFFI? {
        guard let versionSymbol = dlsym(symbolHandle, "ak_version"),
              let rmsPeakSymbol = dlsym(symbolHandle, "ak_compute_rms_peak_f32")
        else {
            return nil
        }

        let versionImpl = unsafeBitCast(versionSymbol, to: VersionFunction.self)
        let computeRmsPeakImpl = unsafeBitCast(rmsPeakSymbol, to: ComputeRmsPeakFunction.self)

        return RustAudioKernelFFI(
            versionImpl: versionImpl,
            computeRmsPeakImpl: computeRmsPeakImpl,
        )
    }

    private static func loadFromBundledDynamicLibrary() -> LoadResult? {
        let loadFlags = RTLD_NOW | RTLD_LOCAL
        for candidate in bundledLibraryCandidatePaths() {
            guard let handle = dlopen(candidate.path, loadFlags) else {
                continue
            }

            guard let ffi = loadFromSymbols(symbolHandle: handle) else {
                dlclose(handle)
                continue
            }

            return .init(
                ffi: ffi,
                source: candidate.source,
                libraryPath: candidate.path,
            )
        }

        return nil
    }

    private static func bundledLibraryCandidatePaths() -> [LibraryCandidate] {
        let libraryName = "libaudio_kernels_rust.dylib"
        var candidates: [LibraryCandidate] = []

        let envPath = ProcessInfo.processInfo.environment["MA_RUST_AUDIO_KERNELS_DYLIB_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let envPath, !envPath.isEmpty {
            candidates.append(LibraryCandidate(path: envPath, source: .environmentOverride))
        }

        if let frameworksURL = Bundle.main.privateFrameworksURL {
            candidates.append(
                LibraryCandidate(
                    path: frameworksURL.appendingPathComponent(libraryName).path,
                    source: .bundledFrameworks,
                ),
            )
        }

        if let executableURL = Bundle.main.executableURL {
            let frameworkURL = executableURL
                .deletingLastPathComponent()
                .appendingPathComponent("../Frameworks/\(libraryName)")
                .standardizedFileURL
            candidates.append(
                LibraryCandidate(
                    path: frameworkURL.path,
                    source: .bundledFrameworks,
                ),
            )
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.path).inserted }
    }
}
