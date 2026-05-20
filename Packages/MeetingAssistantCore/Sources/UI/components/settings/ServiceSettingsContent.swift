import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct ServiceSettingsContent: View {
    @StateObject private var viewModel: ServiceSettingsViewModel
    @ObservedObject private var settings: AppSettingsStore
    private let runInitialTasks: Bool

    public init(
        viewModel: ServiceSettingsViewModel = ServiceSettingsViewModel(),
        settings: AppSettingsStore = .shared,
        runInitialTasks: Bool = !PreviewRuntime.isRunning
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _settings = ObservedObject(wrappedValue: settings)
        self.runInitialTasks = runInitialTasks
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Layout.sectionSpacing) {
            transcriptionProviderSection
            modelInfoSection
            statusSection
            performanceSection
        }
        .task {
            guard runInitialTasks else { return }
            viewModel.refreshInstalledModelStates()
            viewModel.testConnection()
        }
    }

    private var transcriptionProviderSection: some View {
        ServiceTranscriptionProviderSection(viewModel: viewModel)
    }

    private var modelInfoSection: some View {
        DSGroup("settings.models.transcription_model".localized, icon: "waveform") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppDesignSystem.Colors.accent.opacity(0.1))
                            .frame(width: 48, height: 48)
                        Image(systemName: "cpu")
                            .font(.title2)
                            .foregroundStyle(AppDesignSystem.Colors.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.service.on_device".localized)
                            .font(.headline)
                        Text("settings.service.ane_opt".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().padding(.vertical, 4)

                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                    GridRow {
                        Text("settings.service.model".localized)
                            .foregroundStyle(.secondary)

                        HStack {
                            VStack(alignment: .leading) {
                                Text(viewModel.meetingLocalModelDisplayName)
                                    .fontWeight(.medium)
                                Text(asrStatusText)
                                    .font(.caption2)
                                    .foregroundStyle(asrStatusColor)
                            }

                            Spacer()

                            if viewModel.modelState == .downloading || viewModel.modelState == .loading {
                                ProgressView()
                                    .controlSize(.small)
                            } else if viewModel.isASRInstalled {
                                Button(role: .destructive) {
                                    viewModel.deleteASRModels()
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(AppDesignSystem.Colors.error)
                                }
                                .buttonStyle(.borderless)
                                .help("settings.service.delete_model".localized)
                            } else {
                                Button {
                                    viewModel.downloadASRModels()
                                } label: {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.title3)
                                        .foregroundStyle(AppDesignSystem.Colors.accent)
                                }
                                .buttonStyle(.borderless)
                                .help("settings.service.download_model".localized)
                            }
                        }
                    }

                    Divider()

                    if settings.isMeetingTranscriptionEnabled {
                        GridRow {
                            Text("settings.service.diarization".localized)
                                .foregroundStyle(.secondary)

                            HStack {
                                VStack(alignment: .leading) {
                                    Text("settings.service.diarization_model_name".localized)
                                        .fontWeight(.medium)
                                    Text(
                                        viewModel.isDiarizationLoaded
                                            ? "settings.service.installed".localized
                                            : "settings.service.not_installed".localized
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(viewModel.isDiarizationLoaded ? AppDesignSystem.Colors.success : .secondary)
                                }

                                Spacer()

                                if viewModel.isDiarizationLoaded {
                                    Button(role: .destructive) {
                                        viewModel.deleteDiarizationModels()
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(AppDesignSystem.Colors.error)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("settings.service.delete_model".localized)
                                } else {
                                    Button {
                                        viewModel.downloadDiarizationModels()
                                    } label: {
                                        Image(systemName: "arrow.down.circle")
                                            .font(.title3)
                                            .foregroundStyle(AppDesignSystem.Colors.accent)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("settings.service.download_model".localized)
                                }
                            }
                        }
                    }

                    GridRow {
                        Text("settings.service.languages".localized)
                            .foregroundStyle(.secondary)
                        Text("settings.service.languages_desc".localized)
                            .fontWeight(.medium)
                    }

                    GridRow(alignment: .top) {
                        Text("settings.service.model_residency_timeout".localized)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            Picker(
                                "settings.service.model_residency_timeout".localized,
                                selection: Binding(
                                    get: { viewModel.modelResidencyTimeout },
                                    set: { viewModel.modelResidencyTimeout = $0 }
                                )
                            ) {
                                ForEach(viewModel.modelResidencyTimeoutOptions, id: \.self) { option in
                                    Text(option.displayName)
                                        .tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()

                            Text("settings.service.model_residency_timeout.help".localized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .font(.subheadline)
            }
        }
    }

    private var performanceSection: some View {
        DSGroup("settings.models.high_performance".localized, icon: "speedometer") {
            Text("settings.service.no_internet".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusSection: some View {
        DSGroup("settings.models.service_status".localized, icon: "dot.radiowaves.left.and.right") {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.transcriptionStatus.color)
                            .frame(width: 8, height: 8)
                        Text(viewModel.transcriptionStatus.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let detail = viewModel.transcriptionStatus.detail,
                       !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }

                Spacer()

                Button(
                    action: { viewModel.testConnection() },
                    label: {
                        if viewModel.transcriptionStatus == .testing {
                            ProgressView().controlSize(.small)
                        } else {
                            Label(
                                "settings.service.verify".localized,
                                systemImage: "arrow.clockwise"
                            )
                        }
                    }
                )
                .buttonStyle(.bordered)
                .disabled(viewModel.transcriptionStatus == .testing)
            }
        }
    }

    private var asrStatusText: String {
        switch viewModel.modelState {
        case .loaded: "settings.service.installed".localized
        case .downloading: "transcription.model_state.downloading".localized
        case .loading: "transcription.model_state.loading".localized
        case .unloaded: viewModel.isASRInstalled ? "settings.service.installed".localized : "settings.service.not_installed".localized
        case .error: "transcription.model_state.error".localized
        }
    }

    private var asrStatusColor: Color {
        switch viewModel.modelState {
        case .loaded: AppDesignSystem.Colors.success
        case .downloading, .loading: AppDesignSystem.Colors.warning
        case .unloaded:
            viewModel.isASRInstalled ? AppDesignSystem.Colors.success : .secondary
        case .error:
            .secondary
        }
    }
}

@MainActor
private struct ServiceSettingsContentPreview: View {
    @StateObject private var viewModel: ServiceSettingsViewModel

    init() {
        let viewModel = ServiceSettingsViewModel()
        viewModel.transcriptionStatus = .success
        viewModel.modelState = .loaded
        viewModel.isASRInstalled = true
        viewModel.isDiarizationLoaded = true
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ServiceSettingsContent(viewModel: viewModel, runInitialTasks: false)
            .padding()
            .frame(width: 760)
    }
}

#Preview("Service Settings Content") {
    ServiceSettingsContentPreview()
}
