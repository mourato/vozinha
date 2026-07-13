import Combine
import Sparkle

/// Service wrapping Sparkle's update controller for automatic and manual update checks.
///
/// Keeps all Sparkle imports contained in a single file to avoid framework leakage
/// across architectural layers. Sparkle reads `SUFeedURL` and `SUPublicEDKey` from Info.plist.
@MainActor
public final class UpdateService {

    // MARK: - Singleton

    public static let shared = UpdateService()

    // MARK: - Properties

    private let updaterController: SPUStandardUpdaterController

    /// Publisher that emits whether a manual update check can be performed right now.
    public var canCheckForUpdates: AnyPublisher<Bool, Never> {
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private init() {
        // startingUpdater: true → Sparkle begins its automatic check schedule on init.
        // updaterDelegate / userDriverDelegate: nil → use Sparkle's default behavior.
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil,
        )
    }

    // MARK: - Public API

    /// Triggers a user-initiated "Check for Updates" action.
    /// Sparkle handles the UI (progress, release notes, install prompt) automatically.
    public func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
