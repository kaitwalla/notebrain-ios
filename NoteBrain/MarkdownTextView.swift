import SwiftUI

struct MarkdownTextView: View {
    let markdown: String
    @EnvironmentObject var webViewSettings: WebViewSettings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let processedMarkdown = MarkdownTextView.convertLineBreaksToParagraphs(in: markdown)
        if let attributed = try? AttributedString(markdown: processedMarkdown) {
            // Apply appearance settings
            Text(attributed)
                .font(.system(size: webViewSettings.fontSize, weight: .regular, design: .default))
                .foregroundColor(Color(hex: effectiveTextColor))
                .lineSpacing((webViewSettings.lineHeight - 1) * webViewSettings.fontSize)
                .padding(20)
                .background(Color(hex: effectiveBackgroundColor))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(markdown)
                .foregroundColor(.secondary)
        }
    }

    // Converts single line breaks to paragraph breaks (double line breaks)
    static func convertLineBreaksToParagraphs(in markdown: String) -> String {
        // Replace single newlines that are not already part of a double newline (paragraph)
        // This is a simple approach and may need refinement for edge cases (e.g., lists, code blocks)
        let lines = markdown.components(separatedBy: "\n")
        var result: [String] = []
        var buffer: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !buffer.isEmpty {
                    result.append(buffer.joined(separator: " "))
                    buffer.removeAll()
                }
                result.append("") // Paragraph break
            } else {
                buffer.append(line)
            }
        }
        if !buffer.isEmpty {
            result.append(buffer.joined(separator: " "))
        }
        return result.joined(separator: "\n\n")
    }

    private var effectiveTextColor: String {
        switch webViewSettings.darkModeOption {
        case .system:
            return colorScheme == .dark ? "#ffffff" : webViewSettings.textColor
        case .light:
            return webViewSettings.textColor
        case .dark:
            return "#ffffff"
        }
    }
    private var effectiveBackgroundColor: String {
        switch webViewSettings.darkModeOption {
        case .system:
            return colorScheme == .dark ? "#000000" : webViewSettings.backgroundColor
        case .light:
            return webViewSettings.backgroundColor
        case .dark:
            return "#000000"
        }
    }
} 