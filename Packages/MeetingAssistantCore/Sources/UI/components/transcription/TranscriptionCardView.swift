import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

/// An expandable card for a transcription item.
public struct TranscriptionCardView: View {
    private enum Layout {
        static let contentLineLimit = 8
    }

    let transcription: TranscriptionMetadata
    let transcriptionDetail: Transcription?
    let isExpanded: Bool
    let audioURL: URL?
    let availablePrompts: [PostProcessingPrompt]
    let availableRetryTranscriptionOptions: [RetryTranscriptionOption]
    let isPostProcessing: Bool
    let postProcessingErrorMessage: String?
    let onToggleExpand: () -> Void
    let onAction: (TranscriptionAction) -> Void

    public init(
        transcription: TranscriptionMetadata,
        transcriptionDetail: Transcription? = nil,
        isExpanded: Bool,
        audioURL: URL?,
        availablePrompts: [PostProcessingPrompt] = [],
        availableRetryTranscriptionOptions: [RetryTranscriptionOption] = [],
        isPostProcessing: Bool = false,
        postProcessingErrorMessage: String? = nil,
        onToggleExpand: @escaping () -> Void,
        onAction: @escaping (TranscriptionAction) -> Void,
    ) {
        self.transcription = transcription
        self.transcriptionDetail = transcriptionDetail
        self.isExpanded = isExpanded
        self.audioURL = audioURL
        self.availablePrompts = availablePrompts
        self.availableRetryTranscriptionOptions = availableRetryTranscriptionOptions
        self.isPostProcessing = isPostProcessing
        self.postProcessingErrorMessage = postProcessingErrorMessage
        self.onToggleExpand = onToggleExpand
        self.onAction = onAction
    }

    @State private var selectedTab: TranscriptionTab = .aiProcessed
    @State private var showInfoPopover = false
    @State private var showPromptPopover = false
    @State private var expandedTabs: Set<TranscriptionTab> = []
    @State private var draftMeetingTitle = ""
    @State private var isEditingMeetingTitle = false
    @FocusState private var isMeetingTitleFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public enum TranscriptionAction {
        public enum ExportKind: Sendable {
            case summary
            case original
        }

        case askAboutMeeting
        case copy(text: String)
        case updateMeetingTitle(String?)
        case updateCapturePurpose(CapturePurpose)
        case reprocess(prompt: PostProcessingPrompt)
        case retryTranscription(selection: TranscriptionProviderSelection)
        case info
        case viewPrompt
        case delete
        case export(ExportKind)
    }

    public enum TranscriptionTab: CaseIterable {
        case aiProcessed
        case original
        case segmented
        case notes

        var localized: String {
            switch self {
            case .aiProcessed:
                "transcription.tab.ai_processed".localized
            case .original:
                "transcription.tab.original".localized
            case .segmented:
                "transcription.tab.segmented".localized
            case .notes:
                "transcription.tab.notes".localized
            }
        }
    }

    public var body: some View {
        DSCard(
            cornerRadius: AppDesignSystem.Layout.largeCornerRadius,
            padding: isExpanded ? 16 : 12,
        ) {
            if isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleExpand()
        }
        .onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .onAppear {
            syncDraftMeetingTitleIfNeeded()
        }
        .onChange(of: currentPersistedMeetingTitle) { _, _ in
            syncDraftMeetingTitleIfNeeded()
        }
    }

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if shouldDisplayMeetingTitle {
                Text(collapsedMeetingTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(displayText(transcription.previewText))
                .font(.body)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            sourceLabel(text: sourceDisplayName)
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                TranscriptionAudioPlayerView(audioURL: audioURL)

                Spacer(minLength: 12)

                if shouldShowTabPicker {
                    Picker("", selection: $selectedTab) {
                        ForEach(availableTabs, id: \.self) { tab in
                            Text(tab.localized).tag(tab)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 180)
                }
            }

            if shouldDisplayMeetingTitle {
                if transcription.supportsMeetingConversation {
                    meetingTitleEditor
                } else {
                    Text(collapsedMeetingTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            contentView
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let error = inlinePostProcessingErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppDesignSystem.Colors.error)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppDesignSystem.Colors.error)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                sourceLabel(text: sourceDisplayName)

                Spacer()

                HStack(spacing: 8) {
                    if transcription.supportsMeetingConversation {
                        Button {
                            onAction(.askAboutMeeting)
                        } label: {
                            Label("transcription.qa.title".localized, systemImage: "bubble.left.and.bubble.right")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        showInfoPopover.toggle()
                    } label: {
                        Label("transcription.info.title".localized, systemImage: "info.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .popover(isPresented: $showInfoPopover) {
                        if let details = transcriptionDetail {
                            TranscriptionInfoPopover(transcription: details)
                        } else {
                            Text("transcription.info.loading".localized)
                                .padding()
                        }
                    }

                    if hasPromptText {
                        Button {
                            showPromptPopover.toggle()
                        } label: {
                            Label("transcription.prompt.view".localized, systemImage: "text.quote")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .popover(isPresented: $showPromptPopover) {
                            if let details = transcriptionDetail {
                                TranscriptionPromptPopover(transcription: details)
                            }
                        }
                    }

                    Menu {
                        Button {
                            onAction(.copy(text: currentText))
                        } label: {
                            Label("common.copy".localized, systemImage: "doc.on.doc")
                        }

                        Menu {
                            Button {
                                onAction(.export(.summary))
                            } label: {
                                Label("transcription.actions.export_summary".localized, systemImage: "sparkles")
                            }
                            .disabled(!hasPostProcessingContent)

                            Button {
                                onAction(.export(.original))
                            } label: {
                                Label("transcription.actions.export_original".localized, systemImage: "doc.plaintext")
                            }
                        } label: {
                            Label("transcription.actions.export".localized, systemImage: "square.and.arrow.up")
                        }

                        Menu {
                            ForEach(filteredPrompts) { prompt in
                                Button(prompt.title) {
                                    onAction(.reprocess(prompt: prompt))
                                }
                            }
                        } label: {
                            Label("transcription.actions.redo_post_processing".localized, systemImage: "wand.and.sparkles")
                        }
                        .disabled(filteredPrompts.isEmpty || isPostProcessing)

                        if availableRetryTranscriptionOptions.count > 1 {
                            Menu {
                                ForEach(availableRetryTranscriptionOptions) { option in
                                    Button(option.displayName) {
                                        onAction(.retryTranscription(selection: option.selection))
                                    }
                                }
                            } label: {
                                Label("transcription.actions.retry_transcription".localized, systemImage: "arrow.clockwise.circle")
                            }
                            .disabled(audioURL == nil)
                        } else {
                            Button {
                                if let onlyOption = availableRetryTranscriptionOptions.first {
                                    onAction(.retryTranscription(selection: onlyOption.selection))
                                }
                            } label: {
                                Label("transcription.actions.retry_transcription".localized, systemImage: "arrow.clockwise.circle")
                            }
                            .disabled(audioURL == nil || availableRetryTranscriptionOptions.isEmpty)
                        }

                        Button {
                            onAction(.updateCapturePurpose(toggledCapturePurpose))
                        } label: {
                            Label(toggleCapturePurposeLabel, systemImage: toggleCapturePurposeIcon)
                        }

                        Divider()

                        Button(role: .destructive) {
                            onAction(.delete)
                        } label: {
                            Label {
                                Text("common.delete".localized)
                            } icon: {
                                Image(systemName: "trash")
                            }
                            .foregroundStyle(AppDesignSystem.Colors.error)
                        }
                        .foregroundStyle(AppDesignSystem.Colors.error)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .buttonStyle(.bordered)
                }
            }
        }
        .onAppear {
            ensureValidSelectedTab()
        }
        .onChange(of: isSegmentedTabEnabled) { _, _ in
            ensureValidSelectedTab()
        }
        .onChange(of: hasPostProcessingContent) { _, _ in
            ensureValidSelectedTab()
        }
    }

    private var availableTabs: [TranscriptionTab] {
        var tabs: [TranscriptionTab] = [.aiProcessed, .original]

        if isSegmentedTabEnabled {
            tabs.append(.segmented)
        }
        if isNotesTabEnabled {
            tabs.append(.notes)
        }

        return tabs
    }

    private var shouldShowTabPicker: Bool {
        availableTabs.count > 1
    }

    private var hasPostProcessingContent: Bool {
        if let processedContent = transcriptionDetail?.processedContent {
            return !processedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return transcription.isPostProcessed
    }

    private var hasPromptText: Bool {
        transcription.capturePurpose == .dictation && (
            transcriptionDetail?.postProcessingRequestSystemPrompt != nil
                || transcriptionDetail?.postProcessingRequestUserPrompt != nil
                || transcriptionDetail?.postProcessingPromptId != nil
        )
    }

    private var isSegmentedTabEnabled: Bool {
        transcription.capturePurpose == .meeting
            && AppSettingsStore.shared.isDiarizationEnabled
    }

    private var isNotesTabEnabled: Bool {
        transcription.capturePurpose == .meeting
    }

    private var filteredPrompts: [PostProcessingPrompt] {
        let settings = AppSettingsStore.shared
        let typeSpecificPrompts = transcription.supportsMeetingConversation ? settings.meetingAvailablePrompts : settings.dictationAvailablePrompts
        let allowedIDs = Set(availablePrompts.map(\.id))

        guard !allowedIDs.isEmpty else {
            return typeSpecificPrompts
        }

        return typeSpecificPrompts.filter { allowedIDs.contains($0.id) }
    }

    private func ensureValidSelectedTab() {
        guard !availableTabs.contains(selectedTab) else { return }
        selectedTab = availableTabs.first ?? .original
    }

    private var currentText: String {
        switch selectedTab {
        case .aiProcessed:
            transcriptionDetail?.processedContent ?? transcriptionDetail?.text ?? transcription.previewText
        case .original:
            transcriptionDetail?.rawText ?? transcription.previewText
        case .segmented:
            sortedSegments(transcriptionDetail?.segments ?? [])
                .map { "\($0.speaker): \($0.text)" }
                .joined(separator: "\n\n")
        case .notes:
            transcriptionDetail?.contextItems.first(where: { $0.source == .meetingNotes })?.text ?? ""
        }
    }

    private var contentView: some View {
        let text = displayText(currentText)

        return VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .lineLimit(isTabExpanded(selectedTab) ? nil : Layout.contentLineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(textOpacity)
                .animation(pulseAnimation, value: isPostProcessing)

            if shouldShowContentExpansionToggle(text: text) {
                Button(isTabExpanded(selectedTab) ? "transcription.content.show_less".localized : "transcription.content.show_all".localized) {
                    toggleTabExpansion(selectedTab)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(AppDesignSystem.Colors.accent)
            }
        }
    }

    private func displayText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "transcription.empty_fallback".localized
        }
        return text
    }

    private var textOpacity: Double {
        if isPostProcessing, !reduceMotion {
            return 0.45
        }
        return 1
    }

    private var pulseAnimation: Animation? {
        if isPostProcessing, !reduceMotion {
            return .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
        }
        return nil
    }

    private var inlinePostProcessingErrorMessage: String? {
        guard let postProcessingErrorMessage else { return nil }
        let trimmed = postProcessingErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func sortedSegments(_ segments: [Transcription.Segment]) -> [Transcription.Segment] {
        segments.sorted { lhs, rhs in
            if lhs.startTime != rhs.startTime {
                return lhs.startTime < rhs.startTime
            }
            if lhs.endTime != rhs.endTime {
                return lhs.endTime < rhs.endTime
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func isTabExpanded(_ tab: TranscriptionTab) -> Bool {
        expandedTabs.contains(tab)
    }

    private func toggleTabExpansion(_ tab: TranscriptionTab) {
        if expandedTabs.contains(tab) {
            expandedTabs.remove(tab)
        } else {
            expandedTabs.insert(tab)
        }
    }

    private func shouldShowContentExpansionToggle(text: String) -> Bool {
        let lineBreakCount = text.reduce(into: 0) { partialResult, character in
            if character == "\n" {
                partialResult += 1
            }
        }
        let estimatedLines = lineBreakCount + max(1, text.count / 110)
        return estimatedLines > Layout.contentLineLimit
    }

    private func actionButton(icon: String, action: TranscriptionAction, isDestructive: Bool = false) -> some View {
        Button {
            onAction(action)
        } label: {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(isDestructive ? .red : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var appSource: MeetingApp {
        MeetingApp(rawValue: transcription.appRawValue) ?? .unknown
    }

    private var sourceDisplayName: String {
        let trimmed = transcription.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? appSource.displayName : trimmed
    }

    private var toggledCapturePurpose: CapturePurpose {
        transcription.capturePurpose == .meeting ? .dictation : .meeting
    }

    private var toggleCapturePurposeLabel: String {
        switch transcription.capturePurpose {
        case .dictation:
            "transcription.actions.mark_as_meeting".localized
        case .meeting:
            "transcription.actions.mark_as_dictation".localized
        }
    }

    private var toggleCapturePurposeIcon: String {
        switch transcription.capturePurpose {
        case .dictation:
            "person.2.fill"
        case .meeting:
            "text.bubble.fill"
        }
    }

    private var currentPersistedMeetingTitle: String? {
        let detailTitle = transcriptionDetail?.meeting.preferredTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let detailTitle, !detailTitle.isEmpty {
            return detailTitle
        }

        let metadataTitle = transcription.meetingTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let metadataTitle, !metadataTitle.isEmpty {
            return metadataTitle
        }

        return nil
    }

    private var shouldDisplayMeetingTitle: Bool {
        transcription.capturePurpose == .meeting
    }

    private var collapsedMeetingTitle: String {
        currentPersistedMeetingTitle ?? sourceDisplayName
    }

    private var meetingTitleEditor: some View {
        Group {
            if isEditingMeetingTitle {
                TextField(
                    "",
                    text: $draftMeetingTitle,
                    prompt: Text(sourceDisplayName),
                )
                .textFieldStyle(.roundedBorder)
                .font(.title3.weight(.semibold))
                .focused($isMeetingTitleFieldFocused)
                .onSubmit {
                    commitMeetingTitleEdit()
                }
                .onChange(of: isMeetingTitleFieldFocused) { _, isFocused in
                    if !isFocused {
                        commitMeetingTitleEdit()
                    }
                }
                .onExitCommand {
                    cancelMeetingTitleEdit()
                }
            } else {
                Button {
                    beginMeetingTitleEdit()
                } label: {
                    Text(currentPersistedMeetingTitle ?? sourceDisplayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func beginMeetingTitleEdit() {
        guard transcription.supportsMeetingConversation else { return }
        draftMeetingTitle = currentPersistedMeetingTitle ?? ""
        isEditingMeetingTitle = true
        isMeetingTitleFieldFocused = true
    }

    private func commitMeetingTitleEdit() {
        guard isEditingMeetingTitle else { return }

        let trimmedTitle = draftMeetingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditingMeetingTitle = false
        isMeetingTitleFieldFocused = false
        draftMeetingTitle = trimmedTitle
        onAction(.updateMeetingTitle(trimmedTitle.isEmpty ? nil : trimmedTitle))
    }

    private func cancelMeetingTitleEdit() {
        guard isEditingMeetingTitle else { return }

        isEditingMeetingTitle = false
        isMeetingTitleFieldFocused = false
        draftMeetingTitle = currentPersistedMeetingTitle ?? ""
    }

    private func syncDraftMeetingTitleIfNeeded() {
        guard !isEditingMeetingTitle else { return }
        draftMeetingTitle = currentPersistedMeetingTitle ?? ""
    }

    private func sourceLabel(text: String) -> some View {
        HStack(spacing: 6) {
            AppIconView(
                bundleIdentifier: transcription.appBundleIdentifier,
                fallbackSystemName: appSource.icon,
                size: 18,
                cornerRadius: 4,
            )
            Text(text)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(.secondary)
    }
}

private struct TranscriptionCardPreviewContainer: View {
    @State private var isExpanded = true

    var body: some View {
        TranscriptionCardView(
            transcription: .previewMetadata,
            transcriptionDetail: .previewDetail,
            isExpanded: isExpanded,
            audioURL: nil,
            availablePrompts: PostProcessingPrompt.allPredefined,
            availableRetryTranscriptionOptions: [
                RetryTranscriptionOption(
                    selection: TranscriptionProviderSelection(
                        provider: .local,
                        selectedModel: LocalTranscriptionModel.parakeetTdt06BV3.rawValue,
                    ),
                ),
            ],
            onToggleExpand: { isExpanded.toggle() },
            onAction: { _ in },
        )
        .padding()
        .frame(width: 760)
    }
}

private extension TranscriptionMetadata {
    static var previewMetadata: Self {
        .init(
            id: UUID(),
            meetingId: UUID(),
            meetingTitle: "Sprint Planning",
            appName: "Google Meet",
            appRawValue: "google-meet",
            appBundleIdentifier: "com.google.Chrome",
            startTime: Date().addingTimeInterval(-900),
            createdAt: Date(),
            previewText: "Resumo da sprint: concluímos os endpoints de transcrição, faltando validar tratamento de erros e UX da aba de settings.",
            wordCount: 24,
            language: "pt",
            isPostProcessed: true,
            duration: 540,
            audioFilePath: nil,
            inputSource: "microphone",
        )
    }
}

private extension Transcription {
    static var previewDetail: Self {
        .init(
            meeting: Meeting(
                app: .googleMeet,
                title: "Sprint Planning",
                state: .completed,
                startTime: Date().addingTimeInterval(-1_200),
                endTime: Date().addingTimeInterval(-600),
                audioFilePath: nil,
            ),
            segments: [
                .init(speaker: "Speaker 1", text: "Finalizamos o fluxo principal do processamento.", startTime: 0, endTime: 12),
                .init(speaker: "Speaker 2", text: "Próximo passo é revisar os previews dos componentes.", startTime: 13, endTime: 24),
            ],
            text: "Finalizamos o fluxo principal do processamento. Próximo passo é revisar os previews dos componentes.",
            rawText: "finalizamos fluxo principal processamento proximo passo revisar previews componentes",
            processedContent: "Finalizamos o fluxo principal do processamento. O próximo passo é revisar os previews dos componentes.",
            postProcessingPromptTitle: "Clean transcription",
            language: "pt",
        )
    }
}

#Preview("Expanded") {
    TranscriptionCardPreviewContainer()
}

#Preview("Collapsed") {
    TranscriptionCardView(
        transcription: .previewMetadata,
        transcriptionDetail: .previewDetail,
        isExpanded: false,
        audioURL: nil,
        availablePrompts: PostProcessingPrompt.allPredefined,
        availableRetryTranscriptionOptions: [
            RetryTranscriptionOption(
                selection: TranscriptionProviderSelection(
                    provider: .local,
                    selectedModel: LocalTranscriptionModel.parakeetTdt06BV3.rawValue,
                ),
            ),
            RetryTranscriptionOption(
                selection: TranscriptionProviderSelection(
                    provider: .groq,
                    selectedModel: TranscriptionProvider.groqPresetModelIDs[0],
                ),
            ),
        ],
        onToggleExpand: {},
        onAction: { _ in },
    )
    .padding()
    .frame(width: 760)
}
