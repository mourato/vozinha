import MeetingAssistantCoreCommon
import SwiftUI

struct SettingsSidebarView: View {
    @Binding var selectedSection: SettingsSection
    @Binding var searchText: String
    let onSelectDestination: (SettingsDestination) -> Void

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
            List(selection: sectionSelectionBinding) {
                Section("settings.sidebar.workflows".localized) {
                    ForEach(SettingsSection.primarySections) { section in
                        NavigationLink(value: section) {
                            sidebarLabel(for: section)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .settingsScrollEdgeEffect()

            Spacer(minLength: 0)

            Button {
                onSelectDestination(SettingsSection.system.destination)
            } label: {
                sidebarLabel(for: .system)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(bottomSettingsBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .searchable(
            text: $searchText,
            placement: .sidebar,
            prompt: "settings.search.placeholder".localized
        )
    }

    private var bottomSettingsBackground: some ShapeStyle {
        selectedSection == .system
            ? AnyShapeStyle(AppDesignSystem.Colors.subtleFill2)
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
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)

            Text(section.title)
                .font(.system(size: AppDesignSystem.Layout.sidebarLabelFontSize, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private func resultRow(for result: SettingsSearchResult) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: result.section.icon)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: AppDesignSystem.Layout.sidebarLabelFontSize, weight: .regular))
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

    private var sectionSelectionBinding: Binding<SettingsSection> {
        Binding(
            get: { selectedSection },
            set: { newSection in
                onSelectDestination(newSection.destination)
            }
        )
    }
}
