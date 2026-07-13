import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

extension PostProcessingService {
    struct ProviderRequestContext {
        let transcription: String
        let prompt: PostProcessingPrompt
        let mode: IntelligenceKernelMode
        let selectionOverride: EnhancementsAISelection?
        let systemPromptOverride: String?
        let timeoutSeconds: TimeInterval
        let requestConfig: AIConfiguration
        let traceContext: RequestTraceContext
        let attempt: Int
    }

    struct CustomProviderRequestContext {
        let mode: IntelligenceKernelMode
        let selectionOverride: EnhancementsAISelection?
        let systemPrompt: String
        let userContent: String
        let timeoutSeconds: TimeInterval
        let requestConfig: AIConfiguration
        let traceContext: RequestTraceContext
        let attempt: Int
    }

    // MARK: - Request/Response

    func performAIRequest(context: ProviderRequestContext) async throws -> String {
        let requestStartedAt = Date()
        let config = context.requestConfig
        let apiKey = try getAPIKey(selectionOverride: context.selectionOverride, mode: context.mode, provider: config.provider)
        let url = try buildURL(for: config, apiKey: apiKey)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = context.timeoutSeconds

        configureAuthHeaders(for: &request, provider: config.provider, apiKey: apiKey)
        try setRequestBody(
            for: &request,
            config: config,
            transcription: context.transcription,
            prompt: context.prompt,
            systemPromptOverride: context.systemPromptOverride,
            mode: context.mode,
        )

        AppLogger.debug(
            "Sending post-processing request",
            category: .transcriptionEngine,
            extra: traceExtra(
                from: context.traceContext,
                attempt: context.attempt,
                elapsedMilliseconds: nil,
                extra: ["url": sanitizedURLForLogging(url)],
            ),
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let output = try parseSuccessResponse(data: data, provider: config.provider)
        AppLogger.debug(
            "Post-processing provider request succeeded",
            category: .transcriptionEngine,
            extra: traceExtra(
                from: context.traceContext,
                attempt: context.attempt,
                elapsedMilliseconds: Date().timeIntervalSince(requestStartedAt) * 1_000,
            ),
        )
        return output
    }

    func performCustomAIRequest(context: CustomProviderRequestContext) async throws -> String {
        let requestStartedAt = Date()
        let config = context.requestConfig
        let apiKey = try getAPIKey(selectionOverride: context.selectionOverride, mode: context.mode, provider: config.provider)
        let url = try buildURL(for: config, apiKey: apiKey)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = context.timeoutSeconds

        configureAuthHeaders(for: &request, provider: config.provider, apiKey: apiKey)
        try setCustomRequestBody(
            for: &request,
            config: config,
            systemMessage: context.systemPrompt,
            userContent: context.userContent,
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let output = try parseSuccessResponse(data: data, provider: config.provider)
        AppLogger.debug(
            "Custom post-processing provider request succeeded",
            category: .transcriptionEngine,
            extra: traceExtra(
                from: context.traceContext,
                attempt: context.attempt,
                elapsedMilliseconds: Date().timeIntervalSince(requestStartedAt) * 1_000,
            ),
        )
        return output
    }

    func shouldRetry(error: Error) -> Bool {
        if (error as NSError).domain == NSURLErrorDomain {
            let code = (error as NSError).code
            if code == NSURLErrorTimedOut ||
                code == NSURLErrorNetworkConnectionLost ||
                code == NSURLErrorCannotConnectToHost
            {
                return true
            }
        }

        if case let PostProcessingError.apiError(message) = error,
           message.contains("429") || message.contains("HTTP 5")
        {
            return true
        }

        if case let PostProcessingError.requestFailed(underlyingError) = error {
            return shouldRetry(error: underlyingError)
        }

        return false
    }

    func getAPIKey(for mode: IntelligenceKernelMode, provider: AIProvider) throws -> String {
        try getAPIKey(selectionOverride: nil, mode: mode, provider: provider)
    }

    func getAPIKey(
        selectionOverride: EnhancementsAISelection?,
        mode: IntelligenceKernelMode,
        provider: AIProvider,
    ) throws -> String {
        if let selectionOverride,
           let modeKey = settings.enhancementsAPIKey(for: selectionOverride),
           !modeKey.isEmpty
        {
            return modeKey
        }

        if let modeKey = settings.enhancementsAPIKey(for: mode), !modeKey.isEmpty {
            return modeKey
        }

        guard let apiKey = try? KeychainManager.retrieveAPIKey(for: provider), !apiKey.isEmpty else {
            throw PostProcessingError.noAPIConfigured
        }
        return apiKey
    }

    func buildURL(for config: AIConfiguration, apiKey: String) throws -> URL {
        let endpoint = try buildEndpoint(
            for: config.provider,
            baseURL: config.baseURL,
            model: config.selectedModel,
        )
        guard var components = URLComponents(string: endpoint) else {
            throw PostProcessingError.invalidURL
        }

        if config.provider == .google {
            components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        }

        guard let url = components.url else {
            throw PostProcessingError.invalidURL
        }

        return url
    }

    func configureAuthHeaders(
        for request: inout URLRequest,
        provider: AIProvider,
        apiKey: String,
    ) {
        switch provider {
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue(Constants.anthropicAPIVersion, forHTTPHeaderField: "anthropic-version")
        case .google:
            break
        case .openai, .groq, .custom:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
    }

    func setRequestBody(
        for request: inout URLRequest,
        config: AIConfiguration,
        transcription: String,
        prompt: PostProcessingPrompt,
        systemPromptOverride: String?,
        mode: IntelligenceKernelMode,
    ) throws {
        let requestPrompts = AIPromptTemplates.requestPrompts(
            transcription: transcription,
            prompt: prompt,
            mode: mode,
            selectedModel: config.selectedModel,
            baseSystemPrompt: baseSystemPromptOverride(systemPromptOverride, mode: mode),
            promptContentTransformer: { cleanPrompt in
                guard self.shouldApplyMeetingLanguagePreference(mode: mode, prompt: prompt) else {
                    return cleanPrompt
                }
                return self.applyMeetingLanguagePreferenceIfNeeded(to: cleanPrompt, mode: mode)
            },
        )

        try setCustomRequestBody(
            for: &request,
            config: config,
            systemMessage: requestPrompts.systemPrompt,
            userContent: requestPrompts.userPrompt,
        )
    }

    private func baseSystemPromptOverride(_ systemPromptOverride: String?, mode: IntelligenceKernelMode) -> String? {
        switch mode {
        case .dictation:
            systemPromptOverride
        case .meeting, .assistant:
            systemPromptOverride ?? settings.systemPrompt
        }
    }

    private func shouldApplyMeetingLanguagePreference(
        mode: IntelligenceKernelMode,
        prompt: PostProcessingPrompt,
    ) -> Bool {
        guard mode == .meeting else { return false }
        return !prompt.promptText.contains("<INTERNAL_MEETING_TYPE_CLASSIFIER>")
    }

    func setCustomRequestBody(
        for request: inout URLRequest,
        config: AIConfiguration,
        systemMessage: String,
        userContent: String,
    ) throws {
        let encoder = JSONEncoder()

        do {
            switch config.provider {
            case .anthropic:
                let payload = AnthropicMessageRequest(
                    model: config.selectedModel,
                    maxTokens: Constants.maxTokens,
                    system: systemMessage,
                    messages: [AIChatMessage(role: "user", content: userContent)],
                )
                request.httpBody = try encoder.encode(payload)
            case .google:
                let payload = GeminiGenerateContentRequest(
                    systemInstruction: GeminiSystemInstruction(parts: [GeminiPart(text: systemMessage)]),
                    contents: [GeminiContent(role: "user", parts: [GeminiPart(text: userContent)])],
                    generationConfig: GeminiGenerationConfig(maxOutputTokens: Constants.maxTokens),
                )
                request.httpBody = try encoder.encode(payload)
            case .openai, .groq, .custom:
                let messages = [
                    AIChatMessage(role: "system", content: systemMessage),
                    AIChatMessage(role: "user", content: userContent),
                ]
                let payload = OpenAIChatRequest(
                    model: config.selectedModel,
                    messages: messages,
                    maxTokens: Constants.maxTokens,
                )
                request.httpBody = try encoder.encode(payload)
            }
        } catch {
            AppLogger.error("Failed to encode request body", category: .transcriptionEngine, error: error)
            throw PostProcessingError.requestFailed(error)
        }
    }

    private func applyMeetingLanguagePreferenceIfNeeded(
        to prompt: String,
        mode: IntelligenceKernelMode,
    ) -> String {
        guard mode == .meeting else { return prompt }

        let language = settings.meetingSummaryOutputLanguage
        let languageInstruction = if language == .original {
            """
            <OUTPUT_LANGUAGE>
            The final summary must be written in the same language spoken in the meeting transcription.
            </OUTPUT_LANGUAGE>
            """
        } else {
            """
            <OUTPUT_LANGUAGE>
            Translate the final output to \(language.instructionDisplayName). This requirement overrides any instruction that says to keep the original language.
            </OUTPUT_LANGUAGE>
            """
        }
        return [prompt, languageInstruction].joined(separator: "\n\n")
    }

    func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostProcessingError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let decoder = JSONDecoder()
            if let errorResponse = try? decoder.decode(OpenAIErrorResponse.self, from: data) {
                throw PostProcessingError.apiError(errorResponse.error.message)
            }
            if let errorResponse = try? decoder.decode(AnthropicErrorResponse.self, from: data) {
                throw PostProcessingError.apiError(errorResponse.error.message)
            }
            if let errorResponse = try? decoder.decode(GeminiErrorResponse.self, from: data) {
                throw PostProcessingError.apiError(errorResponse.error.message)
            }

            let rawResponse = String(data: data, encoding: .utf8) ?? ""
            throw PostProcessingError.apiError("HTTP \(httpResponse.statusCode): \(rawResponse)")
        }
    }

    func parseSuccessResponse(data: Data, provider: AIProvider) throws -> String {
        let decoder = JSONDecoder()

        do {
            switch provider {
            case .anthropic:
                let response = try decoder.decode(AnthropicMessageResponse.self, from: data)
                guard let text = response.content.first?.text else {
                    throw PostProcessingError.invalidResponse
                }
                return text
            case .google:
                let response = try decoder.decode(GeminiGenerateContentResponse.self, from: data)
                guard let text = response.candidates?.first?.content?.parts.first?.text else {
                    throw PostProcessingError.invalidResponse
                }
                return text
            case .openai, .groq, .custom:
                let response = try decoder.decode(OpenAIChatResponse.self, from: data)
                guard let content = response.choices.first?.message.content else {
                    throw PostProcessingError.invalidResponse
                }
                return content
            }
        } catch {
            AppLogger.error("Failed to decode response", category: .transcriptionEngine, error: error)
            throw PostProcessingError.invalidResponse
        }
    }

    func buildEndpoint(for provider: AIProvider, baseURL: String, model: String) throws -> String {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL

        switch provider {
        case .openai, .groq, .custom:
            return "\(base)/chat/completions"
        case .anthropic:
            return "\(base)/messages"
        case .google:
            let rawModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawModel.isEmpty else {
                throw PostProcessingError.noAPIConfigured
            }
            let normalizedModel = rawModel.hasPrefix("models/") ? rawModel : "models/\(rawModel)"
            return "\(base)/\(normalizedModel):generateContent"
        }
    }

    func sanitizedURLForLogging(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }

        if let queryItems = components.queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems.map { item in
                URLQueryItem(name: item.name, value: "REDACTED")
            }
        }

        return components.url?.absoluteString ?? url.absoluteString
    }
}
