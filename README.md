# NoteBrain iOS App

A SwiftUI-based iOS app for managing and reading articles with CloudKit-powered settings synchronization.

## Features

- **CloudKit Settings Sync**: All app settings are automatically synchronized across all iOS devices using CloudKit
- **Cross-Device Persistence**: Settings persist between app updates and device changes
- **Automatic Migration**: Existing settings from Core Data and UserDefaults are automatically migrated to CloudKit
- **Real-time Sync**: Settings changes are automatically synced to iCloud and propagated to other devices

## CloudKit Implementation

### Architecture

The app uses a unified `CloudKitSettingsManager` that handles all settings persistence:

- **Installation Configuration**: API tokens, installation URLs, and retention settings
- **Display Settings**: Font sizes, colors, spacing, and theme preferences
- **Automatic Migration**: Seamless migration from existing Core Data and UserDefaults storage

### Key Components

1. **CloudKitSettingsManager.swift**: Central manager for all CloudKit operations
2. **Updated Core Data Model**: Enhanced with CloudKit sync capabilities
3. **Modified View Models**: Updated to use CloudKit instead of local storage
4. **CloudKit Entitlements**: Proper iCloud container configuration

### Settings Categories

#### Installation Settings
- Installation URL
- API Token
- Archived retention days

#### Display Settings
- Font size (S, M, L, XL)
- Font family (System, Georgia, Times, Monospace, etc.)
- Text color
- Background color
- Line height
- Paragraph spacing
- Dark mode toggle

### Sync Behavior

- **Automatic**: Settings are saved automatically with debouncing (0.5s delay)
- **Cross-Device**: Changes appear on all devices signed into the same iCloud account
- **Offline Support**: Settings work offline and sync when connection is restored
- **Conflict Resolution**: Uses CloudKit's built-in conflict resolution

### Migration Process

When the app starts:

1. Checks for existing CloudKit settings
2. If none exist, loads from Core Data and UserDefaults
3. Migrates all settings to CloudKit
4. Future changes are synced automatically

### Developer Notes

#### CloudKit Container
- Container ID: `iCloud.kait.dev.NoteBrain.settings`
- Record Type: `AppSettings`
- Single record per user containing all settings

#### Debug Features
In DEBUG builds, additional testing options are available:
- Test token saving
- Force CloudKit sync
- Verify configuration
- Print current state

#### Error Handling
- Graceful fallback to local storage if CloudKit is unavailable
- Comprehensive logging for debugging
- User-friendly error messages

## Setup Requirements

1. **Apple Developer Account**: Required for CloudKit container setup
2. **iCloud Capability**: Must be enabled in Xcode project
3. **CloudKit Dashboard**: Container must be configured in CloudKit Console
4. **User iCloud Sign-in**: Users must be signed into iCloud for sync to work

## Privacy & Security

- All settings are stored in the user's private CloudKit database
- API tokens are encrypted in transit and at rest
- No data is shared between users
- Settings are only accessible to the user's iCloud account

## Troubleshooting

### Common Issues

1. **Settings not syncing**: Check iCloud sign-in status
2. **Migration not working**: Verify CloudKit container configuration
3. **Sync delays**: Normal behavior, changes sync within minutes

### Debug Commands

Use the debug section in Settings to:
- Force immediate sync
- Test persistence
- Verify configuration state

## Future Enhancements

- Settings export/import functionality
- Settings versioning and rollback
- Advanced conflict resolution options
- Settings backup and restore 