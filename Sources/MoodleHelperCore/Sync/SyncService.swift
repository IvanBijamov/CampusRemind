import EventKit
import Foundation

public struct SyncResult {
    public var created: Int
    public var skipped: Int
    public var errors: Int
    public var timestamp: Date

    public init(created: Int = 0, skipped: Int = 0, errors: Int = 0, timestamp: Date = Date()) {
        self.created = created
        self.skipped = skipped
        self.errors = errors
        self.timestamp = timestamp
    }

    public var summary: String {
        "\(created) created, \(skipped) skipped, \(errors) errors"
    }
}

public enum SyncService {
    public static func performSync(
        config: AppConfig,
        skipNetworkCheck: Bool = false,
        networkTimeout: Int = 300,
        enableSummarization: Bool = false,
        dryRun: Bool = false,
        verbose: Bool = false
    ) async throws -> SyncResult {
        // Wait for network connectivity
        if !skipNetworkCheck {
            try await NetworkMonitor.waitForConnectivity(timeout: networkTimeout, verbose: verbose)
        } else if verbose {
            print("Network check: skipped")
        }

        // Initialize summarizer if enabled
        let summarize: ((String?) async -> String?)? = makeSummarizer(enabled: enableSummarization, verbose: verbose)

        // Request Reminders access
        let remindersManager = RemindersManager()
        try await remindersManager.requestAccess()

        // Fetch assignments via iCal
        var courseAssignments = try await fetchViaICal(config: config, verbose: verbose)

        // Clean course names
        courseAssignments = courseAssignments.map { course in
            (courseName: cleanCourseName(course.courseName), assignments: course.assignments)
        }

        // Merge courses that now have the same cleaned name
        var merged: [String: [(title: String, notes: String?, dueDate: Date?)]] = [:]
        for course in courseAssignments {
            merged[course.courseName, default: []].append(contentsOf: course.assignments)
        }
        courseAssignments = merged.map { (courseName: $0.key, assignments: $0.value) }
            .sorted { $0.courseName < $1.courseName }

        // Filter excluded courses
        let excluded = config.excludedCourses ?? []
        if !excluded.isEmpty {
            courseAssignments = courseAssignments.filter { course in
                let isExcluded = excluded.contains { substring in
                    course.courseName.localizedCaseInsensitiveContains(substring)
                }
                if isExcluded && verbose {
                    print("[excluded] \(course.courseName)")
                }
                return !isExcluded
            }
        }

        // Create reminders
        var result = SyncResult()

        for course in courseAssignments {
            if verbose {
                print("\n--- \(course.courseName) ---")
            }

            let list: EKCalendar
            do {
                list = try await remindersManager.findOrCreateList(named: course.courseName)
            } catch {
                print("  Error creating list '\(course.courseName)': \(error.localizedDescription)")
                result.errors += course.assignments.count
                continue
            }

            if course.assignments.isEmpty && verbose {
                print("  (no assignments)")
            }

            for assignment in course.assignments {
                // Check for cancellation between each assignment so we
                // stop promptly if the system reclaims our background time
                if Task.isCancelled {
                    if verbose { print("  [cancelled] stopping early") }
                    return result
                }

                do {
                    let exists = try await remindersManager.reminderExists(
                        title: assignment.title,
                        dueDate: assignment.dueDate,
                        inList: list
                    )

                    if exists {
                        if verbose {
                            print("  [skip] \(assignment.title)")
                        }
                        result.skipped += 1
                        continue
                    }

                    // Summarize description if enabled
                    let notes: String?
                    if let summarize {
                        notes = await summarize(assignment.notes)
                    } else {
                        notes = assignment.notes
                    }

                    if dryRun {
                        let dateStr = assignment.dueDate.map { formatDate($0) } ?? "no due date"
                        print("  [dry-run] Would create: \(assignment.title) (\(dateStr))")
                        result.created += 1
                    } else {
                        try await remindersManager.createReminder(
                            title: assignment.title,
                            notes: notes,
                            dueDate: assignment.dueDate,
                            inList: list
                        )
                        if verbose {
                            let dateStr = assignment.dueDate.map { formatDate($0) } ?? "no due date"
                            print("  [created] \(assignment.title) (\(dateStr))")
                        }
                        result.created += 1
                    }
                } catch {
                    print("  Error with '\(assignment.title)': \(error.localizedDescription)")
                    result.errors += 1
                }
            }
        }

        return result
    }

    // MARK: - Summarizer Factory

    private static func makeSummarizer(enabled: Bool, verbose: Bool) -> ((String?) async -> String?)? {
        guard enabled else {
            if verbose { print("AI summarization: disabled") }
            return nil
        }

        if #available(macOS 26.0, iOS 26.0, *) {
            do {
                let summarizer = try DescriptionSummarizer(verbose: verbose)
                if verbose { print("AI summarization: enabled (on-device)") }
                return { text in await summarizer.summarize(text) }
            } catch {
                if verbose { print("AI summarization: unavailable (\(error.localizedDescription))") }
                return nil
            }
        } else {
            if verbose { print("AI summarization: unavailable (requires macOS 26 / iOS 26)") }
            return nil
        }
    }

    // MARK: - Private Helpers

    private static func fetchViaICal(
        config: AppConfig,
        verbose: Bool
    ) async throws -> [(courseName: String, assignments: [(title: String, notes: String?, dueDate: Date?)])] {
        if verbose { print("Fetching iCal calendar...") }
        let events = try await ICalParser.fetchAndParse(from: config.icalURL)
        if verbose { print("Found \(events.count) calendar events") }

        // Collect all unique course names, then group assignments
        var allCourses: Set<String> = []
        var grouped: [String: [(title: String, notes: String?, dueDate: Date?)]] = [:]

        for event in events {
            let courseName = event.categories ?? "Uncategorized"
            allCourses.insert(courseName)

            // Skip attendance events
            if event.summary.lowercased().hasPrefix("attendance") {
                if verbose { print("  [filtered] \(event.summary)") }
                continue
            }

            let title = cleanTitle(event.summary)
            let notes = event.description.map { stripHTML($0) }
            let dueDate = event.dtend ?? event.dtstart
            grouped[courseName, default: []].append((title: title, notes: notes, dueDate: dueDate))
        }

        // Ensure all courses appear, even those with only attendance
        return allCourses.sorted().map { course in
            (courseName: course, assignments: grouped[course] ?? [])
        }
    }

    /// Extracts a clean course name like "HIS 213" from "HIS-213-1/CRE-213-1/ES-213-1-202610"
    public static func cleanCourseName(_ raw: String) -> String {
        let firstSegment = raw.components(separatedBy: "/").first ?? raw
        let parts = firstSegment.components(separatedBy: "-")

        var dept: String?
        var number: String?
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if dept == nil && trimmed.allSatisfy({ $0.isLetter }) {
                dept = trimmed
            } else if dept != nil && number == nil && trimmed.allSatisfy({ $0.isNumber }) {
                number = trimmed
                break
            }
        }

        if let dept = dept, let number = number {
            return "\(dept) \(number)"
        }

        return raw
    }

    public static func cleanTitle(_ title: String) -> String {
        var result = title.trimmingCharacters(in: .whitespaces)
        for suffix in [" is due", " is due.", " closes", " closes."] {
            if result.lowercased().hasSuffix(suffix) {
                result = String(result.dropLast(suffix.count))
                break
            }
        }
        return result
    }

    public static func stripHTML(_ html: String) -> String {
        var result = html.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " "),
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        result = result.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }

    public static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
