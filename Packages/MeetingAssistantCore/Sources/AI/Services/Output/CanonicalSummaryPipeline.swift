import Foundation
import MeetingAssistantCoreDomain

enum CanonicalSummaryParsingError: Error {
    case emptyOutput
    case jsonObjectNotFound
    case decodeFailed
}

struct CanonicalSummaryPromptComposer {
    func structuredPrompt(from basePrompt: String) -> String {
        """
        \(basePrompt)

        HARD REQUIREMENTS (STRICT):
        - Return ONLY valid JSON (no prose, no markdown code fences).
        - Never invent facts that are not grounded in the transcript.
        - If unsure, keep list fields empty instead of guessing.
        - Set `trustFlags.containsSpeculation` to true whenever uncertainty exists.
        - Keep `trustFlags.confidenceScore` in [0, 1].

        REQUIRED JSON SCHEMA:
        {
          "schemaVersion": 1,
          "generatedAt": "ISO-8601 datetime",
          "title": "string",
          "summary": "string",
          "keyPoints": ["string"],
          "decisions": ["string"],
          "actionItems": [
            { "title": "string", "owner": "string|null", "dueDate": "ISO-8601 datetime or yyyy-MM-dd or null" }
          ],
          "openQuestions": ["string"],
          "trustFlags": {
            "isGroundedInTranscript": true,
            "containsSpeculation": false,
            "isHumanReviewed": false,
            "confidenceScore": 0.0
          }
        }
        """
    }
}

struct CanonicalSummaryRepairComposer {
    func systemPrompt(basePrompt: String) -> String {
        """
        \(basePrompt)

        You are repairing malformed model output into valid canonical summary JSON.
        Output ONLY valid JSON following the required schema exactly.
        Do not include explanations, markdown, or extra keys.
        Do not invent facts not present in the transcript.
        """
    }

    func userMessage(
        malformedOutput: String,
        transcription: String,
        originalPrompt: String,
    ) -> String {
        """
        Repair the malformed output below into valid canonical summary JSON.

        <ORIGINAL_PROMPT>
        \(originalPrompt)
        </ORIGINAL_PROMPT>

        <TRANSCRIPTION>
        \(transcription)
        </TRANSCRIPTION>

        <MALFORMED_OUTPUT>
        \(malformedOutput)
        </MALFORMED_OUTPUT>

        Return only valid JSON.
        """
    }
}

struct CanonicalSummaryResponseParser {
    private let decoder: JSONDecoder

    init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func parse(from output: String) throws -> CanonicalSummary {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CanonicalSummaryParsingError.emptyOutput
        }

        var candidates = [trimmed]
        if let fenced = extractFirstCodeFenceBody(from: trimmed) {
            candidates.append(fenced)
        }
        if let jsonObject = extractFirstJSONObject(from: trimmed) {
            candidates.append(jsonObject)
        }

        for candidate in candidates {
            if let summary = tryDecodeSummary(from: candidate) {
                return summary
            }
        }

        throw CanonicalSummaryParsingError.decodeFailed
    }

    private func tryDecodeSummary(from candidate: String) -> CanonicalSummary? {
        guard let data = candidate.data(using: .utf8),
              let payload = try? decoder.decode(CanonicalSummaryPayload.self, from: data)
        else {
            return nil
        }

        let summary = payload.toCanonicalSummary()
        guard (try? summary.validate()) != nil else {
            return nil
        }
        return summary
    }

    private func extractFirstCodeFenceBody(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "```(?:json)?\\s*([\\s\\S]*?)```", options: [.caseInsensitive]) else {
            return nil
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1
        else {
            return nil
        }

        let bodyRange = match.range(at: 1)
        guard bodyRange.location != NSNotFound else { return nil }
        return nsText.substring(with: bodyRange).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractFirstJSONObject(from text: String) -> String? {
        var objectStart: String.Index?
        var depth = 0
        var isEscaped = false
        var isInsideString = false

        for index in text.indices {
            let char = text[index]

            if char == "\"", !isEscaped {
                isInsideString.toggle()
            }

            if isInsideString {
                isEscaped = (char == "\\") && !isEscaped
                continue
            }

            if char == "{" {
                if depth == 0 {
                    objectStart = index
                }
                depth += 1
            } else if char == "}" {
                guard depth > 0 else { continue }
                depth -= 1
                if depth == 0, let objectStart {
                    return String(text[objectStart...index])
                }
            }

            isEscaped = false
        }

        return nil
    }
}

struct DeterministicSummaryFallbackBuilder {
    private enum Constants {
        static let fallbackConfidenceScore = 0.2
        static let maxSummaryCharacters = 1_200
    }

    private let renderer = CanonicalSummaryRenderer()

    func build(providerOutput: String, transcription: String) -> DomainPostProcessingResult {
        let sourceText = normalize(providerOutput).isEmpty ? normalize(transcription) : normalize(providerOutput)
        let summaryText = clampSummary(sourceText.isEmpty ? "Summary unavailable due to malformed model output." : sourceText)
        let fallbackTitle = clampTitle(summaryText)

        let fallbackSummary = CanonicalSummary(
            title: fallbackTitle,
            summary: summaryText,
            trustFlags: .init(
                isGroundedInTranscript: false,
                containsSpeculation: true,
                isHumanReviewed: false,
                confidenceScore: Constants.fallbackConfidenceScore,
            ),
        )

        let validatedSummary: CanonicalSummary = if (try? fallbackSummary.validate()) != nil {
            fallbackSummary
        } else {
            CanonicalSummary(
                title: fallbackTitle,
                summary: "Summary unavailable due to malformed model output.",
                trustFlags: .init(
                    isGroundedInTranscript: false,
                    containsSpeculation: true,
                    isHumanReviewed: false,
                    confidenceScore: Constants.fallbackConfidenceScore,
                ),
            )
        }

        return DomainPostProcessingResult(
            processedText: renderer.render(validatedSummary),
            canonicalSummary: validatedSummary,
            outputState: .deterministicFallback,
        )
    }

    private func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clampSummary(_ text: String) -> String {
        guard text.count > Constants.maxSummaryCharacters else { return text }
        return String(text.prefix(Constants.maxSummaryCharacters))
    }

    private func clampTitle(_ text: String) -> String {
        let collapsed = text
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !collapsed.isEmpty else {
            return "Untitled Meeting"
        }

        let maxTitleCharacters = 120
        return collapsed.count > maxTitleCharacters ? String(collapsed.prefix(maxTitleCharacters)) : collapsed
    }
}

struct CanonicalSummaryRenderer {
    func render(_ summary: CanonicalSummary) -> String {
        var sections = [summary.summary.trimmingCharacters(in: .whitespacesAndNewlines)]

        if !summary.keyPoints.isEmpty {
            sections.append(renderList(title: "Key Points", values: summary.keyPoints))
        }
        if !summary.decisions.isEmpty {
            sections.append(renderList(title: "Decisions", values: summary.decisions))
        }
        if !summary.actionItems.isEmpty {
            let values = summary.actionItems.map { item in
                var line = item.title
                if let owner = item.owner, !owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    line += " (owner: \(owner))"
                }
                return line
            }
            sections.append(renderList(title: "Action Items", values: values))
        }
        if !summary.openQuestions.isEmpty {
            sections.append(renderList(title: "Open Questions", values: summary.openQuestions))
        }

        return sections
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func renderList(title: String, values: [String]) -> String {
        let bullets = values.map { "- \($0)" }.joined(separator: "\n")
        return "## \(title)\n\(bullets)"
    }
}

private struct CanonicalSummaryPayload: Decodable {
    let schemaVersion: Int?
    let generatedAt: Date?
    let title: String?
    let summary: String?
    let keyPoints: [String]?
    let decisions: [String]?
    let actionItems: [CanonicalSummaryActionItemPayload]?
    let openQuestions: [String]?
    let trustFlags: CanonicalSummaryTrustFlagsPayload?

    func toCanonicalSummary() -> CanonicalSummary {
        CanonicalSummary(
            schemaVersion: schemaVersion ?? CanonicalSummary.currentSchemaVersion,
            generatedAt: generatedAt ?? Date(),
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            summary: summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            keyPoints: cleanedEntries(keyPoints),
            decisions: cleanedEntries(decisions),
            actionItems: (actionItems ?? []).map { $0.toActionItem() },
            openQuestions: cleanedEntries(openQuestions),
            trustFlags: trustFlags?.toTrustFlags() ?? .init(),
        )
    }

    private func cleanedEntries(_ values: [String]?) -> [String] {
        (values ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct CanonicalSummaryActionItemPayload: Decodable {
    let title: String?
    let owner: String?
    let dueDate: String?

    func toActionItem() -> CanonicalSummary.ActionItem {
        CanonicalSummary.ActionItem(
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            owner: owner?.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: parseDate(dueDate),
        )
    }

    private func parseDate(_ rawValue: String?) -> Date? {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty
        else {
            return nil
        }

        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: rawValue) {
            return date
        }

        let shortFormatter = DateFormatter()
        shortFormatter.locale = Locale(identifier: "en_US_POSIX")
        shortFormatter.dateFormat = "yyyy-MM-dd"
        return shortFormatter.date(from: rawValue)
    }
}

private struct CanonicalSummaryTrustFlagsPayload: Decodable {
    let isGroundedInTranscript: Bool?
    let containsSpeculation: Bool?
    let isHumanReviewed: Bool?
    let confidenceScore: Double?

    func toTrustFlags() -> CanonicalSummary.TrustFlags {
        CanonicalSummary.TrustFlags(
            isGroundedInTranscript: isGroundedInTranscript ?? false,
            containsSpeculation: containsSpeculation ?? false,
            isHumanReviewed: isHumanReviewed ?? false,
            confidenceScore: confidenceScore ?? 0.0,
        )
    }
}
