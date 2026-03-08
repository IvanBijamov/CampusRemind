import Foundation
import MoodleHelperCore

@MainActor
@Observable
class SyncViewModel {
    var isSyncing = false
    var lastSyncDate: Date?
    var lastSyncResult: String?
    var errorMessage: String?

    init() {
        loadLastSync()
    }

    func loadLastSync() {
        guard let config = try? AppConfig.load() else { return }
        lastSyncDate = config.lastSyncDate
        lastSyncResult = config.lastSyncResult
    }

    func syncNow() {
        guard !isSyncing else { return }
        isSyncing = true
        errorMessage = nil

        Task {
            do {
                let config = try AppConfig.load()
                let enableSummarization = config.enableSummarization == true

                let result = try await SyncService.performSync(
                    config: config,
                    skipNetworkCheck: false,
                    networkTimeout: 30,
                    enableSummarization: enableSummarization,
                    dryRun: false,
                    verbose: false
                )

                var updatedConfig = config
                updatedConfig.lastSyncDate = Date()
                updatedConfig.lastSyncResult = result.summary
                try updatedConfig.save()

                lastSyncDate = updatedConfig.lastSyncDate
                lastSyncResult = updatedConfig.lastSyncResult
            } catch {
                errorMessage = error.localizedDescription
            }
            isSyncing = false
        }
    }

    var relativeSyncTime: String {
        guard let date = lastSyncDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
