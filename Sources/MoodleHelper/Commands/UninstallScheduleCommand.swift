import ArgumentParser
import Foundation
import MoodleHelperCore

struct UninstallScheduleCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "uninstall-schedule",
        abstract: "Remove the daily sync launchd agent"
    )

    func run() async throws {
        print("Removing sync schedule...")

        do {
            try LaunchAgentManager.uninstall()
            print("Launch agent removed.")
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}
