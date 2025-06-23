//
//  ShareViewController.swift
//  NoteBrainShareExtension
//
//  Created by Kaitlyn Concilio on 6/21/25.
//

import UIKit
import os.log

class ShareViewController: UIViewController {
    private let logger = Logger(subsystem: "kait.dev.NoteBrain", category: "ShareExtension")
    private let sharedDefaults = UserDefaults(suiteName: "group.kait.dev.NoteBrain.shareextension")
    
    private let urlLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(urlLabel)
        NSLayoutConstraint.activate([
            urlLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            urlLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            urlLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        processSharedContent()
    }
    
    private func processSharedContent() {
        guard let extensionContext = extensionContext else {
            logger.error("No extension context available")
            self.dismissExtension()
            return
        }
        
        var urlsToProcess: [String] = []
        let group = DispatchGroup()
        
        for item in extensionContext.inputItems {
            guard let inputItem = item as? NSExtensionItem else { continue }
            for attachment in inputItem.attachments ?? [] {
                if attachment.hasItemConformingToTypeIdentifier("public.url") {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: "public.url", options: nil) { (url, error) in
                        defer { group.leave() }
                        if let url = url as? URL {
                            urlsToProcess.append(url.absoluteString)
                        }
                    }
                } else if attachment.hasItemConformingToTypeIdentifier("public.plain-text") {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { (text, error) in
                        defer { group.leave() }
                        if let text = text as? String {
                            let urls = self.extractURLs(from: text)
                            urlsToProcess.append(contentsOf: urls)
                        }
                    }
                }
            }
            if let contentText = inputItem.attributedContentText?.string, !contentText.isEmpty {
                let urls = extractURLs(from: contentText)
                urlsToProcess.append(contentsOf: urls)
            }
        }
        
        group.notify(queue: .main) {
            if !urlsToProcess.isEmpty {
                self.saveURLsToSharedDefaults(urlsToProcess)
                self.urlLabel.text = "Shared URL(s):\n" + urlsToProcess.joined(separator: "\n")
            } else {
                self.urlLabel.text = "No URL found to share."
            }
            // Show the label for 2 seconds before dismissing
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.dismissExtension()
            }
        }
    }
    
    private func extractURLs(from text: String) -> [String] {
        let urlPattern = "https?://[^\\s]+"
        let regex = try? NSRegularExpression(pattern: urlPattern, options: [])
        let range = NSRange(location: 0, length: text.utf16.count)
        guard let matches = regex?.matches(in: text, options: [], range: range) else {
            return []
        }
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }
    
    private func saveURLsToSharedDefaults(_ urls: [String]) {
        guard let sharedDefaults = sharedDefaults else {
            logger.error("Could not access shared UserDefaults")
            return
        }
        var pendingURLs = sharedDefaults.array(forKey: "PendingURLs") as? [String] ?? []
        for url in urls {
            if !pendingURLs.contains(url) {
                pendingURLs.append(url)
            }
        }
        sharedDefaults.set(pendingURLs, forKey: "PendingURLs")
        sharedDefaults.synchronize()
        logger.info("Saved \(urls.count) URLs to shared UserDefaults. Total pending: \(pendingURLs.count)")
    }
    
    private func dismissExtension() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
