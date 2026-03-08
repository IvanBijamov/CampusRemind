import ArgumentParser
import Foundation
import MoodleHelperCore

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
        let config: AppConfig
        do {
            config = try AppConfig.load()
        } catch {
            print("Error: No configuration found. Run 'moodlehelper configure' first.")
            throw ExitCode.failure
        }

        let enableSummarization = !noSummarize && (config.enableSummarization == true)

        do {
            let result = try await SyncService.performSync(
                config: config,
                skipNetworkCheck: skipNetworkCheck,
                networkTimeout: networkTimeout,
                enableSummarization: enableSummarization,
                dryRun: dryRun,
                verbose: verbose
            )
            print("\nSync complete: \(result.summary)")
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}
