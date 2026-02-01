# Changelog

All notable changes to VoiceCapacitor will be documented in this file.

## [1.0.1] - 2025-02-01

### Added
- `fix-xcode-framework-error.sh` - One-command fix for the most common build error
- Xcode running detection in setup.sh (warns if Xcode is open during pod install)

### Improved
- setup.sh now warns about closing Xcode and provides clearer next steps
- QUICKSTART.md includes preventive steps (close Xcode, clean build)
- README.md troubleshooting section expanded with quick fix script
- docs/IOS_SETUP.md has detailed "Framework not found" solution at the top
- All documentation updated with clearer Xcode workspace instructions

### Fixed
- Addressed common "Framework not found" error that occurs when Xcode is open during setup
- Added explicit warnings about using .xcworkspace instead of .xcodeproj

## [1.0.0] - 2025-02-01

### Added
- Automated setup script (`setup.sh`) - one command to set up everything
- Setup verification script (`verify-setup.sh`) for troubleshooting
- Quick start guide (QUICKSTART.md) for absolute beginners
- Initial release of VoiceCapacitor iOS Speech Recognition template
- Core speech recognition hook (`useSpeechRecognition`)
- Support for 21 languages
- Real-time transcription with partial results
- Language selection component
- Comprehensive documentation (README.md, IOS_SETUP.md)
- MIT License
- Contributing guidelines
- Example UI component

### Features
- ✅ Native iOS speech recognition (no API costs)
- ✅ TypeScript support
- ✅ React + Vite build system
- ✅ Capacitor iOS integration
- ✅ Permission handling
- ✅ Error handling
- ✅ Clean, maintainable codebase

### Technical Details
- React 18.3.1
- Capacitor 8.0.2
- Vite 5.4.19
- TypeScript 5.8.3
- iOS 15.0+ target
- Minimal dependencies (363 packages)

### Documentation
- Automated setup script with clear output
- Quick start guide for beginners (QUICKSTART.md)
- Enhanced README with badges and visual structure
- Detailed iOS setup instructions (docs/IOS_SETUP.md)
- Expanded troubleshooting guide
- API documentation with JSDoc
- Contributing guidelines
- Setup verification script

### Fixed
- Added missing `npm run build` step to README installation instructions
- Updated README with automated setup option (reduces setup time from 10 min to 2 min)
