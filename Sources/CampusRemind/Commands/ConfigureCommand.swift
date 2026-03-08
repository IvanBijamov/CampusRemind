import ArgumentParser
import Foundation
import CampusRemindCore

struct ConfigureCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "configure",
        abstract: "Configure Moodle iCal URL and settings"
    )

    func run() async throws {
        print("=== CampusRemind Configuration ===\n")

        // Prompt for Moodle URL
        print("Moodle URL [https://moodle.conncoll.edu]: ", terminator: "")
        let urlInput = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
        let moodleURL = urlInput.isEmpty ? "https://moodle.conncoll.edu" : urlInput

        // Prompt for iCal URL
        print("\nTo get your iCal export URL:")
        print("  1. Log into Moodle in your browser")
        print("  2. Go to Calendar (or Dashboard)")
        print("  3. Click 'Export calendar' at the bottom")
        print("  4. Select 'All courses' and 'Events from courses'")
        print("  5. Click 'Get calendar URL' and copy the URL")
        print("\niCal export URL: ", terminator: "")

        guard let icalURL = readLine()?.trimmingCharacters(in: .whitespaces), !icalURL.isEmpty else {
            throw ConfigError.missingICalURL
        }

        var config = AppConfig(
            moodleBaseURL: moodleURL,
            icalURL: icalURL
        )

        // Save config
        try config.save()
        print("\nConfiguration saved to \(AppConfig.configFile.path)")

        // Trigger Reminders permission dialog
        print("\nRequesting Reminders access...")
        let manager = RemindersManager()
        do {
            try await manager.requestAccess()
            print("Reminders access granted!")
        } catch {
            print("Warning: \(error.localizedDescription)")
        }

        // AI Summarization setup
        print("\n--- AI Description Summarization (Optional) ---")
        print("Summarize verbose assignment descriptions using on-device Apple Intelligence.")
        print("Enable summarization? [y/N]: ", terminator: "")
        let summarizeAnswer = readLine()?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""

        if summarizeAnswer == "y" || summarizeAnswer == "yes" {
            config.enableSummarization = true
            try config.save()
            print("Summarization enabled!")
        } else {
            print("Skipped. You can enable it later in the config file.")
        }

        print("\nSetup complete! Run 'campusremind sync' to sync assignments.")
    }
}

enum ConfigError: LocalizedError {
    case missingICalURL

    var errorDescription: String? {
        switch self {
        case .missingICalURL: return "iCal export URL is required"
        }
    }
}
