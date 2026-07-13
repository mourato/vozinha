import AppKit
import Foundation

public protocol WebTargetPattern {
    var urlPatterns: [String] { get }
    var browserBundleIdentifiers: [String] { get }
}

extension WebMeetingTarget: WebTargetPattern {}
extension WebContextTarget: WebTargetPattern {}

public enum WebTargetDetection {
    public static func matchTarget<T: WebTargetPattern>(
        for url: URL,
        bundleIdentifier: String,
        targets: [T],
        fallbackBrowserBundleIdentifiers: [String] = [],
    ) -> T? {
        let urlString = url.absoluteString.lowercased()
        let normalizedBundleId = normalizeBundleIdentifier(bundleIdentifier)
        let normalizedFallbackBrowsers = Set(
            fallbackBrowserBundleIdentifiers
                .map(normalizeBundleIdentifier)
                .filter { !$0.isEmpty },
        )

        return targets.first { target in
            guard targetSupportsBundle(target, normalizedBundleId: normalizedBundleId, normalizedFallbackBrowsers: normalizedFallbackBrowsers) else {
                return false
            }
            return target.urlPatterns.contains { pattern in
                urlString.contains(pattern.lowercased())
            }
        }
    }

    public static func matchTargetByWindowTitle<T: WebTargetPattern>(
        bundleIdentifier: String,
        targets: [T],
        fallbackBrowserBundleIdentifiers: [String] = [],
        patternProvider: (T) -> [String] = { $0.urlPatterns },
    ) -> T? {
        let normalizedBundleId = normalizeBundleIdentifier(bundleIdentifier)
        let normalizedFallbackBrowsers = Set(
            fallbackBrowserBundleIdentifiers
                .map(normalizeBundleIdentifier)
                .filter { !$0.isEmpty },
        )

        for target in targets {
            guard targetSupportsBundle(target, normalizedBundleId: normalizedBundleId, normalizedFallbackBrowsers: normalizedFallbackBrowsers) else {
                continue
            }

            let patterns = patternProvider(target)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if !patterns.isEmpty, checkBrowserWindowTitles(for: patterns) {
                return target
            }
        }

        return nil
    }

    public static func checkBrowserWindowTitles(for patterns: [String]) -> Bool {
        let windowInfoOptions: CGWindowListOption = [.optionOnScreenOnly]
        guard
            let windowList = CGWindowListCopyWindowInfo(
                windowInfoOptions,
                kCGNullWindowID,
            ) as? [[CFString: Any]]
        else {
            return false
        }

        for window in windowList {
            guard let windowName = window[kCGWindowName] as? String else { continue }

            for pattern in patterns where windowName.localizedCaseInsensitiveContains(pattern) {
                return true
            }
        }

        return false
    }

    public static func normalizeBundleIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func targetSupportsBundle(
        _ target: some WebTargetPattern,
        normalizedBundleId: String,
        normalizedFallbackBrowsers: Set<String>,
    ) -> Bool {
        let normalizedTargetBrowsers = target.browserBundleIdentifiers
            .map(normalizeBundleIdentifier)
            .filter { !$0.isEmpty }

        if !normalizedTargetBrowsers.isEmpty {
            return normalizedTargetBrowsers.contains(normalizedBundleId)
        }

        if !normalizedFallbackBrowsers.isEmpty {
            return normalizedFallbackBrowsers.contains(normalizedBundleId)
        }

        return false
    }
}
