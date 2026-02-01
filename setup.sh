#!/bin/bash

# VoiceCapacitor Automated Setup Script
# This script automates the entire setup process

set -e  # Exit on any error

echo "🚀 VoiceCapacitor Setup Script"
echo "================================"
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js 18+ from https://nodejs.org"
    exit 1
fi

if ! command -v pod &> /dev/null; then
    echo "❌ CocoaPods not found. Installing with Homebrew..."
    if command -v brew &> /dev/null; then
        brew install cocoapods
    else
        echo "❌ Homebrew not found. Please install CocoaPods manually:"
        echo "   sudo gem install cocoapods"
        exit 1
    fi
fi

echo "✅ Prerequisites check passed"
echo ""

# Step 1: Install npm dependencies
echo "📦 Step 1/5: Installing npm dependencies..."
npm install
echo "✅ npm dependencies installed"
echo ""

# Step 2: Build web assets
echo "🔨 Step 2/5: Building web assets..."
npm run build
echo "✅ Web assets built"
echo ""

# Step 3: Add iOS platform (only if not exists)
if [ ! -d "ios/App" ]; then
    echo "📱 Step 3/5: Adding iOS platform..."
    npx cap add ios
    echo "✅ iOS platform added"
else
    echo "✅ Step 3/5: iOS platform already exists"
fi
echo ""

# Step 4: Install CocoaPods dependencies
echo "☕ Step 4/5: Installing CocoaPods dependencies..."
cd ios/App
pod install
cd ../..
echo "✅ CocoaPods dependencies installed"
echo ""

# Step 5: Sync Capacitor
echo "🔄 Step 5/5: Syncing Capacitor..."
npx cap sync ios
echo "✅ Capacitor synced"
echo ""

# Success message
echo "🎉 Setup complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Open in Xcode:"
echo "   npx cap open ios"
echo ""
echo "2. Connect your iPhone via USB"
echo ""
echo "3. In Xcode:"
echo "   • Select your iPhone from device dropdown (top bar)"
echo "   • Go to Signing & Capabilities → select your Team"
echo "   • Click Play ▶️ (or press Command+R)"
echo ""
echo "4. On first launch, you may need to trust the developer:"
echo "   Settings > General > VPN & Device Management"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📚 Need help? Check docs/IOS_SETUP.md for detailed instructions"
echo ""
