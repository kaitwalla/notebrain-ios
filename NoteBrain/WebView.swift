import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let htmlContent: String
    
    private var styledHTML: String {
        let css = """
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                font-size: 24px;
                color: #222;
                background: #fafbfc;
                margin: 0;
                padding: 20px;
                line-height: 1.7;
            }
            h1, h2, h3, h4, h5, h6 {
                color: #1a1a1a;
                margin-top: 1.5em;
                margin-bottom: 0.5em;
            }
            p {
                margin-bottom: 1em;
            }
            a {
                color: #007aff;
                text-decoration: none;
            }
            a:hover {
                text-decoration: underline;
            }
            img {
                max-width: 100%;
                height: auto;
                border-radius: 8px;
                margin: 1em 0;
            }
            ul, ol {
                margin-left: 1.5em;
            }
            blockquote {
                border-left: 4px solid #eee;
                margin: 1em 0;
                padding: 0.5em 1em;
                color: #555;
                background: #f9f9f9;
                border-radius: 4px;
            }
            code, pre {
                font-family: Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace;
                background: #f4f4f4;
                padding: 2px 4px;
                border-radius: 4px;
            }
        </style>
        """
        return "<html><head>\(css)</head><body>\(htmlContent)</body></html>"
    }
    
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(styledHTML, baseURL: nil)
    }
} 
