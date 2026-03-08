import SwiftUI

struct SyncStatusView: View {
    @State private var viewModel = SyncViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Last Sync") {
                    LabeledContent("Time", value: viewModel.relativeSyncTime)
                    if let result = viewModel.lastSyncResult {
                        LabeledContent("Result", value: result)
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        viewModel.syncNow()
                    } label: {
                        HStack {
                            Text("Sync Now")
                            Spacer()
                            if viewModel.isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isSyncing)
                }
            }
            .navigationTitle("MoodleHelper")
            .refreshable {
                viewModel.syncNow()
            }
        }
    }
}
