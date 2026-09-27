# Cuqter

<div align="center">
  <img src="https://readme-typing-svg.demolab.com?font=Fira+Code&size=24&duration=3000&pause=1000&color=2196F3&center=true&vCenter=true&width=600&lines=Welcome+to+Cuqter;A+Feature-rich+messaging+app;Built+with+Flutter+%26+Firebase;Cross-platform+Mobile+%26+Desktop" alt="Typing SVG" />
</div>
Cuqter is a feature-rich, cross-platform messaging and social networking application built with Flutter. It seamlessly operates across Mobile and Desktop environments, utilizing Firebase as its robust backend infrastructure.

## Key Features

- **Real-Time Chat & Messaging**: Powered by Firebase Firestore and Realtime Database for instantaneous message delivery.
- **Audio & Video Calls**: Integrated WebRTC support for high-quality audio and video communication.
- **Media Sharing**: Effortlessly share images, videos, audio recordings, and files within chats.
- **Status Updates**: Share ephemeral updates with contacts, similar to popular social platforms.
- **Responsive Layout**: Designed to provide an optimal user experience on both mobile devices and desktop screens.
- **Theme Support**: Includes dynamic theming with comprehensive Dark and Light modes.
- **Security**: Built-in App Lock feature utilizing device biometric authentication to protect user privacy.
- **Push Notifications**: Stay connected with Firebase Cloud Messaging (FCM) for background and foreground notifications.
- **Generative AI Integration**: Leverages Google Generative AI capabilities for advanced in-app experiences.
- **Deep Linking**: Easily navigate directly to specific content within the app via URLs.

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend & Database**: Firebase (Auth, Firestore, Storage, Realtime Database, Cloud Messaging, Remote Config)
- **State Management**: Provider
- **Routing**: GoRouter

## Project Structure

- `lib/Account/` - Authentication and user onboarding screens.
- `lib/Screen/` - Core application UI divided into feature modules:
  - `calls/` - Audio and video call interfaces.
  - `chat/` - Messaging views and conversation lists.
  - `home/` - Main navigation and responsive layouts.
  - `media/` - Media viewing and selection.
  - `profile/` - User profile management.
  - `settings/` - App configuration and preferences.
  - `status/` - Status update viewing and creation.
- `lib/providers/` - State management controllers (e.g., ThemeProvider, ChatProvider).
- `lib/services/` - Core services (Biometrics, Deep Linking, Notifications).
- `lib/utils/` & `lib/resources/` - Shared utilities, constants, and helper functions.

## Getting Started

1. Ensure you have the [Flutter SDK](https://flutter.dev/docs/get-started/install) installed (version ^3.11.1 recommended).
2. Clone this repository.
3. Run `flutter pub get` to install dependencies.
4. Set up Firebase for your project and configure `firebase_options.dart`.
5. Run the application using `flutter run`.
