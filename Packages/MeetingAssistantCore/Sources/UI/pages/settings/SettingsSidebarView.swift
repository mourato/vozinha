import MeetingAssistantCoreCommon
import SwiftUI

// preview-check: ignore — sidebar preview requires the SettingsPage navigation environment.

struct SettingsSidebarView: View {
    @Binding var selectedSection: SettingsSection
    @Binding var searchText: String
    let showsSystemSettingsBadge: Bool
    let onSelectDestination: (SettingsDestination) -> Void
    @ScaledMetric(relativeTo: .body) private var sidebarIconSize: CGFloat = 24
    @ScaledMetric(relativeTo: .caption) private var searchResultIconSize: CGFloat = 18
    @State private var hoveredSectionID: String?
    @FocusState private var focusedSectionID: String?

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

            Group {
                if hasActiveSearch {
                    searchResultsList
                } else {
                    sectionsList
                }
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 0)
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
        VStack(spacing: 0) {
            VStack(spacing: 3) {
                ForEach(SettingsSection.primarySections) { section in
                    sidebarNavigationButton(for: section)
                }
            }

            Spacer(minLength: 16)

            sidebarNavigationButton(for: .system)
                .padding(.bottom, 14)
        }
    }

    private func sidebarNavigationButton(for section: SettingsSection) -> some View {
        Button {
            onSelectDestination(section.destination)
        } label: {
            sidebarLabel(for: section)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .padding(.trailing, 10)
                .frame(height: 38)
                .contentShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
        }
        .buttonStyle(.plain)
        .background(sidebarButtonBackground(for: section))
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
        .padding(.horizontal, 10)
        .onHover { hovering in
            hoveredSectionID = hovering ? section.id : nil
        }
        .focused($focusedSectionID, equals: section.id)
        .overlay {
            RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                .stroke(
                    focusedSectionID == section.id ? AppDesignSystem.Colors.accent : .clear,
                    lineWidth: 2,
                )
        }
        .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
        .accessibilityLabel(sidebarAccessibilityLabel(for: section))
    }

    private func sidebarAccessibilityLabel(for section: SettingsSection) -> String {
        guard section == .system, showsSystemSettingsBadge else {
            return section.title
        }
        return "\(section.title), \("settings.system.update_available".localized)"
    }

    private func sidebarButtonBackground(for section: SettingsSection) -> some ShapeStyle {
        if selectedSection == section {
            return AnyShapeStyle(AppDesignSystem.Colors.subtleFill)
        }
        if hoveredSectionID == section.id {
            return AnyShapeStyle(AppDesignSystem.Colors.subtleFill.opacity(0.65))
        }
        return AnyShapeStyle(Color.clear)
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
        HStack(spacing: 9) {
            Image(systemName: sidebarIcon(for: section))
                .symbolRenderingMode(.monochrome)
                .font(AppTypography.sidebarIcon)
                .foregroundStyle(AppDesignSystem.Colors.accent)
                .frame(width: sidebarIconSize, height: sidebarIconSize)

            Text(section.title)
                .font(AppTypography.sidebarLabel)
                .lineLimit(1)

            if section == .system, showsSystemSettingsBadge {
                Circle()
                    .fill(AppDesignSystem.Colors.accent)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)
        }
    }

    private func sidebarIcon(for section: SettingsSection) -> String {
        selectedSection == section ? section.selectedSidebarIcon : section.icon
    }

    private func resultRow(for result: SettingsSearchResult) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: result.section.icon)
                .symbolRenderingMode(.monochrome)
                .font(AppTypography.sidebarSearchResultIcon)
                .foregroundStyle(.secondary)
                .frame(width: searchResultIconSize, height: searchResultIconSize)

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
