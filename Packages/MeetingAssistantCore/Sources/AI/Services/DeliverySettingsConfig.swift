import Foundation
import MeetingAssistantCoreInfrastructure

/// Protocol abstraction for settings required by TranscriptionDeliveryService.
@MainActor
public protocol DeliverySettingsConfig {
    var autoCopyTranscriptionToClipboard: Bool { get }
    var autoPasteTranscriptionToActiveApp: Bool { get }
    var smartSpacingAndCapitalizationEnabled: Bool { get }
    var smartParagraphsEnabled: Bool { get }
}

/// Immutable delivery policy captured at the operation edge.
@MainActor
public struct DeliverySettingsSnapshot: DeliverySettingsConfig {
    public let autoCopyTranscriptionToClipboard: Bool
    public let autoPasteTranscriptionToActiveApp: Bool
    public let smartSpacingAndCapitalizationEnabled: Bool
    public let smartParagraphsEnabled: Bool

    public init(settings: any DeliverySettingsConfig) {
        autoCopyTranscriptionToClipboard = settings.autoCopyTranscriptionToClipboard
        autoPasteTranscriptionToActiveApp = settings.autoPasteTranscriptionToActiveApp
        smartSpacingAndCapitalizationEnabled = settings.smartSpacingAndCapitalizationEnabled
        smartParagraphsEnabled = settings.smartParagraphsEnabled
    }
}

/// Extend existing AppSettingsStore to conform to the protocol directly.
/// This avoids needing wrapper code since the properties match.
extension AppSettingsStore: DeliverySettingsConfig {}
