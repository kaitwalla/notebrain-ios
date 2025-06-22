import SwiftUI
import CoreData

struct SettingsView: View {
    @EnvironmentObject var viewModel: InstallationConfigViewModel
    @EnvironmentObject var cloudKitSettings: CloudKitSettingsManager
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var webViewSettings: WebViewSettings
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Form {
            Section(header: Text("Site setup")) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Installation URL", text: $viewModel.installationURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    SecureField("API Token", text: $viewModel.apiToken)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    HStack {
                        Image(systemName: "icloud")
                            .foregroundColor(.blue)
                        Text("Settings sync across all devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if cloudKitSettings.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
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
            Section(header: Text("Article Display")) {
                Picker("Font Size", selection: $webViewSettings.fontSize) {
                    Text("S").tag(CGFloat(18))
                    Text("M").tag(CGFloat(24))
                    Text("L").tag(CGFloat(30))
                    Text("XL").tag(CGFloat(36))
                }
                .pickerStyle(SegmentedPickerStyle())
                Stepper(value: $webViewSettings.paragraphSpacing, in: 0.5...3.0, step: 0.1) {
                    HStack {
                        Text("Paragraph Spacing")
                        Spacer()
                        Text(String(format: "%.1f em", webViewSettings.paragraphSpacing))
                            .foregroundColor(.secondary)
                    }
                }
                Picker("Font Family", selection: $webViewSettings.fontFamily) {
                    ForEach(["-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif", "Georgia, serif", "Times New Roman, Times, serif", "Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace", "Arial, Helvetica, sans-serif", "Verdana, Geneva, sans-serif", "Tahoma, Geneva, sans-serif"], id: \ .self) { font in
                        Text(fontNameDisplay(font)).tag(font)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                Stepper(value: $webViewSettings.lineHeight, in: 1.0...2.5, step: 0.1) {
                    HStack {
                        Text("Line Height")
                        Spacer()
                        Text(String(format: "%.1f", webViewSettings.lineHeight))
                            .foregroundColor(.secondary)
                    }
                }
                ColorPicker("Text Color", selection: Binding(
                    get: { Color(hex: webViewSettings.textColor) ?? (colorScheme == .dark ? .white : .black) },
                    set: { webViewSettings.textColor = $0.toHex() ?? (colorScheme == .dark ? "#ffffff" : "#222222") }
                ))
                ColorPicker("Background Color", selection: Binding(
                    get: { Color(hex: webViewSettings.backgroundColor) ?? (colorScheme == .dark ? Color(.systemGray6) : .white) },
                    set: { webViewSettings.backgroundColor = $0.toHex() ?? (colorScheme == .dark ? "#1c1c1e" : "#fafbfc") }
                ))
                Picker("Dark Mode", selection: $webViewSettings.darkModeOption) {
                    ForEach(DarkModeOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            if let lastSync = cloudKitSettings.lastSyncDate {
                Section(header: Text("Sync Status")) {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.green)
                        Text("Last synced")
                        Spacer()
                        Text(lastSync, style: .relative)
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
            
            #if DEBUG
            Section(header: Text("Debug")) {
                Button("Test Token Saving") {
                    viewModel.testTokenSaving()
                }
                .foregroundColor(.blue)
                
                Button("Print Current State") {
                    viewModel.printCurrentState()
                }
                .foregroundColor(.blue)
                
                Button("Force Save") {
                    viewModel.forceSave()
                }
                .foregroundColor(.blue)
                
                Button("Set Test Token") {
                    viewModel.apiToken = "test_token_\(Date().timeIntervalSince1970)"
                }
                .foregroundColor(.green)
                
                Button("Verify Configuration") {
                    viewModel.verifyConfiguration()
                }
                .foregroundColor(.orange)
                
                Button("Force CloudKit Sync") {
                    cloudKitSettings.forceSave()
                }
                .foregroundColor(.purple)
                
                Button("Test CloudKit Connectivity") {
                    Task {
                        let isConnected = await cloudKitSettings.testCloudKitConnectivity()
                        print("CloudKit connectivity: \(isConnected ? "SUCCESS" : "FAILED")")
                    }
                }
                .foregroundColor(.cyan)
                
                Button("Test Settings Persistence") {
                    Task {
                        let success = await cloudKitSettings.testSettingsPersistence()
                        print("Settings persistence test: \(success ? "SUCCESS" : "FAILED")")
                    }
                }
                .foregroundColor(.mint)
            }
            #endif
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}

// MARK: - Color <-> Hex helpers
import UIKit
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        var r: Double = 0, g: Double = 0, b: Double = 0, a: Double = 1
        let length = hexSanitized.count
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    func toHex() -> String? {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format: "#%06x", rgb)
    }
}

// Helper to display a user-friendly font name
func fontNameDisplay(_ font: String) -> String {
    switch font {
    case "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif": return "System (San Francisco)"
    case "Georgia, serif": return "Georgia"
    case "Times New Roman, Times, serif": return "Times New Roman"
    case "Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace": return "Monospace (Menlo)"
    case "Arial, Helvetica, sans-serif": return "Arial"
    case "Verdana, Geneva, sans-serif": return "Verdana"
    case "Tahoma, Geneva, sans-serif": return "Tahoma"
    default: return font
    }
}