import Foundation
import MoodleHelperCore

@MainActor
@Observable
class SetupViewModel {
    var moodleURL = "https://moodle.conncoll.edu"
    var icalURL = ""
    var isSaving = false
    var errorMessage: String?
    var isComplete = false

    func save() {
        guard !icalURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "iCal URL is required."
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                let config = AppConfig(
                    moodleBaseURL: moodleURL.trimmingCharacters(in: .whitespaces),
                    icalURL: icalURL.trimmingCharacters(in: .whitespaces),
                    enableSummarization: true
                )
                try config.save()

                // Request Reminders access
                let manager = RemindersManager()
                try await manager.requestAccess()

                // Schedule background sync
                BackgroundTaskManager.shared.scheduleSync()

                isComplete = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
