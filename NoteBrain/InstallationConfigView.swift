import SwiftUI
import CoreData

struct InstallationConfigView: View {
    @StateObject private var viewModel: InstallationConfigViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: InstallationConfigViewModel(context: context))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "brain.head.profile")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.accentColor)
                
                Text("Welcome to NoteBrain")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Please enter your installation details to continue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 15) {
                    TextField("Installation URL", text: $viewModel.installationURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .padding(.horizontal)
                    
                    SecureField("API Token", text: $viewModel.apiToken)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .padding(.horizontal)
                }
                .padding(.vertical)
                
                Button(action: {
                    print("Continue button tapped")
                    viewModel.saveConfiguration()
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
            .padding()
            .navigationBarHidden(true)
        }
        .onChange(of: viewModel.isConfigured) { newValue in
            print("isConfigured changed to: \(newValue)")
        }
    }
} 