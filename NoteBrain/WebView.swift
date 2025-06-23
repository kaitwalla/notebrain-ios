import SwiftUI
import WebKit

@MainActor
class WebViewSettings: ObservableObject {
    @Published var fontSize: CGFloat = 30 {
        didSet { saveSettings() }
    }
    @Published var fontFamily: String = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" {
        didSet { saveSettings() }
    }
    @Published var textColor: String = "#000000" {
        didSet { saveSettings() }
    }
    @Published var backgroundColor: String = "#ffffff" {
        didSet { saveSettings() }
    }
    @Published var lineHeight: CGFloat = 1.7 {
        didSet { saveSettings() }
    }
    @Published var darkModeOption: DarkModeOption = .system {
        didSet { saveSettings() }
    }
    @Published var paragraphSpacing: CGFloat = 1.0 {
        didSet { saveSettings() }
    }
    
    private var cloudKitSettings: CloudKitSettingsManager?
    private var isInitializingFromCloudKit = false
    
    init() {
        // Load settings from UserDefaults immediately
        loadSettingsFromUserDefaults()
        
        // Defer CloudKit setup to avoid actor isolation issues during init
        Task { @MainActor in
            await setupCloudKitBindings()
            // Force update to new defaults if old values are detected
            if textColor == "#222222" || backgroundColor == "#fafbfc" {
                forceUpdateToNewDefaults()
            }
        }
    }
    
    private func loadSettingsFromUserDefaults() {
        let defaults = UserDefaults.standard
        
        // Load WebView settings from UserDefaults
        fontSize = defaults.object(forKey: "WebViewFontSize") as? CGFloat ?? CGFloat(30)
        fontFamily = defaults.string(forKey: "WebViewFontFamily") ?? "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
        textColor = defaults.string(forKey: "WebViewTextColor") ?? "#000000"
        backgroundColor = defaults.string(forKey: "WebViewBackgroundColor") ?? "#ffffff"
        lineHeight = defaults.object(forKey: "WebViewLineHeight") as? CGFloat ?? CGFloat(1.7)
        
        // Handle migration from old boolean useDarkMode to new string-based darkModeOption
        if let oldDarkModeString = defaults.string(forKey: "WebViewUseDarkMode") {
            // New format - already a string
            darkModeOption = DarkModeOption(rawValue: oldDarkModeString) ?? .system
        } else if defaults.object(forKey: "WebViewUseDarkMode") != nil {
            // Old format - boolean value exists
            let oldDarkModeBool = defaults.bool(forKey: "WebViewUseDarkMode")
            darkModeOption = oldDarkModeBool ? .dark : .light
            // Update UserDefaults to new format
            defaults.set(darkModeOption.rawValue, forKey: "WebViewUseDarkMode")
        } else {
            // No value exists, use default
            darkModeOption = .system
        }
        
        paragraphSpacing = defaults.object(forKey: "WebViewParagraphSpacing") as? CGFloat ?? CGFloat(1.0)
    }
    
    private func setupCloudKitBindings() async {
        // Get CloudKit settings manager on main actor
        cloudKitSettings = CloudKitSettingsManager.shared
        
        guard let cloudKitSettings = cloudKitSettings else { return }
        
        // Set flag to prevent saving during initial load
        isInitializingFromCloudKit = true
        
        // Bind CloudKit settings to this view model
        cloudKitSettings.$fontSize
            .assign(to: &$fontSize)
        
        cloudKitSettings.$fontFamily
            .assign(to: &$fontFamily)
        
        cloudKitSettings.$textColor
            .assign(to: &$textColor)
        
        cloudKitSettings.$backgroundColor
            .assign(to: &$backgroundColor)
        
        cloudKitSettings.$lineHeight
            .assign(to: &$lineHeight)
        
        cloudKitSettings.$darkModeOption
            .assign(to: &$darkModeOption)
        
        cloudKitSettings.$paragraphSpacing
            .assign(to: &$paragraphSpacing)
        
        // Clear flag after a short delay to allow initial values to be set
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isInitializingFromCloudKit = false
        }
    }
    
    private func loadSettings() {
        // The CloudKit settings manager handles loading automatically
        // This method is kept for backward compatibility and migration
    }
    
    private func saveSettings() {
        // Don't save during initialization from CloudKit
        guard !isInitializingFromCloudKit else { return }
        
        // Save to UserDefaults immediately for persistence
        let defaults = UserDefaults.standard
        defaults.set(fontSize, forKey: "WebViewFontSize")
        defaults.set(fontFamily, forKey: "WebViewFontFamily")
        defaults.set(textColor, forKey: "WebViewTextColor")
        defaults.set(backgroundColor, forKey: "WebViewBackgroundColor")
        defaults.set(lineHeight, forKey: "WebViewLineHeight")
        defaults.set(darkModeOption.rawValue, forKey: "WebViewUseDarkMode")
        defaults.set(paragraphSpacing, forKey: "WebViewParagraphSpacing")
        
        // Also save to CloudKit if available
        guard let cloudKitSettings = cloudKitSettings else { return }
        
        cloudKitSettings.fontSize = fontSize
        cloudKitSettings.fontFamily = fontFamily
        cloudKitSettings.textColor = textColor
        cloudKitSettings.backgroundColor = backgroundColor
        cloudKitSettings.lineHeight = lineHeight
        cloudKitSettings.darkModeOption = darkModeOption
        cloudKitSettings.paragraphSpacing = paragraphSpacing
        cloudKitSettings.saveSettings()
    }
    
    // Method to reset all settings to defaults
    func resetToDefaults() {
        fontSize = 22
        fontFamily = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
        textColor = "#000000"
        backgroundColor = "#ffffff"
        lineHeight = 1.4
        darkModeOption = .system
        paragraphSpacing = 1.0
    }
    
    // Method to test persistence by setting a unique value
    func testPersistence() {
        let testFontSize: CGFloat = 42
        let testTextColor = "#ff0000"
        
        fontSize = testFontSize
        textColor = testTextColor
        
        // Force a save
        cloudKitSettings?.forceSave()
    }
    
    // Method to force update to new defaults and clear old values
    func forceUpdateToNewDefaults() {
        // Set new defaults
        textColor = "#000000"
        backgroundColor = "#ffffff"
        
        // Force save
        cloudKitSettings?.forceSave()
    }
}

struct WebView: UIViewRepresentable {
    let htmlContent: String
    @EnvironmentObject var webViewSettings: WebViewSettings
    @Environment(\.colorScheme) private var colorScheme
    
    func makeUIView(context: Context) -> WKWebView {
        // Create a proper WKWebViewConfiguration
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Create WebView with a reasonable initial frame
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 300, height: 400), configuration: configuration)
        
        // Ensure the navigation delegate is set immediately
        webView.navigationDelegate = context.coordinator
        
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        
        // Set content compression resistance to ensure the WebView gets space
        webView.setContentCompressionResistancePriority(.required, for: .horizontal)
        webView.setContentCompressionResistancePriority(.required, for: .vertical)
        webView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        webView.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        // Make sure the WebView can expand
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Load the content immediately
        let html = generateHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    private func generateHTML() -> String {
        // Determine effective colors based on dark mode option
        let shouldUseDarkMode: Bool
        switch webViewSettings.darkModeOption {
        case .system:
            shouldUseDarkMode = colorScheme == .dark
        case .light:
            shouldUseDarkMode = false
        case .dark:
            shouldUseDarkMode = true
        }
        
        let effectiveTextColor = shouldUseDarkMode ? "#ffffff" : webViewSettings.textColor
        let effectiveBackgroundColor = shouldUseDarkMode ? "#1c1c1e" : webViewSettings.backgroundColor
        
        // Add debugging and fallback for empty content
        let contentToDisplay = htmlContent.isEmpty ? "<p>No content available</p>" : htmlContent
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    font-family: \(webViewSettings.fontFamily);
                    font-size: \(webViewSettings.fontSize)px;
                    line-height: \(webViewSettings.lineHeight);
                    color: \(effectiveTextColor);
                    background-color: \(effectiveBackgroundColor);
                    margin: 0;
                    padding: 20px;
                    -webkit-text-size-adjust: 100%;
                    -webkit-font-smoothing: antialiased;
                    -moz-osx-font-smoothing: grayscale;
                    min-height: 100vh;
                }
                p {
                    margin-bottom: \(webViewSettings.paragraphSpacing)em;
                }
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 1.5em;
                    margin-bottom: 0.5em;
                    line-height: 1.2;
                }
                img {
                    max-width: 100%;
                    height: auto;
                    display: block;
                    margin: 1em auto;
                }
                blockquote {
                    border-left: 4px solid #ccc;
                    margin: 1em 0;
                    padding-left: 1em;
                    font-style: italic;
                }
                code {
                    background-color: rgba(0, 0, 0, 0.1);
                    padding: 0.2em 0.4em;
                    border-radius: 3px;
                    font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
                }
                pre {
                    background-color: rgba(0, 0, 0, 0.1);
                    padding: 1em;
                    border-radius: 5px;
                    overflow-x: auto;
                }
                pre code {
                    background-color: transparent;
                    padding: 0;
                }
                ul, ol {
                    margin-bottom: 1em;
                }
                li {
                    margin-bottom: 0.5em;
                }
                a {
                    color: #007AFF;
                    text-decoration: none;
                }
                a:hover {
                    text-decoration: underline;
                }
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 1em 0;
                }
                th, td {
                    border: 1px solid #ccc;
                    padding: 0.5em;
                    text-align: left;
                }
                th {
                    background-color: rgba(0, 0, 0, 0.1);
                }
            </style>
        </head>
        <body>
            \(contentToDisplay)
        </body>
        </html>
        """
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, url.scheme != "file" && url.scheme != "about" {
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
            } else {
                decisionHandler(.allow)
            }
        }
    }
} 
