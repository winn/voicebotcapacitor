# iOS Setup Guide

## Step 1: Install CocoaPods

**Option A - Using Homebrew (Recommended):**
```bash
brew install cocoapods
```

**Option B - Using Ruby Gems:**
```bash
sudo gem install cocoapods
```

## Step 2: Set Up iOS Project

```bash
# From project root
npx cap add ios
cd ios/App
pod install
cd ../..
```

## Step 3: Open in Xcode

**Important:** Always open the `.xcworkspace` file, NOT `.xcodeproj`

```bash
npx cap open ios
```

Or manually:
```bash
open ios/App/App.xcworkspace
```

## Step 4: Configure Code Signing

1. Click the blue "App" project in left sidebar
2. Select "App" under TARGETS
3. Go to "Signing & Capabilities" tab
4. Select your Team from dropdown
   - If no team appears, click "Add Account" and sign in with Apple ID
   - Free Apple ID works for development

## Step 5: Set Configuration Files (Important!)

1. Click blue "App" project in left sidebar
2. Select PROJECT "App" (not target)
3. Click "Info" tab
4. Under "Configurations":
   - Debug → App → Select `Pods-App.debug.xcconfig`
   - Release → App → Select `Pods-App.release.xcconfig`

## Step 6: Connect iPhone

1. Connect iPhone via USB cable
2. On iPhone: Tap "Trust This Computer"
3. Enable Developer Mode:
   - Settings > Privacy & Security > Developer Mode → ON
   - iPhone will restart

## Step 7: Build and Run

1. In Xcode, select your iPhone from device dropdown (top bar)
2. Click Play button ▶️ (or press Command+R)
3. Wait for build to complete
4. App will install and launch on your iPhone

## Troubleshooting

### ❌ "Framework 'CapacitorCommunitySpeechRecognition' not found"

**This is the most common issue!** It happens when Xcode can't find the CocoaPods frameworks.

**Solution:**
1. **Close Xcode completely** (Command+Q) - This is critical!
2. **Verify pods are installed:**
   ```bash
   cd ios/App
   pod install
   cd ../..
   ```
3. **Open the WORKSPACE (not .xcodeproj):**
   ```bash
   open ios/App/App.xcworkspace
   ```
   **Important:** Always use `.xcworkspace`, never `.xcodeproj`

4. **In Xcode, verify configuration:**
   - Click blue "App" project → Select PROJECT "App" → Info tab
   - Under "Configurations", verify:
     - Debug → App → `Pods-App.debug`
     - Release → App → `Pods-App.release`

5. **Clean and rebuild:**
   - Press **Shift+Command+K** (Clean Build Folder)
   - Press **Command+B** (Build)

**Why this happens:**
- Xcode needs to be closed when pods are installed
- The `.xcworkspace` must be used (it includes the Pods project)
- Build cache can cause issues if Xcode was open during `pod install`

---

### "Podfile.lock: No such file or directory"
```bash
cd ios/App
pod install
```

### "The sandbox is not in sync with the Podfile.lock"
1. In Xcode: Select App project > Info tab
2. Set Debug/Release configs to Pods-App.*.xcconfig (see Step 5)
3. Clean: Shift+Command+K
4. Rebuild

### Keychain password prompts
- Enter your Mac login password
- Click "Always Allow"

### Permission denied on device
- Settings > VoiceCapacitor > Enable Microphone
- Settings > Privacy > Speech Recognition > Enable

### Build failed with code signing error
- Xcode > Signing & Capabilities > Select your Team
- Change Bundle Identifier if needed (must be unique)
