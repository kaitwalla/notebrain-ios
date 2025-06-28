import SwiftUI

struct ArticleViewSettingsView: View {
    @EnvironmentObject var webViewSettings: WebViewSettings
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Form {
            Section(header: Text("Text Display")) {
                Picker("Font Size", selection: $webViewSettings.fontSize) {
                    Text("S").tag(CGFloat(18))
                    Text("M").tag(CGFloat(24))
                    Text("L").tag(CGFloat(30))
                    Text("XL").tag(CGFloat(36))
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Picker("Font Family", selection: $webViewSettings.fontFamily) {
                    ForEach(["-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif", "Georgia, serif", "Times New Roman, Times, serif", "Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace", "Arial, Helvetica, sans-serif", "Verdana, Geneva, sans-serif", "Tahoma, Geneva, sans-serif"], id: \.self) { font in
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
                
                Stepper(value: $webViewSettings.paragraphSpacing, in: 0.5...3.0, step: 0.1) {
                    HStack {
                        Text("Paragraph Spacing")
                        Spacer()
                        Text(String(format: "%.1f em", webViewSettings.paragraphSpacing))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Colors")) {
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
            
            Section {
                Button("Reset to Defaults") {
                    webViewSettings.resetToDefaults()
                }
                .foregroundColor(.blue)
            }
        }
    }
}

#Preview {
    ArticleViewSettingsView()
        .environmentObject(WebViewSettings())
} 