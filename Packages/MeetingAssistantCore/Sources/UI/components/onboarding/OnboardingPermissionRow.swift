import MeetingAssistantCoreDomain
import SwiftUI

// MARK: - Onboarding Permission Row

/// A row displaying a single permission request with status and action button.
public struct OnboardingPermissionRow: View {
    let item: OnboardingPermissionItem
    let status: PermissionState
    let onGrant: () -> Void
    let onOpenSettings: () -> Void
    @ScaledMetric(relativeTo: .title3) private var iconFontSize: CGFloat = 24
    @ScaledMetric(relativeTo: .title3) private var iconFrameSize: CGFloat = 40

    public init(
        item: OnboardingPermissionItem,
        status: PermissionState,
        onGrant: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.item = item
        self.status = status
        self.onGrant = onGrant
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: item.iconName)
                .font(AppTypography.onboardingPermissionIcon(size: iconFontSize))
                .foregroundColor(status == .granted ? .accentColor : .secondary)
                .frame(width: iconFrameSize, height: iconFrameSize)
                .background(
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                )
                .accessibilityHidden(true)

            // Title and Description
            VStack(alignment: .leading, spacing: 4) {
                Text(item.titleKey.localized)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(item.descriptionKey.localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Status / Action Button
            actionButton
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .notDetermined:
            Button(action: onGrant) {
                Text("onboarding.permissions.grant".localized)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

        case .granted:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .accessibilityHidden(true)
                Text("onboarding.permissions.granted".localized)
                    .font(AppTypography.onboardingStatusLabel)
                    .foregroundColor(.green)
            }

        case .denied:
            Button(action: onOpenSettings) {
                HStack(spacing: 4) {
                    Image(systemName: "gear")
                        .accessibilityHidden(true)
                    Text("onboarding.permissions.open_settings".localized)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help("onboarding.permissions.denied.help".localized)

        case .restricted:
            Text("permission.state.restricted".localized)
                .font(AppTypography.onboardingStatusLabel)
                .foregroundColor(.secondary)
        }
    }

    private var accessibilityLabel: String {
        let statusText = switch status {
        case .notDetermined: "permission.state.not_determined".localized
        case .granted: "permission.state.granted".localized
        case .denied: "permission.state.denied".localized
        case .restricted: "permission.state.restricted".localized
        }
        return "\(item.titleKey.localized): \(statusText)"
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        OnboardingPermissionRow(
            item: OnboardingPermissionItem(
                type: .microphone,
                titleKey: "onboarding.permissions.microphone.title",
                descriptionKey: "onboarding.permissions.microphone.desc",
                iconName: "mic.fill"
            ),
            status: .notDetermined,
            onGrant: {},
            onOpenSettings: {}
        )

        OnboardingPermissionRow(
            item: OnboardingPermissionItem(
                type: .microphone,
                titleKey: "onboarding.permissions.microphone.title",
                descriptionKey: "onboarding.permissions.microphone.desc",
                iconName: "mic.fill"
            ),
            status: .granted,
            onGrant: {},
            onOpenSettings: {}
        )

        OnboardingPermissionRow(
            item: OnboardingPermissionItem(
                type: .microphone,
                titleKey: "onboarding.permissions.microphone.title",
                descriptionKey: "onboarding.permissions.microphone.desc",
                iconName: "mic.fill"
            ),
            status: .denied,
            onGrant: {},
            onOpenSettings: {}
        )
    }
    .padding()
    .frame(width: 500)
}
