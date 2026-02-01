#!/bin/bash

# Fix "Framework not found" error in Xcode
# Run this if you get framework errors when building

echo "🔧 Fixing Xcode Framework Error"
echo "================================"
echo ""

# Check if Xcode is running
if pgrep -x "Xcode" > /dev/null; then
    echo "⚠️  Xcode is currently running!"
    echo ""
    echo "Please CLOSE Xcode now (Command+Q)"
    echo "Press Enter after closing Xcode..."
    read -r

    # Wait a moment for Xcode to fully close
    sleep 2

    # Check again
    if pgrep -x "Xcode" > /dev/null; then
        echo "❌ Xcode is still running. Please close it and run this script again."
        exit 1
    fi
fi

echo "✅ Xcode is closed"
echo ""

# Clean and reinstall pods
echo "🧹 Cleaning CocoaPods installation..."
cd ios/App

if [ -d "Pods" ]; then
    rm -rf Pods Podfile.lock App.xcworkspace
    echo "✅ Cleaned old pods"
fi

echo ""
echo "☕ Reinstalling CocoaPods dependencies..."
pod install

cd ../..
echo "✅ CocoaPods reinstalled"
echo ""

# Rebuild web assets and sync
echo "🔨 Rebuilding web assets..."
npm run build
echo "✅ Web assets rebuilt"
echo ""

echo "🔄 Syncing Capacitor..."
npx cap sync ios
echo "✅ Capacitor synced"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Framework error should be fixed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo ""
echo "1. Open the WORKSPACE (not .xcodeproj):"
echo "   open ios/App/App.xcworkspace"
echo ""
echo "2. In Xcode:"
echo "   • Clean build: Shift+Command+K"
echo "   • Select your iPhone from device dropdown"
echo "   • Build and run: Command+R"
echo ""
echo "If you still see errors, check docs/IOS_SETUP.md"
echo ""
