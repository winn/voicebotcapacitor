# VoiceCapacitor 🎤

iOS Speech Recognition template built with React, TypeScript, and Capacitor.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![iOS](https://img.shields.io/badge/iOS-15%2B-blue)](https://www.apple.com/ios)
[![React](https://img.shields.io/badge/React-18.3-blue)](https://react.dev)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.8-blue)](https://www.typescriptlang.org)

> **A production-ready template for building iOS voice apps with native speech recognition. Zero API costs, 21 languages, fully typed.**

## Why VoiceCapacitor?

- 🆓 **Zero Cost** - Uses Apple's native Speech Recognition API (no cloud API fees)
- 🌍 **21 Languages** - English, Thai, Spanish, French, German, Japanese, Chinese, and more
- 🎯 **Production Ready** - Clean code, documented, tested, ready to fork and customize
- ⚡ **Fast Setup** - One command to install everything
- 📱 **Real-Time** - Live transcription with partial results as you speak
- 🔒 **Privacy** - Runs on device with Apple's secure cloud processing
- 🎨 **Customizable** - Modern React + TypeScript + Tailwind stack

## What's Included

```
✅ Core Features
   ├── 🎤 Speech recognition hook (useSpeechRecognition)
   ├── 🌐 21 language support with language selector
   ├── ⚡ Real-time transcription with partial results
   ├── 🔐 Permission handling (microphone + speech recognition)
   └── ⚠️  Error handling and user feedback

✅ Developer Experience
   ├── 📝 TypeScript with full type safety
   ├── 📚 Comprehensive documentation + JSDoc comments
   ├── 🤖 Automated setup script
   ├── ✅ Setup verification script
   └── 🧪 Clean, maintainable code structure

✅ UI Components
   ├── 🎨 Tailwind CSS styling
   ├── 🔘 Shadcn UI components (Button, Card, Select)
   ├── 📱 Responsive mobile-first design
   └── 🎭 Dark mode compatible

✅ Documentation
   ├── 📖 Quick start guide (QUICKSTART.md)
   ├── 🍎 iOS setup guide (docs/IOS_SETUP.md)
   ├── 🤝 Contributing guidelines (CONTRIBUTING.md)
   └── 📋 Changelog (CHANGELOG.md)
```

## 🚀 Quick Start (Automated)

**New to iOS development?** Check out [QUICKSTART.md](QUICKSTART.md) for a beginner-friendly guide with screenshots!

### One-Command Setup

```bash
# Clone the repo
git clone https://github.com/your-username/voicecapacitor.git
cd voicecapacitor

# Run automated setup (installs everything)
./setup.sh

# Open in Xcode
npx cap open ios

# Then: Select your iPhone, set signing, and click Play ▶️
```

That's it! The `setup.sh` script handles all installation steps automatically.

---

## 📖 Manual Installation

### Prerequisites
- Node.js 18+
- macOS with Xcode 14+
- iOS device (iOS 15+)
- CocoaPods installed

### Installation

1. Clone and install:
```bash
git clone <your-repo-url>
cd voicecapacitor
npm install
```

2. Build web assets:
```bash
npm run build
```

3. Add iOS platform (only needed for fresh setup):
```bash
npx cap add ios
```

4. Install CocoaPods dependencies:
```bash
cd ios/App
pod install
cd ../..
```

5. Sync and open in Xcode:
```bash
npx cap sync ios
npx cap open ios
```

**Optional: Verify your setup**
```bash
./verify-setup.sh
```

6. In Xcode:
   - Select your iPhone from device dropdown
   - Go to Signing & Capabilities → select your Team
   - Click Play ▶️ to build and run

**Detailed iOS setup instructions:** See [docs/IOS_SETUP.md](docs/IOS_SETUP.md)

## Project Structure

- `src/hooks/useSpeechRecognition.ts` - Core speech recognition hook
- `src/components/SpeechRecognitionApp.tsx` - Example UI
- `src/config/languages.ts` - Supported languages configuration
- `ios/App/App/Info.plist` - Contains microphone & speech permissions

## How to Customize

### Change App Name
1. Update `capacitor.config.ts`: `appName`
2. Update `ios/App/App/Info.plist`: `CFBundleDisplayName`

### Add Your Branding
- Update colors in `src/index.css`
- Modify `tailwind.config.ts`

### Build Your App
Use the `useSpeechRecognition()` hook in your own components:

```typescript
import { useSpeechRecognition } from '@/hooks/useSpeechRecognition';

function MyComponent() {
  const {
    isListening,
    transcript,
    startListening,
    stopListening,
    language,
    setLanguage
  } = useSpeechRecognition();

  // Build your UI
}
```

## Use Cases

- Voice transcription apps
- Voice-controlled chatbots (integrate with OpenAI/Claude API)
- Real-time translation
- Voice note taking
- Accessibility tools

## Important Notes

- **Free**: Uses Apple's native Speech Recognition (no API costs)
- **Requires iOS device**: Won't work in simulator
- **Internet required**: iOS speech recognition uses cloud processing
- **Recording limit**: ~1 minute per session (Apple's limitation)
- **Perfect for**: Conversational apps, short voice commands, voicebots

## Troubleshooting

### Common Issues

**❌ "Speech recognition not available"**
- Must run on **physical iOS device** (simulator not supported)
- Requires **iOS 15+**

**❌ "Permission denied"**
- On iPhone: Settings > Privacy & Security > Microphone → Enable for VoiceCapacitor
- On iPhone: Settings > Privacy & Security > Speech Recognition → Enable

**❌ "Build failed" in Xcode**
```bash
# Clean and rebuild pods
cd ios/App
pod deintegrate
pod install
cd ../..

# In Xcode: Clean Build (Shift+Command+K)
# Then rebuild
```

**❌ "Framework 'CapacitorCommunitySpeechRecognition' not found"**

**This is the most common issue!** Quick fix:
```bash
./fix-xcode-framework-error.sh
```

**Manual solution:**
1. **Close Xcode completely** (Command+Q) ← This is critical!
2. Verify pods are installed:
   ```bash
   cd ios/App && pod install && cd ../..
   ```
3. **Open the .xcworkspace** (not .xcodeproj):
   ```bash
   open ios/App/App.xcworkspace
   ```
4. In Xcode: Clean build (Shift+Command+K)
5. Build again (Command+R)

**Root cause:** Xcode must be closed when pods are installed. Always use the `.xcworkspace` file.

**❌ Setup verification**
Run the verification script to check your setup:
```bash
./verify-setup.sh
```

**Need more help?** See [docs/IOS_SETUP.md](docs/IOS_SETUP.md) for detailed troubleshooting.

## License

MIT
