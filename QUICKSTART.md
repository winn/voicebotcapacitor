# Quick Start Guide - VoiceCapacitor

Get VoiceCapacitor running on your iPhone in 5 minutes!

## Prerequisites

Before you start, make sure you have:
- ✅ A Mac computer (required for iOS development)
- ✅ Xcode 14+ installed ([Download from App Store](https://apps.apple.com/app/xcode/id497799835))
- ✅ An iPhone with iOS 15+
- ✅ A USB cable to connect your iPhone

## Automatic Setup (Recommended)

### Step 1: Clone the Repository
```bash
git clone https://github.com/your-username/voicecapacitor.git
cd voicecapacitor
```

### Step 2: Run the Setup Script
```bash
./setup.sh
```

That's it! The script will:
- ✅ Install all dependencies
- ✅ Build the web assets
- ✅ Set up iOS platform
- ✅ Install CocoaPods
- ✅ Sync everything

### Step 3: Open in Xcode
```bash
npx cap open ios
```

### Step 4: Connect Your iPhone
1. Plug your iPhone into your Mac with a USB cable
2. Unlock your iPhone
3. Tap **"Trust This Computer"** on your iPhone

### Step 5: Select Your iPhone in Xcode
- Look at the top bar in Xcode (next to the ▶️ Play button)
- Click the device dropdown (might say "Any iOS Device")
- Select your iPhone from the list

### Step 6: Set Up Code Signing
1. In Xcode's left sidebar, click the blue **"App"** icon (at the very top)
2. In the main area, click **"App"** under **TARGETS**
3. Click the **"Signing & Capabilities"** tab
4. Under "Team", select your Apple ID
   - Don't see your Apple ID? Click "Add Account..." and sign in
   - A free Apple ID works fine!

### Step 7: Build and Run
- Click the **Play ▶️ button** in the top left (or press Command+R)
- Wait for the build to complete
- The app will launch on your iPhone!

### Step 8: Trust the Developer (First Time Only)
If you see "Untrusted Developer" on your iPhone:
1. Go to **Settings > General > VPN & Device Management**
2. Tap on your Apple ID
3. Tap **"Trust [Your Name]"**
4. Launch the app from Xcode again

## You're Done! 🎉

The app should now be running on your iPhone. Try it out:
1. Tap the microphone button
2. Grant microphone permission when asked
3. Speak something
4. Watch the transcript appear in real-time!

---

## Manual Setup

If you prefer to run commands manually, see [README.md](README.md) for detailed step-by-step instructions.

## Troubleshooting

### "Command not found: ./setup.sh"
Make the script executable:
```bash
chmod +x setup.sh
```

### "CocoaPods not found"
Install CocoaPods:
```bash
brew install cocoapods
```

### "Build failed" in Xcode
1. Clean build: Press **Shift+Command+K**
2. Close Xcode completely
3. Run: `cd ios/App && pod install && cd ../..`
4. Open again: `npx cap open ios`
5. Build again

### "Speech recognition not available"
- Must run on a **physical iPhone** (not simulator)
- Requires **iOS 15+**

### More Help
- Detailed iOS setup: [docs/IOS_SETUP.md](docs/IOS_SETUP.md)
- Full documentation: [README.md](README.md)
- Open an issue on GitHub

---

**Having trouble?** Run the verification script:
```bash
./verify-setup.sh
```
