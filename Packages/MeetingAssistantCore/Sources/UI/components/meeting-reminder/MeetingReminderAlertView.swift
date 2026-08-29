import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

struct MeetingReminderAlertView: View {
    let event: MeetingCalendarEventSnapshot
    let prefersRecordPrimary: Bool
    let onPrimary: () -> Void
    let onJoin: () -> Void
    let onNotes: () -> Void
    let onDismiss: () -> Void
    let onSnooze: (Int) -> Void
    let onSnoozeUntilEnd: () -> Void

    @State private var now = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            backdrop
            card
        }
        .onReceive(timer) { date in
            now = date
        }
    }

    private var backdrop: some View {
        Group {
            if reduceTransparency {
                AppDesignSystem.Colors.overlayBackground
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .background(AppDesignSystem.Colors.overlayBackground.opacity(0.55))
            }
        }
        .ignoresSafeArea()
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing16) {
            statusPill
            Text(displayTitle)
                .font(AppTypography.settingsSectionTitle)
                .foregroundStyle(AppDesignSystem.Colors.overlayForeground)
                .accessibilityAddTraits(.isHeader)
            Text(timeRangeLabel)
                .font(.subheadline)
                .foregroundStyle(AppDesignSystem.Colors.overlayForegroundMuted)
            if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(AppDesignSystem.Colors.overlayForegroundMuted)
                    .lineLimit(2)
            }
            if !event.attendees.isEmpty {
                Label(
                    "\(event.attendees.count)",
                    systemImage: "person.2.fill",
                )
                .font(.subheadline)
                .foregroundStyle(AppDesignSystem.Colors.overlayForegroundMuted)
                .accessibilityLabel("\(event.attendees.count) attendees")
            }
            primaryButton
            secondaryActions
        }
        .padding(AppDesignSystem.Layout.spacing24)
        .frame(maxWidth: 520)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.largeCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppDesignSystem.Layout.largeCornerRadius, style: .continuous)
                .stroke(AppDesignSystem.Colors.overlayDivider, lineWidth: 1)
        }
        .padding(AppDesignSystem.Layout.spacing24)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else {
            RoundedRectangle(cornerRadius: AppDesignSystem.Layout.largeCornerRadius, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    private var statusPill: some View {
        Text(countdownLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppDesignSystem.Colors.overlayStatusForeground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(AppDesignSystem.Colors.warning.opacity(reduceMotion ? 1 : 0.95)),
            )
            .accessibilityLabel(countdownLabel)
    }

    private var primaryButton: some View {
        Button(action: onPrimary) {
            Text(primaryTitle)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
    }

    private var secondaryActions: some View {
        HStack(spacing: AppDesignSystem.Layout.spacing12) {
            if prefersRecordPrimary, event.joinURL != nil {
                Button("meeting_reminder.overlay.secondary.join".localized, action: onJoin)
            }
            Button("meeting_reminder.overlay.secondary.notes".localized, action: onNotes)
            Menu("meeting_reminder.overlay.secondary.snooze".localized) {
                ForEach(MeetingReminderScheduler.SnoozeInterval.allCases, id: \.rawValue) { interval in
                    Button(snoozeTitle(for: interval)) {
                        onSnooze(interval.rawValue)
                    }
                }
                Button("meeting_reminder.overlay.snooze.until_end".localized, action: onSnoozeUntilEnd)
            }
            Button("meeting_reminder.overlay.secondary.dismiss".localized, action: onDismiss)
                .keyboardShortcut(.cancelAction)
        }
    }

    private var displayTitle: String {
        let trimmed = event.trimmedTitle
        return trimmed.isEmpty ? "Untitled meeting" : trimmed
    }

    private var primaryTitle: String {
        if prefersRecordPrimary {
            return "meeting_reminder.overlay.primary.record".localized
        }
        return "meeting_reminder.overlay.primary.join".localized
    }

    private var timeRangeLabel: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: event.startDate, to: event.endDate)
    }

    private var countdownLabel: String {
        if now >= event.startDate, now < event.endDate {
            return "meeting_reminder.overlay.countdown.in_progress".localized
        }
        if now >= event.startDate.addingTimeInterval(-60), now < event.startDate {
            return "meeting_reminder.overlay.countdown.starting_now".localized
        }
        let remaining = max(0, Int(event.startDate.timeIntervalSince(now)))
        let minutes = remaining / 60
        let seconds = remaining % 60
        return "meeting_reminder.overlay.countdown.starts_in".localized(with: String(format: "%d:%02d", minutes, seconds))
    }

    private func snoozeTitle(for interval: MeetingReminderScheduler.SnoozeInterval) -> String {
        switch interval {
        case .one: "meeting_reminder.overlay.snooze.1".localized
        case .five: "meeting_reminder.overlay.snooze.5".localized
        case .ten: "meeting_reminder.overlay.snooze.10".localized
        case .fifteen: "meeting_reminder.overlay.snooze.15".localized
        }
    }
}
