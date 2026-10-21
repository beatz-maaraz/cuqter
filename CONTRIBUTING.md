# Contributing to Cuqter

First off, thank you for taking the time to contribute to Cuqter! 🎉

We welcome contributions from developers of all skill levels. Whether you are fixing bugs, proposing new features, improving documentation, or adding tests, your help is appreciated.

---

## Code of Conduct

By participating in this project, you agree to abide by our code of conduct: treat everyone with respect, maintain constructive discussions, and focus on collaborative problem-solving.

---

## How Can I Contribute?

### 1. Reporting Bugs
- Search existing [Issues](https://github.com/beatz-maaraz/cuqter/issues) before opening a new one to avoid duplicates.
- Provide a clear and descriptive title.
- Include step-by-step instructions to reproduce the bug.
- Specify your device model, OS version, Flutter SDK version (`flutter --version`), and target platform (Android / iOS / Web / Desktop).
- Attach screenshots or terminal logs where applicable.

### 2. Suggesting Features
- Open an [Issue](https://github.com/beatz-maaraz/cuqter/issues) with the tag `enhancement`.
- Describe why this feature would be useful to other users.
- Outline possible implementation approaches or UI mockups.

### 3. Pull Requests
1. **Fork the repository** on GitHub.
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/<your-username>/cuqter.git
   cd cuqter
   ```
3. **Create a new feature branch**:
   ```bash
   git checkout -b feature/amazing-feature
   ```
4. **Make your changes**:
   - Follow standard Dart style conventions (`dart format .`).
   - Run static analysis to verify there are no lint or compilation errors:
     ```bash
     flutter analyze
     ```
   - Keep commits focused and provide clear, meaningful commit messages.
5. **Push to your branch**:
   ```bash
   git push origin feature/amazing-feature
   ```
6. **Open a Pull Request** against the `main` branch of `beatz-maaraz/cuqter`.

---

## Development Guidelines

- **Architecture**: Cuqter separates logic into `Screen/` (presentation), `providers/` (state management with Provider), and `services/` (backend, Firebase, WebRTC, local storage). Respect this separation when adding new code.
- **Cross-Platform Compatibility**: Always verify that your changes do not break mobile (Android/iOS) or web/desktop builds (guard platform-specific code with `kIsWeb` or conditional imports).
- **Security**: Never commit API keys, personal credentials, or secrets in your pull request.

---

## Questions or Help?

Feel free to open a discussion or issue on GitHub. Happy coding!
