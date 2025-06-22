# NoteBrain Share Extension Setup Guide

This guide explains how to set up the share extension for NoteBrain in Xcode.

## Overview

The share extension allows users to share URLs, articles, or web pages from other apps directly to NoteBrain. When a user shares content, it gets added to the action queue and will be synced with the server when the app is opened.

## Files Created

The following files have been created for the share extension:

- `NoteBrainShareExtension/ShareViewController.swift` - Main share extension view controller
- `NoteBrainShareExtension/Info.plist` - Extension configuration
- `NoteBrainShareExtension/MainInterface.storyboard` - UI for the share extension
- `NoteBrainShareExtension/NoteBrainShareExtension.entitlements` - App group entitlements
- `NoteBrainShareExtension.xcodeproj/project.pbxproj` - Xcode project configuration
- `NoteBrain/Services/SharedURLProcessor.swift` - Service to handle shared URLs in main app
- Updated `NoteBrain/Services/APIService.swift` - Added support for adding articles via URL
- Updated `NoteBrain/Services/ArticleActionSyncManager.swift` - Added support for "add" action type
- Updated `NoteBrain/ContentView.swift` - Integrated shared URL processing
- Updated `NoteBrain/NoteBrain.entitlements` - Added app group access

## Xcode Setup Instructions

### 1. Add the Share Extension Target

1. Open the NoteBrain project in Xcode
2. Go to File > New > Target
3. Select "Share Extension" under iOS > Application Extension
4. Set the following:
   - Product Name: `NoteBrainShareExtension`
   - Language: Swift
   - Project: NoteBrain
   - Embed in Application: NoteBrain
5. Click "Finish"

### 2. Replace Generated Files

Replace the generated files with the ones provided:

1. Replace `ShareViewController.swift` with the provided version
2. Replace `Info.plist` with the provided version
3. Replace `MainInterface.storyboard` with the provided version
4. Replace the entitlements file with the provided version

### 3. Configure App Groups

1. Select the main NoteBrain target
2. Go to Signing & Capabilities
3. Click "+ Capability" and add "App Groups"
4. Add the group: `group.kait.dev.NoteBrain.shareextension`

5. Select the NoteBrainShareExtension target
6. Go to Signing & Capabilities
7. Click "+ Capability" and add "App Groups"
8. Add the same group: `group.kait.dev.NoteBrain.shareextension`

### 4. Update Bundle Identifiers

1. Select the NoteBrainShareExtension target
2. Go to General settings
3. Set Bundle Identifier to: `kait.dev.NoteBrain.shareextension`
4. Make sure the Team is set correctly

### 5. Build and Test

1. Build the project (⌘+B)
2. Run the app on a device (share extensions don't work in simulator)
3. Test sharing a URL from Safari or another app

## How It Works

### Share Extension Flow

1. User shares a URL from another app
2. Share extension extracts the URL
3. URL is saved to shared UserDefaults
4. Share extension completes and dismisses

### Main App Flow

1. App checks for shared URLs when it appears
2. SharedURLProcessor processes any pending URLs
3. URLs are added to the action queue as "add" actions
4. ArticleActionSyncManager syncs the actions with the server
5. New articles appear in the inbox

### Action Queue Integration

The share extension integrates with the existing action queue system:

- URLs are added as temporary articles with "add" action type
- ArticleActionSyncManager handles the "add" action specially
- Temporary articles are deleted after successful sync
- The system works offline and syncs when connected

## Troubleshooting

### Common Issues

1. **Share extension not appearing**: Make sure you're testing on a device, not simulator
2. **App group access denied**: Verify both targets have the same app group configured
3. **URLs not processing**: Check the console logs for any errors
4. **Build errors**: Make sure all files are properly added to the target

### Debugging

- Check the console logs for both the main app and share extension
- Use the SharedURLProcessor's logging to track URL processing
- Verify UserDefaults are being shared correctly between targets

## Security Considerations

- The share extension only processes URLs, not other content types
- URLs are validated before processing
- The extension has minimal permissions and runs in a sandbox
- Shared data is cleared after processing

## Future Enhancements

Potential improvements to consider:

- Support for sharing text content with embedded URLs
- Batch processing of multiple URLs
- Custom UI for the share extension
- Support for sharing from more content types
- Background processing of shared URLs 