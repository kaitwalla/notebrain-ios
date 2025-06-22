import SwiftUI
import WebKit

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
    @Published var useDarkMode: Bool = false {
        didSet { saveSettings() }
    }
    @Published var paragraphSpacing: CGFloat = 1.0 {
        didSet { saveSettings() }
    }
    
    private let userDefaults = UserDefaults.standard
    private let fontSizeKey = "WebViewFontSize"
    private let fontFamilyKey = "WebViewFontFamily"
    private let textColorKey = "WebViewTextColor"
    private let backgroundColorKey = "WebViewBackgroundColor"
    private let lineHeightKey = "WebViewLineHeight"
    private let useDarkModeKey = "WebViewUseDarkMode"
    private let paragraphSpacingKey = "WebViewParagraphSpacing"
    
    init() {
        loadSettings()
        // Force update to new defaults if old values are detected
        if textColor == "#222222" || backgroundColor == "#fafbfc" {
            forceUpdateToNewDefaults()
        }
    }
    
    private func loadSettings() {
        let savedFontSize = userDefaults.object(forKey: fontSizeKey) as? CGFloat
        let savedFontFamily = userDefaults.string(forKey: fontFamilyKey)
        let savedTextColor = userDefaults.string(forKey: textColorKey)
        let savedBackgroundColor = userDefaults.string(forKey: backgroundColorKey)
        let savedLineHeight = userDefaults.object(forKey: lineHeightKey) as? CGFloat
        let savedUseDarkMode = userDefaults.bool(forKey: useDarkModeKey)
        let savedParagraphSpacing = userDefaults.object(forKey: paragraphSpacingKey) as? CGFloat
        
        fontSize = savedFontSize ?? 30
        fontFamily = savedFontFamily ?? "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
        textColor = savedTextColor ?? "#000000"
        backgroundColor = savedBackgroundColor ?? "#ffffff"
        lineHeight = savedLineHeight ?? 1.7
        useDarkMode = savedUseDarkMode
        paragraphSpacing = savedParagraphSpacing ?? 1.0
    }
    
    private func saveSettings() {
        // Save each value individually
        userDefaults.set(fontSize, forKey: fontSizeKey)
        userDefaults.set(fontFamily, forKey: fontFamilyKey)
        userDefaults.set(textColor, forKey: textColorKey)
        userDefaults.set(backgroundColor, forKey: backgroundColorKey)
        userDefaults.set(lineHeight, forKey: lineHeightKey)
        userDefaults.set(useDarkMode, forKey: useDarkModeKey)
        userDefaults.set(paragraphSpacing, forKey: paragraphSpacingKey)
        
        // Force UserDefaults to save immediately
        userDefaults.synchronize()
    }
    
    // Method to reset all settings to defaults
    func resetToDefaults() {
        fontSize = 22
        fontFamily = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
        textColor = "#000000"
        backgroundColor = "#ffffff"
        lineHeight = 1.4
        useDarkMode = false
        paragraphSpacing = 1.0
    }
    
    // Method to test persistence by setting a unique value
    func testPersistence() {
        let testFontSize: CGFloat = 42
        let testTextColor = "#ff0000"
        
        fontSize = testFontSize
        textColor = testTextColor
        
        // Force a save
        userDefaults.synchronize()
    }
    
    // Method to force update to new defaults and clear old values
    func forceUpdateToNewDefaults() {
        // Clear old UserDefaults values
        userDefaults.removeObject(forKey: textColorKey)
        userDefaults.removeObject(forKey: backgroundColorKey)
        
        // Set new defaults
        textColor = "#000000"
        backgroundColor = "#ffffff"
        
        // Force save
        userDefaults.synchronize()
    }
}

struct WebView: UIViewRepresentable {
    let htmlContent: String
    @EnvironmentObject var webViewSettings: WebViewSettings
    
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
        let effectiveTextColor = webViewSettings.useDarkMode ? "#ffffff" : webViewSettings.textColor
        let effectiveBackgroundColor = webViewSettings.useDarkMode ? "#1c1c1e" : webViewSettings.backgroundColor
        
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
