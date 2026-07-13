import Foundation
import MeetingAssistantCoreCommon

public enum ShortcutExecutionAction: Equatable, Sendable {
    case start
    case stop
}

@MainActor
public final class ShortcutExecutionEngine {
    public private(set) var isPressed = false

    private var pressStartTime: Date?
    private var startedRecording = false

    private var lastTapTime: Date?
    private var lastTapWasRecording = false

    private let holdThreshold: TimeInterval
    private var doubleTapInterval: TimeInterval

    public init(
        holdThreshold: TimeInterval = 0.35,
        doubleTapInterval: TimeInterval = 0.25,
    ) {
        self.holdThreshold = holdThreshold
        self.doubleTapInterval = doubleTapInterval
    }

    public func updateDoubleTapInterval(_ interval: TimeInterval) {
        guard interval > 0 else {
            return
        }
        doubleTapInterval = interval
    }

    public func reset() {
        isPressed = false
        pressStartTime = nil
        startedRecording = false
        lastTapTime = nil
        lastTapWasRecording = false
    }

    public func handleTransition(
        isActive: Bool,
        trigger: ShortcutTrigger,
        isRecording: Bool,
    ) -> [ShortcutExecutionAction] {
        if isActive {
            guard !isPressed else {
                emitShortcutRejected(trigger: trigger, reason: "transition_ignored_already_pressed")
                return []
            }
            isPressed = true
            return handleDown(trigger: trigger, isRecording: isRecording)
        }

        guard isPressed else {
            emitShortcutRejected(trigger: trigger, reason: "transition_ignored_not_pressed")
            return []
        }
        isPressed = false
        return handleUp(trigger: trigger, isRecording: isRecording)
    }

    public func handleDown(
        trigger: ShortcutTrigger,
        isRecording: Bool,
    ) -> [ShortcutExecutionAction] {
        switch trigger {
        case .singleTap:
            return toggleAction(isRecording: isRecording)
        case .hold:
            pressStartTime = Date()
            if !isRecording {
                startedRecording = true
                return [.start]
            }
            startedRecording = false
            emitShortcutRejected(trigger: trigger, reason: "hold_ignored_already_recording")
            return []
        case .doubleTap:
            emitShortcutRejected(trigger: trigger, reason: "double_tap_wait_release")
            return []
        }
    }

    public func handleUp(
        trigger: ShortcutTrigger,
        isRecording: Bool,
    ) -> [ShortcutExecutionAction] {
        switch trigger {
        case .singleTap:
            return []
        case .hold:
            defer { resetHoldState() }
            guard startedRecording else {
                return []
            }
            return [.stop]
        case .doubleTap:
            let now = Date()
            if let lastTapTime,
               now.timeIntervalSince(lastTapTime) <= doubleTapInterval,
               lastTapWasRecording == isRecording
            {
                self.lastTapTime = nil
                lastTapWasRecording = false
                return toggleAction(isRecording: isRecording)
            }

            lastTapTime = now
            lastTapWasRecording = isRecording
            emitShortcutRejected(trigger: trigger, reason: "double_tap_wait_second_tap")
            return []
        }
    }

    public func holdWasLongEnough(referenceDate: Date = Date()) -> Bool {
        guard let pressStartTime else {
            return false
        }
        return referenceDate.timeIntervalSince(pressStartTime) >= holdThreshold
    }

    private func toggleAction(isRecording: Bool) -> [ShortcutExecutionAction] {
        isRecording ? [.stop] : [.start]
    }

    private func resetHoldState() {
        pressStartTime = nil
        startedRecording = false
    }

    private func emitShortcutRejected(trigger: ShortcutTrigger, reason: String) {
        ShortcutTelemetry.emit(
            .shortcutRejected(
                pipeline: "shortcut_execution_engine",
                scope: "engine",
                shortcutTarget: "recording_toggle",
                source: "execution_engine",
                trigger: trigger.rawValue,
                reason: reason,
            ),
            category: .health,
        )
    }
}
