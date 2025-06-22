import SwiftUI
import CoreData

struct InstallationConfigView: View {
    @EnvironmentObject var viewModel: InstallationConfigViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var showToken: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                VStack(spacing: 10) {
                    Image(systemName: "gear")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                    
                    Text("Welcome to NoteBrain")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Please configure your installation settings to get started.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 15) {
                    TextField("Installation URL", text: $viewModel.installationURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .padding(.horizontal)
                    
                    HStack {
                        if showToken {
                            TextField("API Token", text: $viewModel.apiToken)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                        } else {
                            SecureField("API Token", text: $viewModel.apiToken)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                        }
                        Button(action: { showToken.toggle() }) {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .padding(.trailing, 8)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                Button(action: {
                    // Force save the configuration and update the configured state
                    print("Continue button tapped - forcing save...")
                    viewModel.forceSave()
                    print("Force save completed - isConfigured should be: \(!viewModel.installationURL.isEmpty && !viewModel.apiToken.isEmpty)")
                }) {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.installationURL.isEmpty || viewModel.apiToken.isEmpty ? Color.gray : Color.accentColor)
                        .cornerRadius(10)
                }
                .disabled(viewModel.installationURL.isEmpty || viewModel.apiToken.isEmpty)
                
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Setup")
            .navigationBarHidden(true)
        }
    }
} 