import Combine
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Main Tab

/// Main tab for managing transcriptions in Settings.
public struct TranscriptionsSettingsTab: View {
    @StateObject private var viewModel = TranscriptionSettingsViewModel()
    @StateObject private var dictationService = MeetingQuestionDictationService()
    @State private var searchReloadTask: Task<Void, Never>?
    @Binding private var searchText: String
    @Binding private var navigationHistory: TranscriptionsNavigationHistory
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var currentRoute: TranscriptionsPageRoute {
        navigationHistory.currentRoute
    }

    public init(
        searchText: Binding<String> = .constant(""),
        navigationHistory: Binding<TranscriptionsNavigationHistory> = .constant(TranscriptionsNavigationHistory())
    ) {
        _searchText = searchText
        _navigationHistory = navigationHistory
    }

    public var body: some View {
        VStack(spacing: 0) {
            contentSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            synchronizeSearchTextFromChrome()
            await viewModel.loadTranscriptions()
            syncSelectionForCurrentRoute()
        }
        .onReceive(NotificationCenter.default.publisher(for: .meetingAssistantTranscriptionSaved)) { _ in
            Task {
                await viewModel.loadTranscriptions()
            }
        }
        .onChange(of: viewModel.sourceFilter) { _, _ in
            Task {
                await viewModel.loadTranscriptions()
            }
        }
        .onChange(of: viewModel.dateFilter) { _, _ in
            Task {
                await viewModel.loadTranscriptions()
            }
        }
        .onChange(of: viewModel.appFilterId) { _, _ in
            Task {
                await viewModel.loadTranscriptions()
            }
        }
        .onChange(of: viewModel.searchText) { _, _ in
            synchronizeChromeSearchText()
            searchReloadTask?.cancel()
            searchReloadTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await viewModel.loadTranscriptions()
            }
        }
        .onChange(of: searchText) { _, _ in
            synchronizeSearchTextFromChrome()
        }
        .onDisappear {
            searchReloadTask?.cancel()
            searchReloadTask = nil
            Task {
                await dictationService.cancel()
            }
        }
        .onChange(of: viewModel.transcriptions) { _, transcriptions in
            sanitizeNavigationHistory(using: transcriptions)
        }
        .confirmationDialog(
            "settings.transcriptions.delete_title".localized,
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("common.delete".localized, role: .destructive) {
                Task {
                    await viewModel.executeDeleteTranscription()
                }
            }
            Button("common.cancel".localized, role: .cancel) {
                viewModel.cancelDeleteTranscription()
            }
        } message: {
            Text("settings.transcriptions.delete_message".localized(with: viewModel.pendingDeleteTranscription?.appName ?? ""))
        }
        .alert("common.error".localized, isPresented: Binding(
            get: { viewModel.operationErrorMessage != nil },
            set: {
                if !$0 {
                    viewModel.operationErrorMessage = nil
                }
            }
        )) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            if let errorMessage = viewModel.operationErrorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        switch currentRoute {
        case .list:
            listPage
        case let .conversation(transcriptionID):
            conversationPage(transcriptionID: transcriptionID)
        }
    }

    // MARK: - List Page

    private var listPage: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSectionHeader(
                    title: "settings.section.history".localized,
                    description: "settings.transcriptions.items_found".localized(with: viewModel.filteredTranscriptions.count)
                )

                HStack(spacing: 16) {
                    sourceFilterPicker
                        .frame(maxWidth: .infinity)

                    appFilterMenu
                        .frame(width: 170)

                    dateFilterMenu
                        .frame(width: AppDesignSystem.Layout.narrowPickerWidth)
                }

                if let errorMessage = viewModel.loadErrorMessage {
                    SettingsStateBlock(
                        kind: .warning,
                        title: "settings.transcriptions.error_load".localized,
                        message: errorMessage,
                        actionTitle: "settings.service.verify".localized
                    ) {
                        Task {
                            await viewModel.loadTranscriptions()
                        }
                    }
                }
            }
            .padding(24)

            Divider()

            if viewModel.isLoading {
                SettingsStateBlock(
                    kind: .loading,
                    title: "settings.transcriptions.loading".localized
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(24)
            } else if viewModel.filteredTranscriptions.isEmpty {
                emptyState
            } else {
                transcriptionsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            SettingsWindowBackground()
        }
    }

    private var sourceFilterPicker: some View {
        Picker(
            "",
            selection: $viewModel.sourceFilter
        ) {
            ForEach(RecordingSourceFilter.allCases, id: \.self) { filter in
                Text(filter.displayName).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.regular)
        .labelsHidden()
    }

    private var appFilterMenu: some View {
        Menu {
            ForEach(viewModel.appFilterOptions) { option in
                Button {
                    viewModel.appFilterId = option.id
                } label: {
                    HStack {
                        Text(option.displayName)
                        if viewModel.appFilterId == option.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundStyle(AppDesignSystem.Colors.accent)
                Text(selectedAppFilterLabel)
                    .font(.body)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .controlSize(.regular)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppDesignSystem.Colors.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
        }
        .menuStyle(.borderlessButton)
    }

    private var dateFilterMenu: some View {
        Menu {
            ForEach(DateFilter.allCases, id: \.self) { filter in
                Button {
                    viewModel.dateFilter = filter
                } label: {
                    HStack {
                        Text(filter.displayName)
                        if viewModel.dateFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(AppDesignSystem.Colors.accent)
                Text(viewModel.dateFilter.displayName)
                    .font(.body)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppDesignSystem.Colors.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
        }
        .menuStyle(.borderlessButton)
    }

    private var selectedAppFilterLabel: String {
        viewModel.appFilterOptions.first(where: { $0.id == viewModel.appFilterId })?.displayName
            ?? "settings.transcriptions.filter_app_all".localized
    }

    private var emptyState: some View {
        ScrollView {
            MAEmptyStateView(
                iconName: "clock.arrow.circlepath",
                title: "settings.transcriptions.empty_title".localized,
                message: "settings.transcriptions.empty_desc".localized
            )
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.top, 48)
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var transcriptionsList: some View {
        List {
            ForEach(viewModel.sortedGroupDates, id: \.self) { date in
                Section(
                    header: Text(formatHeaderDate(date))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                ) {
                    ForEach(viewModel.groupedTranscriptions[date] ?? []) { transcription in
                        HStack(alignment: .top, spacing: 16) {
                            Text(formatTime(transcription.createdAt))
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.top, 12)
                                .frame(width: 50, alignment: .trailing)

                            TranscriptionCardView(
                                transcription: transcription,
                                transcriptionDetail: viewModel.selectedId == transcription.id ? viewModel.selectedTranscription : nil,
                                isExpanded: viewModel.selectedId == transcription.id,
                                audioURL: transcription.audioFilePath != nil ? URL(fileURLWithPath: transcription.audioFilePath!) : nil,
                                availablePrompts: viewModel.availablePrompts(for: transcription),
                                isPostProcessing: viewModel.isPostProcessing(transcriptionID: transcription.id),
                                postProcessingErrorMessage: viewModel.postProcessingError(for: transcription.id),
                                onToggleExpand: {
                                    let toggleSelection = {
                                        if viewModel.selectedId == transcription.id {
                                            viewModel.selectedId = nil
                                        } else {
                                            viewModel.selectedId = transcription.id
                                        }
                                    }

                                    if reduceMotion {
                                        toggleSelection()
                                    } else {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            toggleSelection()
                                        }
                                    }
                                },
                                onAction: { action in
                                    handleTranscriptionAction(action, for: transcription)
                                }
                            )
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                    }
                }
            }
        }
        .listStyle(.plain)
        .subtleScrollbars()
    }

    // MARK: - Conversation Page

    private func conversationPage(transcriptionID: UUID) -> some View {
        let activeTranscription = viewModel.selectedTranscription?.id == transcriptionID ? viewModel.selectedTranscription : nil

        return TranscriptionConversationPage(
            transcriptionID: transcriptionID,
            activeTranscription: activeTranscription,
            viewModel: viewModel,
            dictationService: dictationService,
            onToggleDictation: handleDictationToggle
        )
    }

    // MARK: - Navigation

    private func openConversation(for metadata: TranscriptionMetadata) {
        guard viewModel.canOpenMeetingConversation(for: metadata) else { return }
        navigationHistory.push(.conversation(metadata.id))
        viewModel.selectedId = metadata.id
        dictationService.clearError()
    }

    private func navigateBack() {
        guard navigationHistory.goBack() != nil else { return }
        syncSelectionForCurrentRoute()
    }

    private func navigateForward() {
        guard navigationHistory.goForward() != nil else { return }
        syncSelectionForCurrentRoute()
    }

    private func syncSelectionForCurrentRoute() {
        switch currentRoute {
        case .list:
            Task {
                await dictationService.cancel()
            }
        case let .conversation(transcriptionID):
            if viewModel.selectedId != transcriptionID {
                viewModel.selectedId = transcriptionID
            }
        }
    }

    private func sanitizeNavigationHistory(using transcriptions: [TranscriptionMetadata]) {
        let validIDs = Set(transcriptions.map(\.id))
        var sanitizedHistory = navigationHistory
        sanitizedHistory.sanitize(validConversationIDs: validIDs)

        guard sanitizedHistory != navigationHistory else {
            syncSelectionForCurrentRoute()
            return
        }

        DispatchQueue.main.async {
            navigationHistory = sanitizedHistory
            syncSelectionForCurrentRoute()
        }
    }

    private func synchronizeSearchTextFromChrome() {
        guard viewModel.searchText != searchText else { return }
        let updatedSearchText = searchText
        DispatchQueue.main.async {
            guard viewModel.searchText != updatedSearchText else { return }
            viewModel.searchText = updatedSearchText
        }
    }

    private func synchronizeChromeSearchText() {
        guard searchText != viewModel.searchText else { return }
        let updatedSearchText = viewModel.searchText
        DispatchQueue.main.async {
            guard searchText != updatedSearchText else { return }
            searchText = updatedSearchText
        }
    }

    // MARK: - Actions

    private func handleTranscriptionAction(_ action: TranscriptionCardView.TranscriptionAction, for metadata: TranscriptionMetadata) {
        switch action {
        case .askAboutMeeting:
            openConversation(for: metadata)
        case let .copy(text):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        case let .updateMeetingTitle(title):
            Task {
                await viewModel.updateMeetingTitle(for: metadata, to: title)
            }
        case let .updateCapturePurpose(capturePurpose):
            Task {
                await viewModel.updateCapturePurpose(for: metadata, to: capturePurpose)
            }
        case let .reprocess(prompt):
            if let transcription = viewModel.selectedTranscription, transcription.id == metadata.id {
                Task {
                    await viewModel.applyPostProcessing(prompt: prompt, to: transcription)
                }
            }
        case .info:
            break
        case .viewPrompt:
            break
        case .retryTranscription:
            Task {
                await viewModel.retryTranscription(for: metadata)
            }
        case .delete:
            viewModel.confirmDeleteTranscription(metadata)
        case let .export(kind):
            Task {
                let exportKind: TranscriptionSettingsViewModel.ManualTranscriptionExportKind = switch kind {
                case .summary:
                    .summary
                case .original:
                    .original
                }
                await viewModel.exportTranscription(for: metadata, kind: exportKind)
            }
        }
    }

    private func handleDictationToggle() {
        guard viewModel.selectedTranscription?.supportsMeetingConversation == true else {
            return
        }

        Task {
            if let transcribedText = await dictationService.toggleDictation() {
                appendDictationText(transcribedText)
            }
        }
    }

    private func appendDictationText(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        let current = viewModel.qaQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty {
            viewModel.qaQuestion = normalized
            return
        }

        viewModel.qaQuestion = "\(current) \(normalized)"
    }

    // MARK: - Formatting

    private func formatHeaderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current

        if Calendar.current.isDateInToday(date) {
            return "settings.transcriptions.today".localized
        } else if Calendar.current.isDateInYesterday(date) {
            return "settings.transcriptions.yesterday".localized
        }

        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}

// MARK: - Transcription Row View

struct TranscriptionRowView: View {
    let metadata: TranscriptionMetadata

    private var appColor: Color {
        MeetingApp(rawValue: metadata.appRawValue)?.color ?? .gray
    }

    private var appIcon: String {
        MeetingApp(rawValue: metadata.appRawValue)?.icon ?? "questionmark.circle"
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: metadata.createdAt)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: metadata.createdAt)
    }

    private var previewText: String {
        let trimmed = metadata.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "transcription.empty_fallback".localized
        }
        return metadata.previewText
    }

    private var isFallbackText: Bool {
        metadata.previewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(appColor.opacity(0.1))
                    .frame(width: 40, height: 40)

                AppIconView(
                    bundleIdentifier: metadata.appBundleIdentifier,
                    fallbackSystemName: appIcon,
                    size: 22,
                    cornerRadius: 5
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.body)
                    .fontWeight(.semibold)

                Text(previewText)
                    .font(isFallbackText ? .caption.italic() : .caption)
                    .foregroundStyle(isFallbackText ? .tertiary : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if metadata.isPostProcessed {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(AppDesignSystem.Colors.iconHighlight)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    TranscriptionsSettingsTab()
        .frame(width: 900, height: 620)
}
