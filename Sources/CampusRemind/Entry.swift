import ArgumentParser
import CampusRemindCore

@main
struct CampusRemind: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "campusremind",
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
