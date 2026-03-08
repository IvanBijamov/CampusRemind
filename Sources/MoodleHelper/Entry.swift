import ArgumentParser
import MoodleHelperCore

@main
struct MoodleHelper: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "moodlehelper",
        abstract: "Sync Moodle assignments to Apple Reminders",
        subcommands: [
            SyncCommand.self,
            ConfigureCommand.self,
            ExcludeCommand.self,
            InstallScheduleCommand.self,
            UninstallScheduleCommand.self,
        ],
        defaultSubcommand: SyncCommand.self
    )
}
