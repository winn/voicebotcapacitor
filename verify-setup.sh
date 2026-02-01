#!/bin/bash

# VoiceCapacitor Setup Verification Script
# Run this after installation to verify everything is ready

echo "🔍 Verifying VoiceCapacitor Setup..."
echo ""

# Check Node.js
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    echo "✅ Node.js installed: $NODE_VERSION"
else
    echo "❌ Node.js not found. Please install Node.js 18+"
    exit 1
fi

# Check npm
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm -v)
    echo "✅ npm installed: $NPM_VERSION"
else
    echo "❌ npm not found"
    exit 1
fi

# Check CocoaPods
if command -v pod &> /dev/null; then
    POD_VERSION=$(pod --version)
    echo "✅ CocoaPods installed: $POD_VERSION"
else
    echo "⚠️  CocoaPods not found. Install with: brew install cocoapods"
fi

# Check node_modules
if [ -d "node_modules" ]; then
    PACKAGE_COUNT=$(find node_modules -maxdepth 1 -type d | wc -l)
    echo "✅ node_modules exists ($PACKAGE_COUNT packages)"
else
    echo "❌ node_modules not found. Run: npm install"
    exit 1
fi

# Check dist folder
if [ -d "dist" ]; then
    echo "✅ dist folder exists (web assets built)"
else
    echo "⚠️  dist folder not found. Run: npm run build"
fi

# Check iOS platform
if [ -d "ios/App" ]; then
    echo "✅ iOS platform exists"
else
    echo "❌ iOS platform not found. Run: npx cap add ios"
    exit 1
fi

# Check Pods
if [ -d "ios/App/Pods" ]; then
    echo "✅ CocoaPods dependencies installed"
else
    echo "⚠️  Pods not found. Run: cd ios/App && pod install"
fi

# Check workspace
if [ -f "ios/App/App.xcworkspace/contents.xcworkspacedata" ]; then
    echo "✅ Xcode workspace ready"
else
    echo "⚠️  Workspace not found. Run: cd ios/App && pod install"
fi

echo ""
echo "🎉 Setup verification complete!"
echo ""
echo "Next steps:"
echo "1. Open in Xcode: npx cap open ios"
echo "2. Select your iPhone from device dropdown"
echo "3. Go to Signing & Capabilities → select your Team"
echo "4. Click Play ▶️ to build and run"
