import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

@MainActor
public final class MeetingQAService: ObservableObject, MeetingQAServiceProtocol {
    public static let shared = MeetingQAService()

    public typealias APIKeyProvider = (AIProvider) throws -> String
    public typealias SleepFunction = @Sendable (UInt64) async throws -> Void

    private enum Constants {
        static let requestTimeoutSeconds: TimeInterval = 45
        static let maxTokens = 1_200
        static let maxRetryAttempts = 2
        static let retryDelayNanoseconds: UInt64 = 800_000_000
        static let anthropicAPIVersion = "2023-06-01"
        static let maxSegmentsInPrompt = 40
    }

    @Published public private(set) var isAnswering = false
    @Published public private(set) var lastError: MeetingQAError?

    private let settings: AppSettingsStore
    private let session: URLSession
    private let apiKeyProvider: APIKeyProvider
    private let sleepFunction: SleepFunction

    public init(
        settings: AppSettingsStore = .shared,
        session: URLSession = .shared,
        apiKeyProvider: @escaping APIKeyProvider = { provider in
            guard let key = try KeychainManager.retrieveAPIKey(for: provider),
                  !key.isEmpty
            else {
                throw MeetingQAError.noAPIConfigured
            }
            return key
        },
        sleepFunction: @escaping SleepFunction = { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        },
    ) {
        self.settings = settings
        self.session = session
        self.apiKeyProvider = apiKeyProvider
        self.sleepFunction = sleepFunction
    }

    public func ask(question: String, transcription: Transcription) async throws -> MeetingQAResponse {
        try await ask(
            question: question,
            transcription: transcription,
            modelSelectionOverride: nil,
        )
    }

    private func ask(
        question: String,
        transcription: Transcription,
        modelSelectionOverride: MeetingQAModelSelection?,
    ) async throws -> MeetingQAResponse {
        guard settings.isIntelligenceKernelModeEnabled(.meeting) else {
            throw MeetingQAError.disabled
        }

        guard transcription.supportsMeetingConversation else {
            throw MeetingQAError.disabled
        }

        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            throw MeetingQAError.emptyQuestion
        }

        guard settings.meetingQnAEnabled else {
            throw MeetingQAError.disabled
        }

        let requestConfig = resolvedConfiguration(for: modelSelectionOverride)
        if let readinessIssue = readinessIssue(for: requestConfig) {
            AppLogger.info(
                "Meeting Q&A blocked: enhancements configuration not ready",
                category: .transcriptionEngine,
                extra: ["reasonCode": readinessIssue.rawValue],
            )
            throw meetingQAError(for: readinessIssue)
        }

        isAnswering = true
        lastError = nil
        defer { isAnswering = false }

        do {
            return try await askWithRetry(
                question: trimmedQuestion,
                transcription: transcription,
                configuration: requestConfig,
            )
        } catch let error as MeetingQAError {
            lastError = error
            throw error
        } catch let urlError as URLError {
            let mappedError: MeetingQAError = switch urlError.code {
            case .timedOut:
                .timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                .networkUnavailable
            default:
                .requestFailed(urlError.localizedDescription)
            }
            lastError = mappedError
            throw mappedError
        } catch {
            let wrapped = MeetingQAError.requestFailed(error.localizedDescription)
            lastError = wrapped
            throw wrapped
        }
    }

    public func ask(_ request: IntelligenceKernelQuestionRequest) async throws -> MeetingQAResponse {
        guard settings.isIntelligenceKernelModeEnabled(request.mode) else {
            throw MeetingQAError.disabled
        }

        switch request.mode {
        case .meeting:
            return try await ask(
                question: request.question,
                transcription: request.transcription,
                modelSelectionOverride: request.modelSelectionOverride,
            )
        case .dictation, .assistant:
            throw MeetingQAError.disabled
        }
    }

    private func askWithRetry(
        question: String,
        transcription: Transcription,
        configuration: AIConfiguration,
    ) async throws -> MeetingQAResponse {
        var lastThrownError: Error?

        for attempt in 0..<Constants.maxRetryAttempts {
            do {
                let rawOutput = try await performRequest(
                    question: question,
                    transcription: transcription,
                    configuration: configuration,
                )
                return try parseModelOutput(rawOutput)
            } catch {
                lastThrownError = error

                let shouldRetry = isRetryable(error)
                let isLastAttempt = attempt == Constants.maxRetryAttempts - 1
                guard shouldRetry, !isLastAttempt else {
                    throw error
                }

                AppLogger.warning(
                    "Meeting Q&A request failed, retrying",
                    category: .transcriptionEngine,
                    extra: ["attempt": attempt + 1],
                )
                try await sleepFunction(Constants.retryDelayNanoseconds)
            }
        }

        throw lastThrownError ?? MeetingQAError.invalidResponse
    }

    private func performRequest(
        question: String,
        transcription: Transcription,
        configuration config: AIConfiguration,
    ) async throws -> String {
        let apiKey = try getAPIKey(for: config.provider)
        let url = try buildURL(for: config, apiKey: apiKey)
        let (systemPrompt, userPrompt) = buildPrompts(question: question, transcription: transcription)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.requestTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch config.provider {
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue(Constants.anthropicAPIVersion, forHTTPHeaderField: "anthropic-version")
            let payload = AnthropicMessageRequest(
                model: config.selectedModel,
                maxTokens: Constants.maxTokens,
                system: systemPrompt,
                messages: [AIChatMessage(role: "user", content: userPrompt)],
            )
            request.httpBody = try JSONEncoder().encode(payload)

        case .google:
            let payload = GeminiGenerateContentRequest(
                systemInstruction: GeminiSystemInstruction(parts: [GeminiPart(text: systemPrompt)]),
                contents: [GeminiContent(role: "user", parts: [GeminiPart(text: userPrompt)])],
                generationConfig: GeminiGenerationConfig(maxOutputTokens: Constants.maxTokens),
            )
            request.httpBody = try JSONEncoder().encode(payload)

        case .openai, .groq, .custom:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            let payload = OpenAIChatRequest(
                model: config.selectedModel,
                messages: [
                    AIChatMessage(role: "system", content: systemPrompt),
                    AIChatMessage(role: "user", content: userPrompt),
                ],
                maxTokens: Constants.maxTokens,
            )
            request.httpBody = try JSONEncoder().encode(payload)
        }

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response: response, data: data)
        return try parseProviderResponse(data: data, provider: config.provider)
    }

    private func buildPrompts(question: String, transcription: Transcription) -> (String, String) {
        let summaryText = transcription.canonicalSummary?.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let summaryBlock = (summaryText?.isEmpty == false) ? summaryText! : "(none)"
        let meetingNotesBlock = resolvedMeetingNotesBlock(from: transcription)

        let evidenceSegments = Array(
            transcription.segments
                .sorted { lhs, rhs in
                    if lhs.startTime != rhs.startTime {
                        return lhs.startTime < rhs.startTime
                    }
                    if lhs.endTime != rhs.endTime {
                        return lhs.endTime < rhs.endTime
                    }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                .prefix(Constants.maxSegmentsInPrompt),
        )
        let transcriptBlock: String = if evidenceSegments.isEmpty {
            transcription.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            evidenceSegments.map { segment in
                let speaker = segment.speaker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? Transcription.unknownSpeaker
                    : segment.speaker
                return "[\(segment.startTime)-\(segment.endTime)] \(speaker): \(segment.text)"
            }.joined(separator: "\n")
        }

        let systemPrompt = """
        You are a grounded meeting Q&A assistant.
        Rules:
        - Answer only using information from provided transcript segments, canonical summary, and meeting notes.
        - Treat meeting notes as supplemental user-provided context.
        - If transcript evidence conflicts with meeting notes, prioritize transcript evidence.
        - Never fabricate facts.
        - If evidence is insufficient, return status not_found.
        - If status is answered, include at least one evidence item with speaker/startTime/endTime/excerpt.
        - Return ONLY valid JSON matching this schema:
        {
          "status": "answered" | "not_found",
          "answer": "string",
          "evidence": [
            {
              "speaker": "string",
              "startTime": 0.0,
              "endTime": 1.0,
              "excerpt": "string"
            }
          ]
        }
        """

        let userPrompt = """
        QUESTION:
        \(question)

        CANONICAL_SUMMARY:
        \(summaryBlock)

        MEETING_NOTES:
        \(meetingNotesBlock)

        TRANSCRIPT_SEGMENTS:
        \(transcriptBlock)
        """

        return (systemPrompt, userPrompt)
    }

    private func resolvedMeetingNotesBlock(from transcription: Transcription) -> String {
        let notes = transcription.contextItems
            .filter { $0.source == .meetingNotes }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !notes.isEmpty else {
            return "(none)"
        }

        return notes
            .map(MeetingNotesMarkdownSanitizer.sanitizeForPromptBlockContent)
            .joined(separator: "\n\n")
    }

    private func parseModelOutput(_ rawOutput: String) throws -> MeetingQAResponse {
        guard let jsonCandidate = extractJSONCandidate(from: rawOutput),
              let data = jsonCandidate.data(using: .utf8)
        else {
            throw MeetingQAError.invalidResponse
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(MeetingQAResponse.self, from: data) else {
            throw MeetingQAError.invalidResponse
        }

        if decoded.status == .answered {
            let hasAnswer = !decoded.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            guard hasAnswer, !decoded.evidence.isEmpty else {
                return .notFound
            }
            return decoded
        }

        return .notFound
    }

    private func extractJSONCandidate(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return trimmed
        }

        guard let firstBrace = trimmed.firstIndex(of: "{"),
              let lastBrace = trimmed.lastIndex(of: "}")
        else {
            return nil
        }

        return String(trimmed[firstBrace...lastBrace])
    }

    private func parseProviderResponse(data: Data, provider: AIProvider) throws -> String {
        let decoder = JSONDecoder()

        switch provider {
        case .anthropic:
            let response = try decoder.decode(AnthropicMessageResponse.self, from: data)
            guard let text = response.content.first?.text else {
                throw MeetingQAError.invalidResponse
            }
            return text

        case .google:
            let response = try decoder.decode(GeminiGenerateContentResponse.self, from: data)
            guard let text = response.candidates?.first?.content?.parts.first?.text else {
                throw MeetingQAError.invalidResponse
            }
            return text

        case .openai, .groq, .custom:
            let response = try decoder.decode(OpenAIChatResponse.self, from: data)
            guard let content = response.choices.first?.message.content else {
                throw MeetingQAError.invalidResponse
            }
            return content
        }
    }

    private func validateHTTP(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MeetingQAError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let decoder = JSONDecoder()
            if let openAIError = try? decoder.decode(OpenAIErrorResponse.self, from: data) {
                throw MeetingQAError.requestFailed(openAIError.error.message)
            }

            if let anthropicError = try? decoder.decode(AnthropicErrorResponse.self, from: data) {
                throw MeetingQAError.requestFailed(anthropicError.error.message)
            }

            if let geminiError = try? decoder.decode(GeminiErrorResponse.self, from: data) {
                throw MeetingQAError.requestFailed(geminiError.error.message)
            }

            let raw = String(data: data, encoding: .utf8) ?? ""
            throw MeetingQAError.requestFailed("HTTP \(httpResponse.statusCode): \(raw)")
        }
    }

    private func getAPIKey(for provider: AIProvider) throws -> String {
        let meetingSelectionProvider = settings.enhancementsSelection(for: .meeting).provider
        if provider == meetingSelectionProvider,
           let modeKey = settings.enhancementsAPIKey(for: .meeting),
           !modeKey.isEmpty
        {
            return modeKey
        }

        let key = try apiKeyProvider(provider)
        guard !key.isEmpty else {
            throw MeetingQAError.noAPIConfigured
        }
        return key
    }

    private func apiKeyExists(for provider: AIProvider) -> Bool {
        let meetingSelectionProvider = settings.enhancementsSelection(for: .meeting).provider
        if provider == meetingSelectionProvider,
           let modeKey = settings.enhancementsAPIKey(for: .meeting)
        {
            return !modeKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        guard let key = try? apiKeyProvider(provider) else {
            return false
        }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func meetingQAError(for issue: EnhancementsInferenceReadinessIssue) -> MeetingQAError {
        switch issue {
        case .invalidBaseURL:
            .invalidURL
        case .missingAPIKey, .missingModel:
            .noAPIConfigured
        }
    }

    private func resolvedConfiguration(for overrideSelection: MeetingQAModelSelection?) -> AIConfiguration {
        let base = settings.resolvedEnhancementsAIConfiguration(for: .meeting)
        guard let overrideSelection,
              let provider = AIProvider(rawValue: overrideSelection.providerRawValue)
        else {
            return base
        }

        let normalizedModel = settings.normalizedEnhancementsModelID(
            overrideSelection.modelID,
            for: provider,
        )
        guard !normalizedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return base
        }

        let baseURL = provider == .custom ? settings.aiConfiguration.baseURL : provider.defaultBaseURL
        return AIConfiguration(provider: provider, baseURL: baseURL, selectedModel: normalizedModel)
    }

    private func readinessIssue(for config: AIConfiguration) -> EnhancementsInferenceReadinessIssue? {
        guard isValidHTTPURLString(config.baseURL) else {
            return .invalidBaseURL
        }

        guard apiKeyExists(for: config.provider) else {
            return .missingAPIKey
        }

        let model = config.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            return .missingModel
        }

        return nil
    }

    private func isValidHTTPURLString(_ value: String) -> Bool {
        guard let url = URL(string: value) else { return false }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return false }
        guard let host = url.host, !host.isEmpty else { return false }
        return true
    }

    private func buildURL(for config: AIConfiguration, apiKey: String) throws -> URL {
        let base = config.baseURL.hasSuffix("/") ? String(config.baseURL.dropLast()) : config.baseURL
        let endpoint: String

        switch config.provider {
        case .anthropic:
            endpoint = "\(base)/messages"
        case .google:
            let rawModel = config.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawModel.isEmpty else {
                throw MeetingQAError.noAPIConfigured
            }
            let model = rawModel.hasPrefix("models/") ? rawModel : "models/\(rawModel)"
            endpoint = "\(base)/\(model):generateContent"
        case .openai, .groq, .custom:
            endpoint = "\(base)/chat/completions"
        }

        guard var components = URLComponents(string: endpoint) else {
            throw MeetingQAError.invalidURL
        }

        if config.provider == .google {
            components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        }

        guard let url = components.url else {
            throw MeetingQAError.invalidURL
        }

        return url
    }

    private func isRetryable(_ error: Error) -> Bool {
        if let qaError = error as? MeetingQAError {
            switch qaError {
            case .timeout, .networkUnavailable:
                return true
            case let .requestFailed(message):
                return message.contains("429") || message.contains("HTTP 5")
            default:
                return false
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost:
                return true
            default:
                return false
            }
        }

        return false
    }
}
