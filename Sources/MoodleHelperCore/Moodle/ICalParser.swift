import Foundation

public struct ICalEvent {
    public let uid: String
    public let summary: String
    public let description: String?
    public let dtstart: Date?
    public let dtend: Date?
    public let categories: String?

    public init(uid: String, summary: String, description: String?, dtstart: Date?, dtend: Date?, categories: String?) {
        self.uid = uid
        self.summary = summary
        self.description = description
        self.dtstart = dtstart
        self.dtend = dtend
        self.categories = categories
    }
}

public struct ICalParser {
    public static func parse(_ icsContent: String) -> [ICalEvent] {
        let unfolded = unfoldLines(icsContent)
        let lines = unfolded.components(separatedBy: .newlines)

        var events: [ICalEvent] = []
        var inEvent = false
        var uid = ""
        var summary = ""
        var description: String?
        var dtstart: Date?
        var dtend: Date?
        var categories: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "BEGIN:VEVENT" {
                inEvent = true
                uid = ""
                summary = ""
                description = nil
                dtstart = nil
                dtend = nil
                categories = nil
            } else if trimmed == "END:VEVENT" {
                if inEvent && !summary.isEmpty {
                    events.append(ICalEvent(
                        uid: uid,
                        summary: summary,
                        description: description,
                        dtstart: dtstart,
                        dtend: dtend,
                        categories: categories
                    ))
                }
                inEvent = false
            } else if inEvent {
                if let value = extractValue(trimmed, property: "UID") {
                    uid = value
                } else if let value = extractValue(trimmed, property: "SUMMARY") {
                    summary = value
                } else if let value = extractValue(trimmed, property: "DESCRIPTION") {
                    description = value
                        .replacingOccurrences(of: "\\n", with: "\n")
                        .replacingOccurrences(of: "\\,", with: ",")
                        .replacingOccurrences(of: "\\\\", with: "\\")
                } else if let value = extractValue(trimmed, property: "CATEGORIES") {
                    categories = value
                } else if trimmed.hasPrefix("DTSTART") {
                    dtstart = parseDate(from: trimmed)
                } else if trimmed.hasPrefix("DTEND") {
                    dtend = parseDate(from: trimmed)
                }
            }
        }

        return events
    }

    public static func fetchAndParse(from urlString: String) async throws -> [ICalEvent] {
        guard let url = URL(string: urlString) else {
            throw ICalError.invalidURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw ICalError.invalidData
        }
        return parse(content)
    }

    private static func unfoldLines(_ content: String) -> String {
        // RFC 5545: lines starting with space/tab are continuations
        return content
            .replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")
    }

    private static func extractValue(_ line: String, property: String) -> String? {
        // Handle "PROPERTY:value" and "PROPERTY;params:value"
        if line.hasPrefix("\(property):") {
            return String(line.dropFirst(property.count + 1))
        }
        if line.hasPrefix("\(property);") {
            if let colonIndex = line.firstIndex(of: ":") {
                return String(line[line.index(after: colonIndex)...])
            }
        }
        return nil
    }

    private static func parseDate(from line: String) -> Date? {
        // Extract the value after the last colon
        guard let colonIndex = line.lastIndex(of: ":") else { return nil }
        let dateString = String(line[line.index(after: colonIndex)...])

        let formatters: [(String, DateFormatter)] = [
            ("yyyyMMdd'T'HHmmss'Z'", {
                let f = DateFormatter()
                f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
                f.timeZone = TimeZone(identifier: "UTC")
                return f
            }()),
            ("yyyyMMdd'T'HHmmss", {
                let f = DateFormatter()
                f.dateFormat = "yyyyMMdd'T'HHmmss"
                // Try to extract TZID from the line
                if let tzRange = line.range(of: "TZID="),
                   let colonRange = line.range(of: ":", range: tzRange.upperBound..<line.endIndex) {
                    let tzid = String(line[tzRange.upperBound..<colonRange.lowerBound])
                    f.timeZone = TimeZone(identifier: tzid) ?? .current
                } else {
                    f.timeZone = .current
                }
                return f
            }()),
            ("yyyyMMdd", {
                let f = DateFormatter()
                f.dateFormat = "yyyyMMdd"
                f.timeZone = .current
                return f
            }()),
        ]

        for (_, formatter) in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }
}

public enum ICalError: LocalizedError {
    case invalidURL
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid iCal URL"
        case .invalidData: return "Could not decode iCal data"
        }
    }
}
