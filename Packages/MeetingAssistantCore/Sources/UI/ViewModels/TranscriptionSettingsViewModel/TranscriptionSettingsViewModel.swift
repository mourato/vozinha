import AppKit
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import OSLog
import SwiftUI

@MainActor
public class TranscriptionSettingsViewModel: ObservableObject {
    public struct AppFilterOption: Identifiable, Hashable, Sendable {
        public enum Scope: Hashable, Sendable {
            case all
            case appRawValue(String)
            case appBundleIdentifier(String)
            case appDisplayName(String)
        }

        public let id: String
        public let scope: Scope
        public let displayName: String
    }

    private enum FilterConstants {
        static let allAppsId = "__all_apps__"
        static let rawAppPrefix = "raw:"
        static let bundleAppPrefix = "bundle:"
        static let nameAppPrefix = "name:"
    }

    public struct QATurn: Identifiable, Hashable, Sendable {
        public let id: UUID
        public let question: String
        public let response: MeetingQAResponse?
        public let errorMessage: String?
        public let createdAt: Date

        public init(
            id: UUID = UUID(),
            question: String,
            response: MeetingQAResponse?,
            errorMessage: String?,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.question = question
            self.response = response
            self.errorMessage = errorMessage
            self.createdAt = createdAt
        }
    }

    @Published public var transcriptions: [TranscriptionMetadata] = []
    @Published public var selectedTranscription: Transcription?
    @Published public var selectedId: UUID? {
        didSet {
            if let id = selectedId {
                Task { await self.loadFullTranscription(id: id) }
            } else {
                Task {
                    self.selectedTranscription = nil
                }
            }
        }
    }

    @Published public var isProcessingAI = false
    @Published public var postProcessingByTranscriptionID: Set<UUID> = []
    @Published public var postProcessingErrorByTranscriptionID: [UUID: String] = [:]
    @Published public var qaQuestion = ""
    @Published public var qaResponse: MeetingQAResponse?
    @Published public var isAnsweringQuestion = false
    @Published public var qaErrorMessage: String?
    @Published public var qaHistoryByTranscription: [UUID: [QATurn]] = [:]
    @Published public var qaModelSelectionByTranscription: [UUID: MeetingQAModelSelection] = [:]

    @Published public var isLoading = true
    @Published public var sourceFilter: RecordingSourceFilter = .all
    @Published public var dateFilter: DateFilter = .today
    @Published public var searchText = ""
    @Published public var appFilterId = FilterConstants.allAppsId
    @Published public var loadErrorMessage: String?
    @Published public var operationErrorMessage: String?

    @Published public var showDeleteConfirmation = false
    @Published public var pendingDeleteTranscription: TranscriptionMetadata?

    let storage: StorageService
    let recordingManager: RecordingManager
    let meetingRepository: MeetingRepository
    let meetingQAService: any MeetingQAServiceProtocol
    let meetingNotesRichTextStore: any MeetingNotesRichTextStoreProtocol
    let meetingNotesMarkdownStore: any MeetingNotesMarkdownDocumentStoreProtocol
    let settings: AppSettingsStore
    let keychain: KeychainProvider
    let isLocalModelReady: @MainActor (LocalTranscriptionModel) -> Bool
    let savePanelProvider: @MainActor () -> NSSavePanel
    let summaryExportHelper: SummaryExportHelperProtocol
    let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "TranscriptionSettingsViewModel")
    var lastAskedQuestion: String?
    var lastQuestionTranscriptionId: UUID?

    static let segmentSortComparator: (Transcription.Segment, Transcription.Segment) -> Bool = { lhs, rhs in
        if lhs.startTime != rhs.startTime {
            return lhs.startTime < rhs.startTime
        }
        if lhs.endTime != rhs.endTime {
            return lhs.endTime < rhs.endTime
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    public init(
        storage: StorageService = FileSystemStorageService.shared,
        recordingManager: RecordingManager = .shared,
        meetingRepository: MeetingRepository = CoreDataMeetingRepository(),
        meetingQAService: any MeetingQAServiceProtocol = MeetingQAService.shared,
        meetingNotesRichTextStore: any MeetingNotesRichTextStoreProtocol = MeetingNotesRichTextStore(),
        meetingNotesMarkdownStore: any MeetingNotesMarkdownDocumentStoreProtocol = MeetingNotesMarkdownDocumentStore.shared,
        settings: AppSettingsStore = .shared,
        keychain: KeychainProvider = DefaultKeychainProvider(),
        isLocalModelReady: @escaping @MainActor (LocalTranscriptionModel) -> Bool = {
            FluidAIModelManager.shared.isASRModelInstalled(localModelID: $0.rawValue)
        },
        savePanelProvider: @escaping @MainActor () -> NSSavePanel = { NSSavePanel() },
        summaryExportHelper: SummaryExportHelperProtocol = SummaryExportHelper()
    ) {
        self.storage = storage
        self.recordingManager = recordingManager
        self.meetingRepository = meetingRepository
        self.meetingQAService = meetingQAService
        self.meetingNotesRichTextStore = meetingNotesRichTextStore
        self.meetingNotesMarkdownStore = meetingNotesMarkdownStore
        self.settings = settings
        self.keychain = keychain
        self.isLocalModelReady = isLocalModelReady
        self.savePanelProvider = savePanelProvider
        self.summaryExportHelper = summaryExportHelper
    }

    public var isMeetingQnAEnabled: Bool {
        settings.meetingQnAEnabled
    }

    public func canOpenMeetingConversation(for metadata: TranscriptionMetadata) -> Bool {
        metadata.supportsMeetingConversation
    }

    public func qaHistory(for transcriptionID: UUID) -> [QATurn] {
        qaHistoryByTranscription[transcriptionID] ?? []
    }

    public func effectiveMeetingQAModelSelection(for transcriptionID: UUID) -> MeetingQAModelSelection {
        if let override = qaModelSelectionByTranscription[transcriptionID],
           AIProvider(rawValue: override.providerRawValue) != nil,
           !override.modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return override
        }

        let defaults = settings.enhancementsAISelection
        return MeetingQAModelSelection(
            providerRawValue: defaults.provider.rawValue,
            modelID: defaults.selectedModel
        )
    }

    public var filteredTranscriptions: [TranscriptionMetadata] {
        let selectedAppScope = selectedAppFilterScope()
        return transcriptions.filter { transcription in
            let matchesSource = self.matchesSourceFilter(transcription)
            let matchesDate = self.dateFilter.contains(transcription.createdAt)
            let matchesApp = self.matchesAppFilter(transcription, scope: selectedAppScope)
            let matchesText = self.matchesSearchFilter(transcription)
            return matchesSource && matchesDate && matchesApp && matchesText
        }
    }

    public var appFilterOptions: [AppFilterOption] {
        let optionsById = transcriptions.reduce(into: [String: AppFilterOption]()) { result, transcription in
            guard let option = appFilterOption(for: transcription) else { return }
            result[option.id] = option
        }

        let allAppsOption = AppFilterOption(
            id: FilterConstants.allAppsId,
            scope: .all,
            displayName: "settings.transcriptions.filter_app_all".localized
        )

        let sortedAppOptions = optionsById.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        return [allAppsOption] + sortedAppOptions
    }

    /// Transcriptions grouped by date (start of day) for section headers.
    public var groupedTranscriptions: [Date: [TranscriptionMetadata]] {
        Dictionary(grouping: filteredTranscriptions) { metadata in
            Calendar.current.startOfDay(for: metadata.createdAt)
        }
    }

    /// Sorted list of dates for the group headers.
    public var sortedGroupDates: [Date] {
        groupedTranscriptions.keys.sorted(by: >)
    }

    private func matchesSourceFilter(_ transcription: TranscriptionMetadata) -> Bool {
        switch sourceFilter {
        case .all:
            true
        case .dictations:
            transcription.capturePurpose == .dictation
        case .meetings:
            transcription.capturePurpose == .meeting
        }
    }

    private func matchesAppFilter(_ transcription: TranscriptionMetadata, scope: AppFilterOption.Scope) -> Bool {
        switch scope {
        case .all:
            return true
        case let .appRawValue(appRawValue):
            return transcription.appRawValue == appRawValue
        case let .appBundleIdentifier(bundleIdentifier):
            let transcriptionBundleIdentifier = transcription.appBundleIdentifier?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return transcriptionBundleIdentifier == bundleIdentifier
        case let .appDisplayName(displayName):
            return normalizedFilterValue(appDisplayName(for: transcription)) == displayName
        }
    }

    private func selectedAppFilterScope() -> AppFilterOption.Scope {
        guard appFilterId != FilterConstants.allAppsId else { return .all }

        if appFilterId.hasPrefix(FilterConstants.rawAppPrefix) {
            let rawValue = String(appFilterId.dropFirst(FilterConstants.rawAppPrefix.count))
            return rawValue.isEmpty ? .all : .appRawValue(rawValue)
        }

        if appFilterId.hasPrefix(FilterConstants.bundleAppPrefix) {
            let bundleIdentifier = String(appFilterId.dropFirst(FilterConstants.bundleAppPrefix.count))
            return bundleIdentifier.isEmpty ? .all : .appBundleIdentifier(bundleIdentifier)
        }

        if appFilterId.hasPrefix(FilterConstants.nameAppPrefix) {
            let displayName = String(appFilterId.dropFirst(FilterConstants.nameAppPrefix.count))
            return displayName.isEmpty ? .all : .appDisplayName(displayName)
        }

        return .all
    }

    private func matchesSearchFilter(_ transcription: TranscriptionMetadata) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let previewText = transcription.previewText.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let appName = transcription.appName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let meetingTitle = if transcription.supportsMeetingConversation {
            transcription.meetingTitle?
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) ?? ""
        } else {
            ""
        }

        return previewText.contains(normalizedQuery)
            || appName.contains(normalizedQuery)
            || meetingTitle.contains(normalizedQuery)
    }

    private func appDisplayName(for transcription: TranscriptionMetadata) -> String {
        let trimmedName = transcription.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }

        if let knownApp = MeetingApp(rawValue: transcription.appRawValue) {
            return knownApp.displayName
        }

        let trimmedRawValue = transcription.appRawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedRawValue.isEmpty ? MeetingApp.unknown.displayName : trimmedRawValue
    }

    private func appFilterOption(for transcription: TranscriptionMetadata) -> AppFilterOption? {
        let rawValue = transcription.appRawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = appDisplayName(for: transcription)

        if !rawValue.isEmpty, rawValue != MeetingApp.unknown.rawValue {
            return AppFilterOption(
                id: "\(FilterConstants.rawAppPrefix)\(rawValue)",
                scope: .appRawValue(rawValue),
                displayName: displayName
            )
        }

        let bundleIdentifier = transcription.appBundleIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return AppFilterOption(
                id: "\(FilterConstants.bundleAppPrefix)\(bundleIdentifier)",
                scope: .appBundleIdentifier(bundleIdentifier),
                displayName: displayName
            )
        }

        let normalizedDisplayName = normalizedFilterValue(displayName)
        guard !normalizedDisplayName.isEmpty else { return nil }
        return AppFilterOption(
            id: "\(FilterConstants.nameAppPrefix)\(normalizedDisplayName)",
            scope: .appDisplayName(normalizedDisplayName),
            displayName: displayName
        )
    }

    private func normalizedFilterValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    public func loadTranscriptions() async {
        isLoading = true
        loadErrorMessage = nil
        do {
            transcriptions = try await storage.loadAllMetadata().filter {
                $0.lifecycleState == .failed || !($0.duration == 0 && $0.previewText.isEmpty)
            }
            if !appFilterOptions.contains(where: { $0.id == appFilterId }) {
                appFilterId = FilterConstants.allAppsId
            }

            if let selectedId, !transcriptions.contains(where: { $0.id == selectedId }) {
                self.selectedId = nil
            }
        } catch {
            logger.error("Failed to load transcriptions: \(error.localizedDescription)")
            loadErrorMessage = "settings.transcriptions.error_load".localized
        }
        isLoading = false
    }

    public func loadFullTranscription(id: UUID) async {
        do {
            if selectedTranscription?.id != id {
                resetQuestionState()
            }
            selectedTranscription = try await storage.loadTranscription(by: id)
            if let selectedTranscription {
                restoreMeetingConversationState(from: selectedTranscription)
            }
        } catch {
            logger.error("Failed to load full transcription: \(error.localizedDescription)")
        }
    }

}
