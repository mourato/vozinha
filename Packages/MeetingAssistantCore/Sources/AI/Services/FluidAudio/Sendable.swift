@preconcurrency import FluidAudio
import Foundation

// MARK: - Sendable Conformances for FluidAudio

extension OfflineDiarizerManager: @unchecked @retroactive Sendable {}

// Note: AsrManager is an actor and Granite models, DiarizationResult,
// OfflineDiarizerConfig, and TokenTiming are already Sendable in FluidAudio
// at pinned revision 3fd6388, so no local patches are needed.
