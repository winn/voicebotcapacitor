# Contributing to VoiceCapacitor

Thank you for considering contributing to VoiceCapacitor! This document provides guidelines for contributing to this project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/voicecapacitor.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test thoroughly on a physical iOS device
6. Commit your changes: `git commit -m "Add: your feature description"`
7. Push to your fork: `git push origin feature/your-feature-name`
8. Open a Pull Request

## Development Setup

### Prerequisites
- Node.js 18+
- macOS with Xcode 14+
- iOS device (iOS 15+)
- CocoaPods installed

### Installation

```bash
# Install dependencies
npm install

# Add iOS platform
npx cap add ios

# Install CocoaPods
cd ios/App
pod install
cd ../..

# Sync and build
npx cap sync ios
npx cap open ios
```

## Code Style

- Use TypeScript for all new code
- Follow existing code formatting (use ESLint)
- Add JSDoc comments for public APIs
- Keep components small and focused
- Extract reusable logic into custom hooks

## Testing

- Test all changes on a physical iOS device
- Verify speech recognition works for multiple languages
- Test permission flows
- Check error handling

## Pull Request Guidelines

- Keep PRs focused on a single feature or fix
- Write clear, descriptive commit messages
- Update documentation if needed
- Add comments for complex logic
- Ensure the app builds and runs successfully

## Commit Message Format

Use clear, imperative commit messages:

- `Add: new feature description`
- `Fix: bug description`
- `Update: change description`
- `Remove: what was removed`
- `Docs: documentation changes`

## Questions?

Open an issue for:
- Bug reports
- Feature requests
- Questions about usage
- Discussion about changes

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Keep discussions professional

Thank you for contributing!
