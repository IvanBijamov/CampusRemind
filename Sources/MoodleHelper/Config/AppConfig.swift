import Foundation

struct AppConfig: Codable {
    var moodleBaseURL: String
    var username: String
    var token: String?
    var icalURL: String?
    var useICalFallback: Bool
    var excludedCourses: [String]?
    var enableSummarization: Bool?

    static let configDirectory: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".moodlehelper")
    }()

    static let configFile: URL = {
        configDirectory.appendingPathComponent("config.json")
    }()

    static func load() throws -> AppConfig {
        let data = try Data(contentsOf: configFile)
        return try JSONDecoder().decode(AppConfig.self, from: data)
    }

    func save() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: AppConfig.configDirectory.path) {
            try fm.createDirectory(at: AppConfig.configDirectory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: AppConfig.configFile, options: .atomic)
    }
}
