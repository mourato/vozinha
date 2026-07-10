import MeetingAssistantCoreCommon
import SwiftUI

struct SettingsSidebarView: View {
    @Binding var selectedSection: SettingsSection
    @Binding var searchText: String
    let onSelectDestination: (SettingsDestination) -> Void
    @ScaledMetric(relativeTo: .body) private var sidebarIconSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption) private var searchResultIconSize: CGFloat = 18

    var body: some View {
        Group {
            if hasActiveSearch {
                searchResultsList
            } else {
                sectionsList
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
    }

    private var sectionsList: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(SettingsSection.primarySections) { section in
                    sidebarNavigationButton(for: section)
                }
            }

            Spacer(minLength: 0)

            sidebarNavigationButton(for: .system)
                .padding(.bottom, 8)
        }
        .searchable(
            text: $searchText,
            placement: .sidebar,
            prompt: "settings.search.placeholder".localized
        )
    }

    private func sidebarNavigationButton(for section: SettingsSection) -> some View {
        Button {
            onSelectDestination(section.destination)
        } label: {
            sidebarLabel(for: section)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(sidebarButtonBackground(for: section))
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
        .padding(.horizontal, 8)
        .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
    }

    private func sidebarButtonBackground(for section: SettingsSection) -> some ShapeStyle {
        selectedSection == section
            ? AnyShapeStyle(AppDesignSystem.Colors.subtleFill)
            : AnyShapeStyle(Color.clear)
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
        .settingsScrollEdgeEffect()
        .searchable(
            text: $searchText,
            placement: .sidebar,
            prompt: "settings.search.placeholder".localized
        )
    }

    private func sidebarLabel(for section: SettingsSection) -> some View {
        HStack(spacing: 8) {
            Image(systemName: section.icon)
                .symbolRenderingMode(.monochrome)
                .font(AppTypography.sidebarIcon)
                .foregroundStyle(AppDesignSystem.Colors.accent)
                .frame(width: sidebarIconSize, height: sidebarIconSize)

            Text(section.title)
                .font(AppTypography.sidebarLabel)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
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
