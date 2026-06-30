import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

public struct PostProcessingContextCaptureResult: Sendable {
    public let context: String?
    public let items: [TranscriptionContextItem]
    public let didTimeout: Bool

    public init(context: String?, items: [TranscriptionContextItem], didTimeout: Bool) {
        self.context = context
        self.items = items
        self.didTimeout = didTimeout
    }
}

@MainActor
public final class AssistantContextCaptureService {
    private let contextAwarenessService: any ContextAwarenessServiceProtocol
    private let textContextProvider: any TextContextProvider
    private let textContextGuardrails: TextContextGuardrails
    private let textContextPolicy: TextContextPolicy
    private let isAccessibilityTrusted: () -> Bool
    private let requestAccessibilityPermission: () -> Void

    public init(
        contextAwarenessService: any ContextAwarenessServiceProtocol,
        textContextProvider: any TextContextProvider,
        textContextGuardrails: TextContextGuardrails,
        textContextPolicy: TextContextPolicy,
        isAccessibilityTrusted: @escaping () -> Bool = { AccessibilityPermissionService.isTrusted() },
        requestAccessibilityPermission: @escaping () -> Void = { AccessibilityPermissionService.requestPermission() }
    ) {
        self.contextAwarenessService = contextAwarenessService
        self.textContextProvider = textContextProvider
        self.textContextGuardrails = textContextGuardrails
        self.textContextPolicy = textContextPolicy
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.requestAccessibilityPermission = requestAccessibilityPermission
    }

    public func capturePostProcessingContext(
        for meeting: Meeting,
        settings: AppSettingsStore,
        activeTabURL: String?,
        calendarContext: String?,
        isDictationMode: Bool,
        includeWindowOCR: Bool? = nil
    ) async -> (context: String?, items: [TranscriptionContextItem]) {
        let shouldIncludeWindowOCR = includeWindowOCR ?? settings.contextAwarenessIncludeWindowOCR

        guard settings.contextAwarenessEnabled else {
            AppLogger.debug(
                "Context awareness disabled, skipping context capture",
                category: .recordingManager,
                extra: ["reasonCode": "context.disabled"]
            )

            guard let activeTabURL else {
                return (nil, [])
            }

            return (
                nil,
                [TranscriptionContextItem(source: .activeTabURL, text: activeTabURL)]
            )
        }

        let snapshot = await contextAwarenessService.captureSnapshot(
            options: .init(
                includeActiveApp: true,
                includeClipboard: settings.contextAwarenessIncludeClipboard,
                includeWindowOCR: shouldIncludeWindowOCR,
                includeAccessibilityText: settings.contextAwarenessIncludeAccessibilityText,
                protectSensitiveApps: true,
                redactSensitiveData: settings.contextAwarenessRedactSensitiveData,
                excludedBundleIDs: settings.contextAwarenessExcludedBundleIDs
            )
        )

        var context = contextAwarenessService.makePostProcessingContext(from: snapshot)
        var items = makeContextItems(from: snapshot)

        if let activeTabURL {
            appendActiveTabURLContext(activeTabURL, to: &context, items: &items)
        }

        if let calendarContext {
            appendCalendarContext(calendarContext, to: &context, items: &items)
        }

        await appendFocusedTextContextIfNeeded(
            snapshot: snapshot,
            isDictationMode: isDictationMode,
            settings: settings,
            context: &context,
            items: &items
        )

        logContextCaptureSummary(snapshot: snapshot, items: items, settings: settings)
        return (context, items)
    }

    public func capturePostProcessingContextWithTimeout(
        for meeting: Meeting,
        settings: AppSettingsStore,
        activeTabURL: String?,
        calendarContext: String?,
        isDictationMode: Bool,
        includeWindowOCR: Bool? = nil,
        timeoutNanoseconds: UInt64
    ) async -> PostProcessingContextCaptureResult {
        await withTaskGroup(
            of: PostProcessingContextCaptureResult.self,
            returning: PostProcessingContextCaptureResult.self
        ) { group in
            group.addTask {
                let capture = await self.capturePostProcessingContext(
                    for: meeting,
                    settings: settings,
                    activeTabURL: activeTabURL,
                    calendarContext: calendarContext,
                    isDictationMode: isDictationMode,
                    includeWindowOCR: includeWindowOCR
                )
                return PostProcessingContextCaptureResult(
                    context: capture.context,
                    items: capture.items,
                    didTimeout: false
                )
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return PostProcessingContextCaptureResult(context: nil, items: [], didTimeout: true)
            }

            let firstResult = await group.next() ?? PostProcessingContextCaptureResult(
                context: nil,
                items: [],
                didTimeout: true
            )
            group.cancelAll()
            return firstResult
        }
    }

    public func makeContextItems(from snapshot: ContextAwarenessSnapshot) -> [TranscriptionContextItem] {
        var items: [TranscriptionContextItem] = []

        if let activeAppName = snapshot.activeAppName {
            items.append(TranscriptionContextItem(source: .activeApp, text: activeAppName))
        }

        if let activeWindowTitle = snapshot.activeWindowTitle {
            items.append(TranscriptionContextItem(source: .windowTitle, text: activeWindowTitle))
        }

        if let accessibilityText = snapshot.activeAccessibilityText {
            items.append(TranscriptionContextItem(source: .accessibilityText, text: accessibilityText))
        }

        if let clipboardText = snapshot.clipboardText {
            items.append(TranscriptionContextItem(source: .clipboard, text: clipboardText))
        }

        if let ocrText = snapshot.activeWindowOCRText {
            items.append(TranscriptionContextItem(source: .windowOCR, text: ocrText))
        }

        return items
    }

    private func captureFocusedTextContext(settings: AppSettingsStore) async -> String? {
        guard settings.contextAwarenessIncludeAccessibilityText else { return nil }

        guard isAccessibilityTrusted() else {
            AppLogger.warning(
                "Focused text capture skipped: accessibility permission not granted",
                category: .recordingManager,
                extra: ["reasonCode": "focused_text.permission_denied"]
            )
            requestAccessibilityPermission()
            return nil
        }

        do {
            let snapshot = try await textContextProvider.fetchTextContext()
            let guarded = textContextGuardrails.apply(to: snapshot.text, policy: textContextPolicy)
            var normalized = guarded.trimmingCharacters(in: .whitespacesAndNewlines)

            if settings.contextAwarenessRedactSensitiveData {
                normalized = ContextAwarenessPrivacy.redactSensitiveText(normalized) ?? ""
            }

            return normalized.isEmpty ? nil : normalized
        } catch {
            AppLogger.warning(
                "Focused text capture failed",
                category: .recordingManager,
                extra: [
                    "reasonCode": "focused_text.provider_failed",
                    "error": error.localizedDescription,
                ]
            )
            return nil
        }
    }

    private func appendFocusedTextContextIfNeeded(
        snapshot: ContextAwarenessSnapshot,
        isDictationMode: Bool,
        settings: AppSettingsStore,
        context: inout String?,
        items: inout [TranscriptionContextItem]
    ) async {
        guard isDictationMode else { return }
        guard settings.contextAwarenessIncludeAccessibilityText else { return }
        guard snapshot.activeAccessibilityText == nil else { return }
        guard let focusedText = await captureFocusedTextContext(settings: settings) else { return }
        guard !items.contains(where: { $0.source == .focusedText && $0.text == focusedText }) else { return }

        items.append(TranscriptionContextItem(source: .focusedText, text: focusedText))
        appendContextBlock(
            """
            - Focused text:
            \(focusedText)
            """,
            to: &context
        )
    }

    private func appendActiveTabURLContext(
        _ activeTabURL: String,
        to context: inout String?,
        items: inout [TranscriptionContextItem]
    ) {
        items.append(TranscriptionContextItem(source: .activeTabURL, text: activeTabURL))
        appendContextBlock("- Active tab URL: \(activeTabURL)", to: &context)
    }

    private func appendCalendarContext(
        _ calendarContext: String,
        to context: inout String?,
        items: inout [TranscriptionContextItem]
    ) {
        items.append(TranscriptionContextItem(source: .calendarEvent, text: calendarContext))

        if let existingContext = context,
           !existingContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            context = "\(existingContext)\n\(calendarContext)"
        } else {
            context = calendarContext
        }
    }

    private func appendContextBlock(_ block: String, to context: inout String?) {
        if let existingContext = context,
           !existingContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            context = "\(existingContext)\n\(block)"
        } else {
            context = """
            CONTEXT_METADATA
            \(block)
            """
        }
    }

    private func logContextCaptureSummary(
        snapshot: ContextAwarenessSnapshot,
        items: [TranscriptionContextItem],
        settings: AppSettingsStore
    ) {
        if settings.contextAwarenessIncludeWindowOCR, snapshot.activeWindowOCRText == nil {
            AppLogger.debug(
                "Context capture finished without OCR text",
                category: .recordingManager,
                extra: ["reasonCode": "context.ocr_missing"]
            )
        }

        if items.isEmpty {
            AppLogger.info(
                "Context capture finished with no context items",
                category: .recordingManager,
                extra: ["reasonCode": "context.empty"]
            )
            return
        }

        AppLogger.debug(
            "Context capture finished",
            category: .recordingManager,
            extra: [
                "reasonCode": "context.captured",
                "itemCount": items.count,
                "sources": items.map(\.source.rawValue).joined(separator: ","),
            ]
        )
    }
}
