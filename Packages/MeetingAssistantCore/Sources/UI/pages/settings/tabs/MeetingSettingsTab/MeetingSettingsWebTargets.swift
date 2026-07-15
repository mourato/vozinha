import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

extension MeetingSettingsTab {
    var webTargetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundStyle(AppDesignSystem.Colors.accent)
                Text("settings.meetings.web_targets.title".localized)
                    .font(.headline)
                Spacer()
                DSInfoPopoverButton(
                    title: "settings.meetings.web_targets.title".localized,
                    message: "settings.meetings.web_targets.desc".localized,
                )
            }

            SettingsInlineList(
                items: webTargetsViewModel.targets,
                emptyText: "settings.meetings.web_targets.empty".localized,
                containerStyle: .plain,
            ) { target in
                webTargetRow(target)
            }

            HStack {
                Spacer()
                Button {
                    webTargetsViewModel.addTarget()
                } label: {
                    Label("settings.meetings.web_targets.add".localized, systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }

    func webTargetRow(_ target: WebMeetingTarget) -> some View {
        let isSelected = selectedWebTargetID == target.id

        return HStack(spacing: 12) {
            SettingsRowClickSurface(
                onSingleClick: {
                    selectedWebTargetID = target.id
                },
                onDoubleClick: {
                    selectedWebTargetID = target.id
                    webTargetsViewModel.editTarget(target)
                },
            ) {
                HStack(spacing: 12) {
                    Image(systemName: target.app.icon)
                        .font(.title3)
                        .foregroundStyle(target.app.color)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(target.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(AppDesignSystem.Colors.primaryTextStyle(isSelected: isSelected))
                        Text(target.urlPatterns.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(AppDesignSystem.Colors.secondaryTextStyle(isSelected: isSelected))
                        Text(browserNames(from: target.browserBundleIdentifiers))
                            .font(.caption2)
                            .foregroundStyle(AppDesignSystem.Colors.secondaryTextStyle(isSelected: isSelected))
                    }

                    Spacer()
                }
            }

            SettingsContextMenuButton(
                accessibilityLabel: "settings.rules_per_app.actions".localized,
                symbolColor: isSelected
                    ? AppDesignSystem.Colors.selectedContentSecondaryForeground
                    : .secondary,
            ) {
                Button {
                    selectedWebTargetID = target.id
                    webTargetsViewModel.editTarget(target)
                } label: {
                    Label("settings.meetings.web_targets.edit".localized, systemImage: "pencil")
                }

                Button(role: .destructive) {
                    selectedWebTargetID = target.id
                    webTargetsViewModel.confirmDelete(target)
                } label: {
                    Label("settings.meetings.web_targets.delete".localized, systemImage: "trash")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selectionBackground(isSelected: isSelected))
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
        .contextMenu {
            Button {
                selectedWebTargetID = target.id
                webTargetsViewModel.editTarget(target)
            } label: {
                Label("settings.meetings.web_targets.edit".localized, systemImage: "pencil")
            }

            Button(role: .destructive) {
                selectedWebTargetID = target.id
                webTargetsViewModel.confirmDelete(target)
            } label: {
                Label("settings.meetings.web_targets.delete".localized, systemImage: "trash")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(webTargetAccessibilityLabel(for: target))
        .accessibilityHint("settings.rules_per_app.actions".localized)
    }

    func browserNames(from bundleIdentifiers: [String]) -> String {
        WebTargetBrowserNamesFormatter.formattedNames(
            bundleIdentifiers: bundleIdentifiers,
            fallbackBundleIdentifiers: meetingViewModel.settings.effectiveWebTargetBrowserBundleIdentifiers,
            localizedListKey: "settings.meetings.web_targets.browsers",
        )
    }

    @ViewBuilder
    func selectionBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                .fill(AppDesignSystem.Colors.selectionFill)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                        .stroke(AppDesignSystem.Colors.selectionStroke, lineWidth: 1),
                )
        } else {
            Color.clear
        }
    }

    func deleteSelectedWebTarget() {
        guard let selectedWebTargetID,
              let target = webTargetsViewModel.targets.first(where: { $0.id == selectedWebTargetID })
        else {
            return
        }
        webTargetsViewModel.confirmDelete(target)
    }

    func webTargetAccessibilityLabel(for target: WebMeetingTarget) -> String {
        [target.displayName, target.urlPatterns.joined(separator: ", "), browserNames(from: target.browserBundleIdentifiers)]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}
