import SwiftUI
import CoreData

struct SettingsView: View {
    @StateObject private var viewModel: InstallationConfigViewModel
    
    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: InstallationConfigViewModel(context: context))
    }
    
    var body: some View {
        Form {
            Section(header: Text("Site setup")) {
                HStack {
                    Text("Installation URL")
                    Spacer()
                    Text(viewModel.installationURL)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("API Token")
                    Spacer()
                    Text(viewModel.apiToken)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            Section(header: Text("Archive Settings")) {
                Stepper(value: $viewModel.archivedRetentionDays, in: 1...365) {
                    HStack {
                        Text("Keep archived posts for")
                        Spacer()
                        Text("\(viewModel.archivedRetentionDays) days")
                            .foregroundColor(.secondary)
                    }
                }
            }
            Section {
                Button(role: .destructive) {
                    viewModel.removeConfiguration()
                } label: {
                    Label("Remove Settings", systemImage: "trash")
                }
                .disabled(viewModel.installationURL.isEmpty && viewModel.apiToken.isEmpty)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView(context: PersistenceController.preview.container.viewContext)
} 
