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

## Tech Stack & Architecture

Cuqter follows a modern mobile development architecture pattern, separating UI, state management, and services.

- **Frontend Framework**: Flutter (Dart)
- **Backend & Database**: Firebase (Auth, Firestore, Storage, Realtime Database, Cloud Messaging, Remote Config)
- **State Management**: Provider (`MultiProvider` for global states like `ThemeProvider` and `ChatProvider`)
- **Routing**: GoRouter (Deep linking enabled via `DeepLinkService`)
- **Responsive Design**: Uses a custom `ResponsiveLayout` to dynamically switch between mobile (`NavigationScreen`) and desktop (`DesktopNavigationScreen`) views.

### Architectural Flow
1. **Presentation Layer (`lib/Screen/`)**: Contains the UI elements. Widgets react to state changes.
2. **State Layer (`lib/providers/`)**: Houses `ChangeNotifier` classes that hold app state (e.g., chat history, theme).
3. **Service Layer (`lib/services/`)**: Interfaces with external APIs, Firebase, Biometrics, and Deep linking. Abstracts the backend logic from the providers.

## Full Project Structure

```text
lib/
├── Account/                # Authentication screens (Login, Signup, Onboarding)
├── Screen/                 # Core application UI modules
│   ├── calls/              # Audio & Video call interfaces (WebRTC logic integration)
│   ├── chat/               # Messaging views, conversation lists, chat bubbles
│   ├── home/               # Main navigation (Bottom nav, Sidebar for Desktop)
│   ├── media/              # Media viewing, picking, and gallery interfaces
│   ├── profile/            # User profile management & settings
│   ├── settings/           # App configuration, security settings, AppLock
│   └── status/             # Ephemeral status update viewing and creation
├── modules/                # Core data models and entities (e.g., User Model, Message Model)
├── providers/              # State management controllers (ThemeProvider, ChatProvider)
├── resources/              # Static assets, string constants, translations
├── responsive/             # Responsive layout builders (Mobile/Desktop logic)
├── services/               # Core business logic and external integrations
│   ├── biometric_service.dart     # Handles device authentication (App Lock)
│   ├── deep_link_service.dart     # Manages URL navigation within the app
│   └── notification_service.dart  # FCM push notification handling
├── utils/                  # Shared utilities, color constants (e.g., colors.dart), helpers
├── widgets/                # Reusable, shared UI components across the app
└── main.dart               # App entry point, Firebase init, MultiProvider setup
```

## Getting Started

### Prerequisites
1. Ensure you have the [Flutter SDK](https://flutter.dev/docs/get-started/install) installed (version ^3.11.1 recommended).
2. Install a compatible IDE (VS Code, Android Studio) with Flutter extensions.

### Installation & Setup

1. **Clone this repository:**
   ```bash
   git clone https://github.com/your-username/cuqter.git
   cd cuqter
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration:**
   - Create a project on the [Firebase Console](https://console.firebase.google.com/).
   - Enable Authentication, Firestore, Storage, and Firebase Cloud Messaging.
   - Run the FlutterFire CLI to configure your project:
     ```bash
     flutterfire configure
     ```
   - This will generate the required `firebase_options.dart` file in your `lib/` directory.

4. **Run the application:**
   ```bash
   flutter run
   ```

## Background Operations & Security
- **App Lock**: Managed by the `AppLockWrapper` in `main.dart`, which monitors `AppLifecycleState` and triggers the `AppLockScreen` upon resuming from the background, leveraging `BiometricService`.
- **Background Messaging**: Cuqter handles Firebase messages in the background using an isolated `@pragma('vm:entry-point')` handler located in `main.dart`.
