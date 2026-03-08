import SwiftUI
import BackgroundTasks
import MoodleHelperCore

@main
struct MoodleHelperApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundTaskManager.shared.registerTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundTaskManager.shared.scheduleSync()
            }
        }
    }
}
