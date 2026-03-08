import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var showReconfigureAlert = false
    var onReconfigure: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("AI Summarization") {
                    Toggle("Summarize Descriptions", isOn: $viewModel.enableSummarization)
                        .onChange(of: viewModel.enableSummarization) { _, _ in
                            viewModel.toggleSummarization()
                        }
                }

                Section {
                    ForEach(viewModel.excludedCourses, id: \.self) { course in
                        Text(course)
                    }
                    .onDelete { offsets in
                        viewModel.removeExclusion(at: offsets)
                    }

                    HStack {
                        TextField("Course name", text: $viewModel.newExclusion)
                        Button("Add") {
                            viewModel.addExclusion()
                        }
                        .disabled(viewModel.newExclusion.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Excluded Courses")
                } footer: {
                    Text("Courses matching these substrings will be skipped during sync.")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Reconfigure", role: .destructive) {
                        showReconfigureAlert = true
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Reconfigure?", isPresented: $showReconfigureAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reconfigure", role: .destructive) {
                    viewModel.reconfigure()
                    onReconfigure()
                }
            } message: {
                Text("This will delete your current configuration. You'll need to set up CampusRemind again.")
            }
        }
    }
}
