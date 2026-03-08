import BackgroundTasks
import Foundation
import os
import MoodleHelperCore

final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    static let syncTaskIdentifier = "com.moodlehelper.sync"
    private let logger = Logger(subsystem: "com.moodlehelper", category: "BackgroundTask")

    private init() {}

    func registerTasks() {
        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.syncTaskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self.handleSync(task: processingTask)
        }
        logger.info("BGTask registration: \(registered ? "success" : "failed")")
    }

    func scheduleSync() {
        let request = BGProcessingTaskRequest(identifier: Self.syncTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background sync scheduled")
        } catch let error as BGTaskScheduler.Error {
            switch error.code {
            case .unavailable:
                logger.warning("Scheduling unavailable (expected on simulator)")
            case .tooManyPendingTaskRequests:
                logger.info("Already scheduled, skipping")
            case .notPermitted:
                logger.error("Not permitted — check Info.plist background modes")
            @unknown default:
                logger.error("Schedule error: \(error.localizedDescription)")
            }
        } catch {
            logger.error("Schedule error: \(error.localizedDescription)")
        }
    }

    private func handleSync(task: BGProcessingTask) {
        logger.info("Background sync task started")

        let syncTask = Task {
            var result: SyncResult?
            do {
                let config = try AppConfig.load()
                logger.info("Config loaded, iCal URL: \(config.icalURL.prefix(50))...")

                let enableSummarization = config.enableSummarization == true

                result = try await SyncService.performSync(
                    config: config,
                    skipNetworkCheck: true,
                    networkTimeout: 30,
                    enableSummarization: enableSummarization,
                    dryRun: false,
                    verbose: false
                )

                logger.info("Sync completed: \(result!.summary)")
            } catch {
                logger.error("Sync failed: \(error.localizedDescription)")
            }

            // Save whatever progress was made (even partial on cancellation)
            if let result {
                var config = try? AppConfig.load()
                config?.lastSyncDate = Date()
                config?.lastSyncResult = result.summary
                try? config?.save()
            }

            task.setTaskCompleted(success: result != nil && result!.errors == 0)

            // Re-schedule for next time
            self.scheduleSync()
        }

        task.expirationHandler = {
            self.logger.warning("Background sync expired by system")
            syncTask.cancel()
        }
    }
}
