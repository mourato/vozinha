// PostProcessingRepositoryAdapter - Adapter para PostProcessingRepository usando PostProcessingService
// Seguindo Clean Architecture

import Foundation
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

/// Adapter que implementa PostProcessingRepository usando PostProcessingService existente
@MainActor
public final class PostProcessingRepositoryAdapter: PostProcessingRepository, PostProcessingRepositorySelectionAware {
    private let postProcessingService: any PostProcessingServiceProtocol
    private let settings: AppSettingsStore

    public init(postProcessingService: any PostProcessingServiceProtocol) {
        self.postProcessingService = postProcessingService
        settings = .shared
    }

    public func processTranscription(_ transcription: String) async throws -> String {
        try await postProcessingService.processTranscription(transcription)
    }

    public func processTranscription(
        _ transcription: String,
        mode: IntelligenceKernelMode,
    ) async throws -> String {
        if let prompt = selectedPrompt(for: mode) {
            return try await postProcessingService.processTranscription(
                transcription,
                with: prompt,
                mode: mode,
                systemPromptOverride: nil,
            )
        }

        return try await postProcessingService.processTranscription(transcription)
    }

    public func processTranscription(
        _ transcription: String,
        with prompt: DomainPostProcessingPrompt,
    ) async throws -> String {
        // Converter DomainPostProcessingPrompt para PostProcessingPrompt (legado)
        let legacyPrompt = PostProcessingPrompt(
            id: prompt.id,
            title: prompt.title,
            promptText: prompt.content,
            isActive: true,
        )
        return try await postProcessingService.processTranscription(transcription, with: legacyPrompt)
    }

    public func processTranscription(
        _ transcription: String,
        with prompt: DomainPostProcessingPrompt,
        mode: IntelligenceKernelMode,
    ) async throws -> String {
        let legacyPrompt = PostProcessingPrompt(
            id: prompt.id,
            title: prompt.title,
            promptText: prompt.content,
            isActive: true,
        )
        return try await postProcessingService.processTranscription(
            transcription,
            with: legacyPrompt,
            mode: mode,
            systemPromptOverride: nil,
        )
    }

    public func processTranscriptionStructured(_ transcription: String) async throws -> DomainPostProcessingResult {
        try await postProcessingService.processTranscriptionStructured(transcription)
    }

    public func processTranscriptionStructured(
        _ transcription: String,
        mode: IntelligenceKernelMode,
    ) async throws -> DomainPostProcessingResult {
        if let prompt = selectedPrompt(for: mode) {
            return try await postProcessingService.processTranscriptionStructured(
                transcription,
                with: prompt,
                mode: mode,
            )
        }

        return try await postProcessingService.processTranscriptionStructured(transcription)
    }

    public func processTranscriptionStructured(
        _ transcription: String,
        with prompt: DomainPostProcessingPrompt,
    ) async throws -> DomainPostProcessingResult {
        let legacyPrompt = PostProcessingPrompt(
            id: prompt.id,
            title: prompt.title,
            promptText: prompt.content,
            isActive: true,
        )
        return try await postProcessingService.processTranscriptionStructured(transcription, with: legacyPrompt)
    }

    public func processTranscriptionStructured(
        _ transcription: String,
        with prompt: DomainPostProcessingPrompt,
        mode: IntelligenceKernelMode,
    ) async throws -> DomainPostProcessingResult {
        let legacyPrompt = PostProcessingPrompt(
            id: prompt.id,
            title: prompt.title,
            promptText: prompt.content,
            isActive: true,
        )
        return try await postProcessingService.processTranscriptionStructured(
            transcription,
            with: legacyPrompt,
            mode: mode,
        )
    }

    public func processTranscription(
        _ transcription: String,
        with prompt: DomainPostProcessingPrompt,
        mode: IntelligenceKernelMode,
        selection: DomainPostProcessingSelection,
    ) async throws -> String {
        let legacyPrompt = PostProcessingPrompt(id: prompt.id, title: prompt.title, promptText: prompt.content, isActive: true)
        let aiSelection = EnhancementsAISelection(
            provider: AIProvider(rawValue: selection.providerID) ?? .openai,
            selectedModel: selection.modelID,
            registrationID: selection.registrationID,
        )
        return try await postProcessingService.processTranscription(
            transcription,
            with: legacyPrompt,
            mode: mode,
            selectionOverride: aiSelection,
            systemPromptOverride: nil,
        )
    }

    public func processTranscriptionStructured(
        _ transcription: String,
        with prompt: DomainPostProcessingPrompt,
        mode: IntelligenceKernelMode,
        selection: DomainPostProcessingSelection,
    ) async throws -> DomainPostProcessingResult {
        let legacyPrompt = PostProcessingPrompt(id: prompt.id, title: prompt.title, promptText: prompt.content, isActive: true)
        return try await postProcessingService.processTranscriptionStructured(
            transcription,
            with: legacyPrompt,
            mode: mode,
            selectionOverride: EnhancementsAISelection(
                provider: AIProvider(rawValue: selection.providerID) ?? .openai,
                selectedModel: selection.modelID,
                registrationID: selection.registrationID,
            ),
        )
    }

    private func selectedPrompt(for mode: IntelligenceKernelMode) -> PostProcessingPrompt? {
        switch mode {
        case .meeting:
            settings.selectedPrompt
        case .dictation, .assistant:
            settings.selectedDictationPrompt ?? .defaultPrompt
        }
    }
}
