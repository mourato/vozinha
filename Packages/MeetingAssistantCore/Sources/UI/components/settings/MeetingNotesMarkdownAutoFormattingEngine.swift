import AppKit
import Foundation

extension NSAttributedString.Key {
    static let meetingNotesAdornment = NSAttributedString.Key("meetingNotesAdornment")
    static let meetingNotesHeadingLevel = NSAttributedString.Key("meetingNotesHeadingLevel")
    static let meetingNotesTaskMarkerState = NSAttributedString.Key("meetingNotesTaskMarkerState")
}

enum MeetingNotesMarkdownListKind: Equatable {
    case unordered
    case ordered(number: Int)
    case task(isChecked: Bool)
}

struct MeetingNotesMarkdownLineMatch {
    let lineRange: NSRange
    let bodyRange: NSRange
    let markerRange: NSRange?
    let listKind: MeetingNotesMarkdownListKind?
    let indent: String
}

enum MeetingNotesMarkdownLineStartTrigger: Equatable {
    case unordered(indent: String)
    case ordered(indent: String, number: Int)
    case task(indent: String, isChecked: Bool)
    case heading(indent: String, level: Int)
}

enum MeetingNotesMarkdownReturnAction: Equatable {
    case continueList(insertion: String)
    case exitList(replacementRange: NSRange)
    case resetHeading
    case none
}

struct MeetingNotesOrderedListReplacement {
    let range: NSRange
    let replacement: String
}

enum MeetingNotesMarkdownAutoFormattingEngine {
    static let unorderedMarker = "• "
    static let uncheckedTaskMarker = "☐ "
    static let checkedTaskMarker = "☑ "

    static func lineMatch(in text: NSString, lineRange: NSRange) -> MeetingNotesMarkdownLineMatch {
        let lineBodyRange = bodyRange(for: lineRange, in: text)
        let lineBodyText = text.substring(with: lineBodyRange)
        let (indent, indentLength) = splitIndentation(lineBodyText)
        let markerOffset = indentLength
        let rest = String(lineBodyText.dropFirst(indentLength))

        if rest.hasPrefix(unorderedMarker) {
            let markerRange = NSRange(location: lineBodyRange.location + markerOffset, length: unorderedMarker.count)
            let contentRange = NSRange(
                location: markerRange.location + markerRange.length,
                length: max(0, NSMaxRange(lineBodyRange) - (markerRange.location + markerRange.length)),
            )
            return MeetingNotesMarkdownLineMatch(
                lineRange: lineRange,
                bodyRange: contentRange,
                markerRange: markerRange,
                listKind: .unordered,
                indent: indent,
            )
        }

        if rest.hasPrefix(uncheckedTaskMarker) || rest.hasPrefix(checkedTaskMarker) {
            let marker = rest.hasPrefix(checkedTaskMarker) ? checkedTaskMarker : uncheckedTaskMarker
            let markerRange = NSRange(location: lineBodyRange.location + markerOffset, length: marker.count)
            let contentRange = NSRange(
                location: markerRange.location + markerRange.length,
                length: max(0, NSMaxRange(lineBodyRange) - (markerRange.location + markerRange.length)),
            )
            return MeetingNotesMarkdownLineMatch(
                lineRange: lineRange,
                bodyRange: contentRange,
                markerRange: markerRange,
                listKind: .task(isChecked: marker == checkedTaskMarker),
                indent: indent,
            )
        }

        if let ordered = orderedListMatch(in: rest) {
            let markerRange = NSRange(
                location: lineBodyRange.location + markerOffset + ordered.markerLocalRange.location,
                length: ordered.markerLocalRange.length,
            )
            let contentRange = NSRange(
                location: markerRange.location + markerRange.length,
                length: max(0, NSMaxRange(lineBodyRange) - (markerRange.location + markerRange.length)),
            )
            return MeetingNotesMarkdownLineMatch(
                lineRange: lineRange,
                bodyRange: contentRange,
                markerRange: markerRange,
                listKind: .ordered(number: ordered.number),
                indent: indent,
            )
        }

        return MeetingNotesMarkdownLineMatch(
            lineRange: lineRange,
            bodyRange: lineBodyRange,
            markerRange: nil,
            listKind: nil,
            indent: indent,
        )
    }

    static func lineStartTrigger(for linePrefix: String) -> MeetingNotesMarkdownLineStartTrigger? {
        let (indent, indentLength) = splitIndentation(linePrefix)
        let raw = String(linePrefix.dropFirst(indentLength))

        if raw == "-" || raw == "*" {
            return .unordered(indent: indent)
        }

        if let ordered = orderedTriggerNumber(in: raw) {
            return .ordered(indent: indent, number: ordered)
        }

        if raw == "[ ]" || raw == "[]" {
            return .task(indent: indent, isChecked: false)
        }

        if raw == "[x]" || raw == "[X]" {
            return .task(indent: indent, isChecked: true)
        }

        if raw.allSatisfy({ $0 == "#" }), raw.count >= 1, raw.count <= 6 {
            return .heading(indent: indent, level: raw.count)
        }

        return nil
    }

    static func returnAction(in text: NSString, insertionLocation: Int, headingLevel: Int?) -> MeetingNotesMarkdownReturnAction {
        guard text.length > 0 else {
            if headingLevel != nil {
                return .resetHeading
            }
            return .none
        }

        let clamped = min(max(insertionLocation, 0), text.length)
        let lineRange = text.lineRange(for: NSRange(location: clamped, length: 0))
        let line = lineMatch(in: text, lineRange: lineRange)

        guard let listKind = line.listKind else {
            if headingLevel != nil {
                return .resetHeading
            }
            return .none
        }

        let hasBodyText = !text.substring(with: line.bodyRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty

        if !hasBodyText {
            return .exitList(replacementRange: bodyRange(for: lineRange, in: text))
        }

        switch listKind {
        case .unordered:
            return .continueList(insertion: "\n\(line.indent)\(unorderedMarker)")
        case let .ordered(number):
            return .continueList(insertion: "\n\(line.indent)\(number + 1). ")
        case let .task(isChecked):
            let marker = isChecked ? checkedTaskMarker : uncheckedTaskMarker
            return .continueList(insertion: "\n\(line.indent)\(marker)")
        }
    }

    static func orderedListRenumberReplacements(in text: NSString) -> [MeetingNotesOrderedListReplacement] {
        guard text.length > 0 else { return [] }

        var replacements: [MeetingNotesOrderedListReplacement] = []
        var countersByDepth: [Int: Int] = [:]

        enumerateLineRanges(in: text) { lineRange in
            let match = lineMatch(in: text, lineRange: lineRange)
            guard let listKind = match.listKind else {
                countersByDepth.removeAll()
                return
            }

            switch listKind {
            case let .ordered(number):
                let depth = indentationDepth(for: match.indent)
                countersByDepth = countersByDepth.filter { $0.key <= depth }
                let nextNumber = (countersByDepth[depth] ?? 0) + 1
                countersByDepth[depth] = nextNumber

                guard nextNumber != number,
                      let markerRange = match.markerRange
                else {
                    return
                }

                let markerText = text.substring(with: markerRange)
                let currentDigits = markerText.prefix { $0.isNumber }
                let replacementRange = NSRange(location: markerRange.location, length: currentDigits.count)
                replacements.append(
                    MeetingNotesOrderedListReplacement(
                        range: replacementRange,
                        replacement: String(nextNumber),
                    ),
                )
            case .unordered, .task:
                countersByDepth.removeAll()
            }
        }

        return replacements
    }

    @MainActor
    static func headingLevel(at location: Int, in textView: NSTextView) -> Int? {
        guard let storage = textView.textStorage, storage.length > 0 else { return nil }
        let clamped = min(max(location, 0), storage.length - 1)
        let value = storage.attribute(.meetingNotesHeadingLevel, at: clamped, effectiveRange: nil)
        return value as? Int
    }

    static func bodyRange(for lineRange: NSRange, in text: NSString) -> NSRange {
        guard lineRange.length > 0 else { return lineRange }
        let lineText = text.substring(with: lineRange)
        if lineText.hasSuffix("\n") {
            return NSRange(location: lineRange.location, length: max(0, lineRange.length - 1))
        }
        return lineRange
    }

    static func enumerateLineRanges(in text: NSString, _ body: (NSRange) -> Void) {
        var location = 0
        while location < text.length {
            let lineRange = text.lineRange(for: NSRange(location: location, length: 0))
            body(lineRange)
            location = NSMaxRange(lineRange)
        }

        if text.length == 0 {
            body(NSRange(location: 0, length: 0))
        }
    }

    private static func splitIndentation(_ line: String) -> (indent: String, length: Int) {
        let indentPrefix = line.prefix { $0 == " " || $0 == "\t" }
        return (String(indentPrefix), indentPrefix.count)
    }

    private static func orderedTriggerNumber(in text: String) -> Int? {
        guard text.hasSuffix("."), text.count >= 2 else { return nil }
        let digits = text.dropLast()
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber), let value = Int(digits) else {
            return nil
        }
        return value
    }

    private static func indentationDepth(for indent: String) -> Int {
        var depth = 0
        var spaces = 0
        for char in indent {
            if char == "\t" {
                depth += 1
                spaces = 0
            } else if char == " " {
                spaces += 1
                if spaces == 4 {
                    depth += 1
                    spaces = 0
                }
            }
        }

        if spaces > 0 {
            depth += 1
        }
        return depth
    }

    private static func orderedListMatch(in text: String) -> (number: Int, markerLocalRange: NSRange)? {
        var digits = ""
        for character in text {
            guard character.isNumber else { break }
            digits.append(character)
        }

        guard !digits.isEmpty,
              let number = Int(digits)
        else {
            return nil
        }

        let suffixStart = text.index(text.startIndex, offsetBy: digits.count)
        let suffix = text[suffixStart...]
        guard suffix.hasPrefix(". ") else { return nil }

        return (
            number,
            NSRange(location: 0, length: digits.count + 2),
        )
    }
}
