import MeetingAssistantCoreCommon
import SwiftUI

// preview-check: ignore — sidebar preview requires the SettingsPage navigation environment.

struct SettingsSidebarView: View {
    @Binding var selectedSection: SettingsSection
    @Binding var searchText: String
    let showsSystemSettingsBadge: Bool
    let onSelectDestination: (SettingsDestination) -> Void
    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

            if hasActiveSearch {
                searchResultsList
            } else {
                sectionsList
            }
        }
        .padding(.top, 8)
    }

    private var searchField: some View {
        SettingsSearchField(
            text: $searchText,
            placeholder: "settings.search.placeholder".localized,
            style: .sidebar,
        )
        .accessibilityLabel("settings.search.placeholder".localized)
    }

    private var sectionsList: some View {
        List(selection: $selectedSection) {
            Section {
                ForEach(SettingsSection.primarySections) { section in
                    sidebarRow(for: section)
                        .tag(section)
                }
            }

            Section {
                sidebarRow(for: SettingsSection.system)
                    .tag(SettingsSection.system)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private func sidebarRow(for section: SettingsSection) -> some View {
        sidebarLabel(for: section)
            .contentShape(Rectangle())
            .accessibilityLabel(sidebarAccessibilityLabel(for: section))
    }

    private func sidebarAccessibilityLabel(for section: SettingsSection) -> String {
        guard section == .system, showsSystemSettingsBadge else {
            return section.title
        }
        return "\(section.title), \("settings.system.update_available".localized)"
    }

    private var hasActiveSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchResults: [SettingsSearchResult] {
        SettingsSearchIndex.results(for: searchText)
    }

    private var searchResultsList: some View {
        List {
            if searchResults.isEmpty {
                Section {
                    Text("settings.search.empty".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("settings.search.clear".localized) {
                        searchText = ""
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppDesignSystem.Colors.accent)
                }
            } else {
                Section("settings.search.results".localized(with: searchResults.count)) {
                    ForEach(searchResults) { result in
                        Button {
                            onSelectDestination(result.destination)
                            searchText = ""
                        } label: {
                            resultRow(for: result)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .settingsScrollEdgeEffect()
    }

    private func sidebarLabel(for section: SettingsSection) -> some View {
        HStack(spacing: 8) {
            Image(systemName: sidebarIcon(for: section))
                .font(AppTypography.sidebarIcon)
                .foregroundStyle(.primary)
                .frame(width: 18, alignment: .center)
                .opacity(controlActiveState == .inactive ? 0.55 : 1.0)

            Text(section.title)
                .font(AppTypography.sidebarLabel)
                .lineLimit(1)

            if section == .system, showsSystemSettingsBadge {
                Spacer(minLength: 0)
                Circle()
                    .fill(AppDesignSystem.Colors.accent)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 28)
    }

    private func sidebarIcon(for section: SettingsSection) -> String {
        selectedSection == section ? section.selectedSidebarIcon : section.icon
    }

    private func resultRow(for result: SettingsSearchResult) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: result.section.icon)
                .font(AppTypography.sidebarSearchResultIcon)
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .center)
                .opacity(controlActiveState == .inactive ? 0.55 : 1.0)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(AppTypography.sidebarSearchResultLabel)
                    .lineLimit(2)

                Text(result.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if selectedSection == result.section {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
