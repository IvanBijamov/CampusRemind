import ArgumentParser
import Foundation
import MoodleHelperCore

struct InstallScheduleCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install-schedule",
        abstract: "Install a daily launchd agent to sync automatically"
    )

    @Option(name: .long, help: "Hour of day to run sync (0-23)")
    var hour: Int = 8

    func run() async throws {
        guard hour >= 0 && hour <= 23 else {
            print("Error: Hour must be between 0 and 23")
            throw ExitCode.failure
        }

        print("Installing daily sync schedule (runs at \(hour):00)...")

        do {
            try LaunchAgentManager.install(hour: hour)
            try LaunchAgentManager.load()
            print("Launch agent installed at: \(LaunchAgentManager.plistURL.path)")
            print("Sync will run daily at \(hour):00.")
            print("\nTo verify: launchctl list | grep moodlehelper")
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}
