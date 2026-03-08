import Foundation

public struct AppConfig: Codable {
    public var moodleBaseURL: String
    public var icalURL: String
    public var excludedCourses: [String]?
    public var enableSummarization: Bool?
    public var lastSyncDate: Date?
    public var lastSyncResult: String?

    public init(moodleBaseURL: String, icalURL: String, excludedCourses: [String]? = nil, enableSummarization: Bool? = nil, lastSyncDate: Date? = nil, lastSyncResult: String? = nil) {
        self.moodleBaseURL = moodleBaseURL
        self.icalURL = icalURL
        self.excludedCourses = excludedCourses
        self.enableSummarization = enableSummarization
        self.lastSyncDate = lastSyncDate
        self.lastSyncResult = lastSyncResult
    }

    public static let configDirectory: URL = {
        #if os(iOS)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("MoodleHelper")
        #else
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".moodlehelper")
        #endif
    }()

    public static let configFile: URL = {
        configDirectory.appendingPathComponent("config.json")
    }()

    public static func load() throws -> AppConfig {
        let data = try Data(contentsOf: configFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppConfig.self, from: data)
    }

    public func save() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: AppConfig.configDirectory.path) {
            try fm.createDirectory(at: AppConfig.configDirectory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        try data.write(to: AppConfig.configFile, options: .atomic)
    }
}
