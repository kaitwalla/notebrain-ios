#!/bin/bash

# NoteBrain Share Extension Setup Script
# This script helps set up the share extension in Xcode

echo "NoteBrain Share Extension Setup"
echo "================================"
echo ""

# Check if we're in the right directory
if [ ! -f "NoteBrain.xcodeproj/project.pbxproj" ]; then
    echo "Error: Please run this script from the NoteBrain project root directory"
    exit 1
fi

echo "✓ Found NoteBrain.xcodeproj"
echo ""

# Check if share extension files exist
if [ ! -d "NoteBrainShareExtension" ]; then
    echo "Error: NoteBrainShareExtension directory not found"
    echo "Please make sure all share extension files are in place"
    exit 1
fi

echo "✓ Found NoteBrainShareExtension directory"
echo ""

# List the files that should be present
echo "Share extension files to verify:"
echo "- NoteBrainShareExtension/ShareViewController.swift"
echo "- NoteBrainShareExtension/Info.plist"
echo "- NoteBrainShareExtension/MainInterface.storyboard"
echo "- NoteBrainShareExtension/NoteBrainShareExtension.entitlements"
echo "- NoteBrainShareExtension.xcodeproj/project.pbxproj"
echo ""

# Check if main app files were updated
echo "Main app files that should be updated:"
echo "- NoteBrain/Services/SharedURLProcessor.swift"
echo "- NoteBrain/Services/APIService.swift"
echo "- NoteBrain/Services/ArticleActionSyncManager.swift"
echo "- NoteBrain/ContentView.swift"
echo "- NoteBrain/NoteBrain.entitlements"
echo ""

echo "Next steps:"
echo "1. Open NoteBrain.xcodeproj in Xcode"
echo "2. Add a new Share Extension target:"
echo "   - File > New > Target"
echo "   - iOS > Application Extension > Share Extension"
echo "   - Product Name: NoteBrainShareExtension"
echo "   - Language: Swift"
echo "   - Embed in Application: NoteBrain"
echo ""
echo "3. Replace the generated files with the provided ones"
echo "4. Configure App Groups for both targets:"
echo "   - Add capability: App Groups"
echo "   - Group: group.kait.dev.NoteBrain.shareextension"
echo ""
echo "5. Set Bundle Identifier for share extension:"
echo "   - kait.dev.NoteBrain.shareextension"
echo ""
echo "6. Build and test on a device (not simulator)"
echo ""

echo "For detailed instructions, see SHARE_EXTENSION_SETUP.md"
echo ""

# Check if Xcode is installed
if command -v xcodebuild &> /dev/null; then
    echo "✓ Xcode command line tools found"
else
    echo "⚠ Xcode command line tools not found"
    echo "Please install Xcode from the App Store"
fi

echo ""
echo "Setup script completed!" 