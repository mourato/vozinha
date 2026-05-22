import MeetingAssistantCoreCommon
import SwiftUI

struct SettingsSidebarView: View {
    @Binding var selectedSection: SettingsSection
    @Binding var searchText: String
    let onSelectSection: (SettingsSection) -> Void

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
        List(selection: sectionSelectionBinding) {
            Section("about.title".localized) {
                ForEach(SettingsSection.primarySections) { section in
                    NavigationLink(value: section) {
                        sidebarLabel(for: section)
                    }
                }
            }

            Section("settings.title".localized) {
                ForEach(SettingsSection.settingsSections) { section in
                    NavigationLink(value: section) {
                        sidebarLabel(for: section)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(
            text: $searchText,
            placement: .sidebar,
            prompt: "settings.search.placeholder".localized
        )
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
                            onSelectSection(result.section)
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(section.sidebarIconBackgroundColor)
                )

            Text(section.title)
                .font(.system(size: AppDesignSystem.Layout.sidebarLabelFontSize, weight: .regular))
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private func resultRow(for result: SettingsSearchResult) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: result.section.icon)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(result.section.sidebarIconBackgroundColor)
                )

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
                onSelectSection(newSection)
            }
        )
    }
}
