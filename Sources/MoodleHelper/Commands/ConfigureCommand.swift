import ArgumentParser
import Foundation

struct ConfigureCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "configure",
        abstract: "Configure Moodle credentials and authentication"
    )

    func run() async throws {
        print("=== MoodleHelper Configuration ===\n")

        // Prompt for Moodle URL
        print("Moodle URL [https://moodle.conncoll.edu]: ", terminator: "")
        let urlInput = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
        let moodleURL = urlInput.isEmpty ? "https://moodle.conncoll.edu" : urlInput

        // Prompt for username
        print("Username: ", terminator: "")
        guard let username = readLine()?.trimmingCharacters(in: .whitespaces), !username.isEmpty else {
            throw ConfigError.missingUsername
        }

        // Prompt for password (no echo)
        guard let passwordCStr = getpass("Password: ") else {
            throw ConfigError.missingPassword
        }
        let password = String(cString: passwordCStr)

        // Attempt REST API authentication
        print("\nAttempting Moodle API authentication...")
        var config = AppConfig(
            moodleBaseURL: moodleURL,
            username: username,
            token: nil,
            icalURL: nil,
            useICalFallback: false
        )

        do {
            let token = try await MoodleClient.authenticate(baseURL: moodleURL, username: username, password: password)
            config.token = token
            config.useICalFallback = false
            print("Authentication successful!")

            // Save password to Keychain for token refresh
            try KeychainHelper.save(account: username, password: password)
        } catch {
            print("\nREST API authentication failed: \(error.localizedDescription)")
            print("\nThis is common with SSO/CAS institutions.")
            print("Would you like to use iCal calendar export instead? [Y/n]: ", terminator: "")
            let answer = readLine()?.trimmingCharacters(in: .whitespaces).lowercased() ?? "y"

            if answer == "n" || answer == "no" {
                throw ConfigError.authFailed
            }

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

            config.icalURL = icalURL
            config.useICalFallback = true
            print("iCal fallback configured.")
        }

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
            print("Skipped. You can enable it later in ~/.moodlehelper/config.json")
        }

        print("\nSetup complete! Run 'moodlehelper sync' to sync assignments.")
    }
}

enum ConfigError: LocalizedError {
    case missingUsername
    case missingPassword
    case authFailed
    case missingICalURL

    var errorDescription: String? {
        switch self {
        case .missingUsername: return "Username is required"
        case .missingPassword: return "Password is required"
        case .authFailed: return "Authentication failed and iCal fallback declined"
        case .missingICalURL: return "iCal export URL is required for fallback mode"
        }
    }
}
