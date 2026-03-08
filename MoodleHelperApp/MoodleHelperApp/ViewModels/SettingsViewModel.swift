import Foundation
import MoodleHelperCore

@MainActor
@Observable
class SettingsViewModel {
    var enableSummarization = true
    var excludedCourses: [String] = []
    var newExclusion = ""
    var errorMessage: String?

    init() {
        loadConfig()
    }

    func loadConfig() {
        guard let config = try? AppConfig.load() else { return }
        enableSummarization = config.enableSummarization ?? true
        excludedCourses = config.excludedCourses ?? []
    }

    func toggleSummarization() {
        do {
            var config = try AppConfig.load()
            config.enableSummarization = enableSummarization
            try config.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addExclusion() {
        let trimmed = newExclusion.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !excludedCourses.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            newExclusion = ""
            return
        }

        excludedCourses.append(trimmed)
        newExclusion = ""
        saveExclusions()
    }

    func removeExclusion(at offsets: IndexSet) {
        excludedCourses.remove(atOffsets: offsets)
        saveExclusions()
    }

    func reconfigure() {
        let fm = FileManager.default
        try? fm.removeItem(at: AppConfig.configFile)
    }

    private func saveExclusions() {
        do {
            var config = try AppConfig.load()
            config.excludedCourses = excludedCourses.isEmpty ? nil : excludedCourses
            try config.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
