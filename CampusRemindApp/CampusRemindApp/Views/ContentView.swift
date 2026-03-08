import SwiftUI
import CampusRemindCore

struct ContentView: View {
    @State private var isConfigured = FileManager.default.fileExists(
        atPath: AppConfig.configFile.path
    )

    var body: some View {
        if isConfigured {
            TabView {
                Tab("Sync", systemImage: "arrow.triangle.2.circlepath") {
                    SyncStatusView()
                }
                Tab("Settings", systemImage: "gear") {
                    SettingsView(onReconfigure: {
                        isConfigured = false
                    })
                }
            }
        } else {
            SetupView(onComplete: {
                isConfigured = true
            })
        }
    }
}
