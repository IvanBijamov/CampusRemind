import ArgumentParser
import Foundation

struct ExcludeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "exclude",
        abstract: "Manage excluded courses (by substring match)"
    )

    @Argument(help: "Substrings to add to the exclusion list (e.g. 'PHY 108' 'Miscellaneous')")
    var patterns: [String] = []

    @Flag(name: .long, help: "List current exclusions")
    var list = false

    @Flag(name: .long, help: "Clear all exclusions")
    var clear = false

    @Option(name: .long, help: "Remove a specific exclusion")
    var remove: String?

    func run() async throws {
        var config: AppConfig
        do {
            config = try AppConfig.load()
        } catch {
            print("Error: No configuration found. Run 'moodlehelper configure' first.")
            throw ExitCode.failure
        }

        if clear {
            config.excludedCourses = []
            try config.save()
            print("Cleared all exclusions.")
            return
        }

        if let toRemove = remove {
            config.excludedCourses?.removeAll { $0.caseInsensitiveCompare(toRemove) == .orderedSame }
            try config.save()
            print("Removed '\(toRemove)' from exclusions.")
            printExclusions(config)
            return
        }

        if !patterns.isEmpty {
            var current = config.excludedCourses ?? []
            for pattern in patterns {
                if !current.contains(where: { $0.caseInsensitiveCompare(pattern) == .orderedSame }) {
                    current.append(pattern)
                    print("Added '\(pattern)' to exclusions.")
                } else {
                    print("'\(pattern)' already excluded.")
                }
            }
            config.excludedCourses = current
            try config.save()
            printExclusions(config)
            return
        }

        // Default: list exclusions
        printExclusions(config)
    }

    private func printExclusions(_ config: AppConfig) {
        let exclusions = config.excludedCourses ?? []
        if exclusions.isEmpty {
            print("No excluded courses.")
        } else {
            print("\nExcluded courses:")
            for e in exclusions {
                print("  - \(e)")
            }
        }
    }
}
