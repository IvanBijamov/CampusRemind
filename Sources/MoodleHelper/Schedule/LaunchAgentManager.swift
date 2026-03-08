import Foundation

enum LaunchAgentManager {
    static let label = "com.moodlehelper.sync"

    static var plistURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static func install(hour: Int = 8) throws {
        // Find the built binary
        let binaryPath = try findBinary()
        let logPath = AppConfig.configDirectory.appendingPathComponent("sync.log").path

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [binaryPath, "sync"],
            "StartCalendarInterval": ["Hour": hour, "Minute": 0],
            "StandardOutPath": logPath,
            "StandardErrorPath": logPath,
            "RunAtLoad": false,
        ]

        let fm = FileManager.default
        let launchAgentsDir = plistURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: launchAgentsDir.path) {
            try fm.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        }

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
    }

    static func load() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistURL.path]
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ScheduleError.loadFailed
        }
    }

    static func unload() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistURL.path]
        try process.run()
        process.waitUntilExit()
        // Don't throw on failure — may not be loaded
    }

    static func uninstall() throws {
        try? unload()
        let fm = FileManager.default
        if fm.fileExists(atPath: plistURL.path) {
            try fm.removeItem(at: plistURL)
        }
    }

    private static func findBinary() throws -> String {
        // Check if running from a known location
        let possiblePaths = [
            "/usr/local/bin/moodlehelper",
            ProcessInfo.processInfo.arguments.first,
        ].compactMap { $0 }

        let fm = FileManager.default
        for path in possiblePaths {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fall back to the current executable
        return ProcessInfo.processInfo.arguments[0]
    }
}

enum ScheduleError: LocalizedError {
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .loadFailed: return "Failed to load launchd agent"
        }
    }
}
