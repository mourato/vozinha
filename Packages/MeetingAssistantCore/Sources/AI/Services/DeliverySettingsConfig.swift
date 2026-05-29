import Foundation
import MeetingAssistantCoreInfrastructure

/// Protocol abstraction for settings required by TranscriptionDeliveryService.
@MainActor
public protocol DeliverySettingsConfig {
    var autoCopyTranscriptionToClipboard: Bool { get }
    var autoPasteTranscriptionToActiveApp: Bool { get }
    var smartSpacingAndCapitalizationEnabled: Bool { get }
}

/// Extend existing AppSettingsStore to conform to the protocol directly.
/// This avoids needing wrapper code since the properties match.
extension AppSettingsStore: DeliverySettingsConfig {}
