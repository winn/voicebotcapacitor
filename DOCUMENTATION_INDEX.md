# VoiceCapacitor Documentation Index

Quick reference for all documentation files.

## 🚀 Getting Started

| Document | Purpose | Time | Audience |
|----------|---------|------|----------|
| **[QUICKSTART.md](QUICKSTART.md)** | Fastest way to get started | 5 min | Beginners |
| **[README.md](README.md)** | Complete documentation | 10 min | Everyone |
| **[.github/GETTING_STARTED.md](.github/GETTING_STARTED.md)** | Choose your learning path | 2 min | New users |

## 📚 Detailed Guides

| Document | Purpose | Audience |
|----------|---------|----------|
| **[docs/IOS_SETUP.md](docs/IOS_SETUP.md)** | iOS/Xcode configuration | iOS developers |
| **[CONTRIBUTING.md](CONTRIBUTING.md)** | How to contribute | Contributors |
| **[CHANGELOG.md](CHANGELOG.md)** | Version history | Everyone |

## 🛠️ Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| **`./setup.sh`** | Automated installation | First time setup |
| **`./verify-setup.sh`** | Verify installation | Troubleshooting |

## 📖 Quick Links by Task

### First Time Setup
1. Read: [QUICKSTART.md](QUICKSTART.md)
2. Run: `./setup.sh`
3. Verify: `./verify-setup.sh`

### Troubleshooting
1. Check: [README.md - Troubleshooting](README.md#troubleshooting)
2. Read: [docs/IOS_SETUP.md](docs/IOS_SETUP.md)
3. Run: `./verify-setup.sh`

### Contributing
1. Read: [CONTRIBUTING.md](CONTRIBUTING.md)
2. Follow: Code style guidelines
3. Submit: Pull request

### Using the Template
1. Review: [README.md - How to Customize](README.md#how-to-customize)
2. Study: `src/hooks/useSpeechRecognition.ts`
3. Check: `src/config/languages.ts`

## 📁 Project Structure

```
voicecapacitor/
├── README.md                      # Main documentation
├── QUICKSTART.md                  # 5-minute setup guide
├── CONTRIBUTING.md                # Contribution guidelines
├── CHANGELOG.md                   # Version history
├── LICENSE                        # MIT License
├── setup.sh                       # Automated setup script
├── verify-setup.sh                # Setup verification
├── .github/
│   └── GETTING_STARTED.md        # Path selector
├── docs/
│   └── IOS_SETUP.md              # Detailed iOS guide
└── src/
    ├── components/
    │   ├── SpeechRecognitionApp.tsx
    │   └── ui/
    ├── config/
    │   └── languages.ts
    └── hooks/
        └── useSpeechRecognition.ts
```

## 🎯 Choose Your Documentation Path

**I'm brand new:**
→ Start with [QUICKSTART.md](QUICKSTART.md)

**I want to understand everything:**
→ Read [README.md](README.md)

**I'm having iOS/Xcode issues:**
→ Check [docs/IOS_SETUP.md](docs/IOS_SETUP.md)

**I want to contribute:**
→ Follow [CONTRIBUTING.md](CONTRIBUTING.md)

**I need to verify my setup:**
→ Run `./verify-setup.sh`

---

**Updated:** 2025-02-01  
**Version:** 1.0.0
