import ArgumentParser
import EventKit
import Foundation

struct SyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Sync Moodle assignments to Apple Reminders"
    )

    @Flag(name: .long, help: "Show what would be done without creating reminders")
    var dryRun = false

    @Flag(name: .long, help: "Show detailed output")
    var verbose = false

    @Option(name: .long, help: "Seconds to wait for network connectivity (default: 300)")
    var networkTimeout: Int = 300

    @Flag(name: .long, help: "Skip the network connectivity check")
    var skipNetworkCheck = false

    @Flag(name: .long, help: "Disable AI description summarization for this run")
    var noSummarize = false

    func run() async throws {
        // Load config
        let config: AppConfig
        do {
            config = try AppConfig.load()
        } catch {
            print("Error: No configuration found. Run 'moodlehelper configure' first.")
            throw ExitCode.failure
        }

        // Wait for network connectivity
        if !skipNetworkCheck {
            do {
                try await NetworkMonitor.waitForConnectivity(timeout: networkTimeout, verbose: verbose)
            } catch {
                print("Error: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        } else if verbose {
            print("Network check: skipped")
        }

        // Initialize summarizer if enabled
        let summarizer: DescriptionSummarizer?
        if !noSummarize, config.enableSummarization == true {
            do {
                summarizer = try DescriptionSummarizer(verbose: verbose)
                if verbose { print("AI summarization: enabled (on-device)") }
            } catch {
                summarizer = nil
                if verbose { print("AI summarization: unavailable (\(error.localizedDescription))") }
            }
        } else {
            summarizer = nil
            if verbose { print("AI summarization: disabled") }
        }

        // Request Reminders access
        let remindersManager = RemindersManager()
        do {
            try await remindersManager.requestAccess()
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        // Fetch assignments
        var courseAssignments: [(courseName: String, assignments: [(title: String, notes: String?, dueDate: Date?)])]

        if config.useICalFallback {
            courseAssignments = try await fetchViaICal(config: config)
        } else {
            courseAssignments = try await fetchViaAPI(config: config)
        }

        // Clean course names first
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

        // Filter excluded courses (after name cleaning so exclusions match cleaned names)
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
        var totalCreated = 0
        var totalSkipped = 0
        var totalErrors = 0

        for course in courseAssignments {
            if verbose {
                print("\n--- \(course.courseName) ---")
            }

            // Always create the list, even if there are no assignments
            let list: EKCalendar
            do {
                list = try await remindersManager.findOrCreateList(named: course.courseName)
            } catch {
                print("  Error creating list '\(course.courseName)': \(error.localizedDescription)")
                totalErrors += course.assignments.count
                continue
            }

            if course.assignments.isEmpty && verbose {
                print("  (no assignments)")
            }

            for assignment in course.assignments {
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
                        totalSkipped += 1
                        continue
                    }

                    // Summarize description if enabled
                    let notes: String?
                    if let summarizer {
                        notes = await summarizer.summarize(assignment.notes)
                    } else {
                        notes = assignment.notes
                    }

                    if dryRun {
                        let dateStr = assignment.dueDate.map { formatDate($0) } ?? "no due date"
                        print("  [dry-run] Would create: \(assignment.title) (\(dateStr))")
                        totalCreated += 1
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
                        totalCreated += 1
                    }
                } catch {
                    print("  Error with '\(assignment.title)': \(error.localizedDescription)")
                    totalErrors += 1
                }
            }
        }

        print("\nSync complete: \(totalCreated) created, \(totalSkipped) skipped, \(totalErrors) errors")
    }

    private func fetchViaAPI(config: AppConfig) async throws -> [(courseName: String, assignments: [(title: String, notes: String?, dueDate: Date?)])] {
        guard var token = config.token else {
            print("Error: No API token. Run 'moodlehelper configure'.")
            throw ExitCode.failure
        }

        var client = MoodleClient(baseURL: config.moodleBaseURL, token: token)

        let siteInfo: SiteInfo
        do {
            siteInfo = try await client.getSiteInfo()
        } catch MoodleClientError.tokenExpired {
            if verbose { print("Token expired, re-authenticating...") }
            guard let password = try? KeychainHelper.load(account: config.username) else {
                print("Error: Token expired and no password in Keychain. Run 'moodlehelper configure'.")
                throw ExitCode.failure
            }
            token = try await MoodleClient.authenticate(
                baseURL: config.moodleBaseURL,
                username: config.username,
                password: password
            )
            var updatedConfig = config
            updatedConfig.token = token
            try updatedConfig.save()

            client = MoodleClient(baseURL: config.moodleBaseURL, token: token)
            siteInfo = try await client.getSiteInfo()
        }

        if verbose { print("Logged in as \(siteInfo.fullname)") }

        let courses = try await client.getCourses(userId: siteInfo.userid)
        if verbose { print("Found \(courses.count) courses") }

        guard !courses.isEmpty else { return [] }

        let courseIds = courses.map(\.id)
        let assignmentsResponse = try await client.getAssignments(courseIds: courseIds)

        // Build a set of course IDs that have assignments
        let coursesWithAssignments = Set(assignmentsResponse.courses.map(\.id))

        var results = assignmentsResponse.courses.map { course in
            let assignments = course.assignments.compactMap { a -> (title: String, notes: String?, dueDate: Date?)? in
                if a.name.lowercased().hasPrefix("attendance") { return nil }
                let dueDate: Date? = a.duedate > 0 ? Date(timeIntervalSince1970: TimeInterval(a.duedate)) : nil
                let title = cleanTitle(a.name)
                let notes = a.intro.map { stripHTML($0) }
                return (title: title, notes: notes, dueDate: dueDate)
            }
            return (courseName: course.fullname, assignments: assignments)
        }

        // Add courses that had no assignments at all
        for course in courses where !coursesWithAssignments.contains(course.id) {
            results.append((courseName: course.fullname, assignments: []))
        }

        return results
    }

    private func fetchViaICal(config: AppConfig) async throws -> [(courseName: String, assignments: [(title: String, notes: String?, dueDate: Date?)])] {
        guard let icalURL = config.icalURL else {
            print("Error: No iCal URL configured. Run 'moodlehelper configure'.")
            throw ExitCode.failure
        }

        if verbose { print("Fetching iCal calendar...") }
        let events = try await ICalParser.fetchAndParse(from: icalURL)
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

        // Ensure all courses appear, even those with only attendance (no assignments after filter)
        return allCourses.sorted().map { course in
            (courseName: course, assignments: grouped[course] ?? [])
        }
    }

    /// Extracts a clean course name like "HIS 213" from "HIS-213-1/CRE-213-1/ES-213-1-202610"
    private func cleanCourseName(_ raw: String) -> String {
        // Take the first segment before any "/" (e.g. "HIS-213-1-202610")
        let firstSegment = raw.components(separatedBy: "/").first ?? raw

        // Split by "-" to get parts like ["HIS", "213", "1", "202610"]
        let parts = firstSegment.components(separatedBy: "-")

        // Find the department (letters) and course number (digits)
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

        // Fallback: return raw if pattern doesn't match
        return raw
    }

    private func cleanTitle(_ title: String) -> String {
        var result = title.trimmingCharacters(in: .whitespaces)
        for suffix in [" is due", " is due.", " closes", " closes."] {
            if result.lowercased().hasSuffix(suffix) {
                result = String(result.dropLast(suffix.count))
                break
            }
        }
        return result
    }

    private func stripHTML(_ html: String) -> String {
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
