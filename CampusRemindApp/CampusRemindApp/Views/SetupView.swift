import SwiftUI

struct SetupView: View {
    @State private var viewModel = SetupViewModel()
    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Moodle Instance") {
                    TextField("Moodle URL", text: $viewModel.moodleURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section {
                    TextField("iCal Export URL", text: $viewModel.icalURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } header: {
                    Text("iCal Calendar URL")
                } footer: {
                    Text("To get this URL:\n1. Log into Moodle in your browser\n2. Go to Calendar\n3. Click 'Export calendar'\n4. Select 'All courses' and 'Events from courses'\n5. Click 'Get calendar URL' and copy it")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        viewModel.save()
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save & Continue")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.icalURL.isEmpty)
                }
            }
            .navigationTitle("Setup")
            .onChange(of: viewModel.isComplete) { _, complete in
                if complete {
                    onComplete()
                }
            }
        }
    }
}
