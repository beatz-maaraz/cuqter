<div align="center">
  <img src="assets/icon/icon.png" width="120" height="120" alt="Cuqter Logo" style="border-radius: 28px;" />
  <h1>Cuqter</h1>
  <p><strong>A Modern, Cross-Platform Real-Time Messaging, WebRTC Calling & AI-Powered Social Platform</strong></p>

  <p>
    <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter" /></a>
    <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart" /></a>
    <a href="https://firebase.google.com"><img src="https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20FCM-FFCA28?logo=firebase&logoColor=black" alt="Firebase" /></a>
    <a href="https://webrtc.org"><img src="https://img.shields.io/badge/WebRTC-P2P%20Voice%20%26%20Video-333333?logo=webrtc&logoColor=white" alt="WebRTC" /></a>
    <a href="https://ai.google.dev"><img src="https://img.shields.io/badge/AI-Google%20Gemini-8E75C2?logo=google&logoColor=white" alt="Google Gemini" /></a>
    <a href="https://beatz-maaraz.github.io/cuqter.xz/"><img src="https://img.shields.io/badge/Demo-Live%20Web%20App-00C853?logo=googlechrome&logoColor=white" alt="Live Demo" /></a>
    <a href="https://github.com/beatz-maaraz/cuqter/actions/workflows/firebase-hosting-merge.yml"><img src="https://github.com/beatz-maaraz/cuqter/actions/workflows/firebase-hosting-merge.yml/badge.svg" alt="CI/CD Deploy" /></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License" /></a>
  </p>

  <p>
    <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-4CAF50?style=flat-square" alt="Supported Platforms" />
    <a href="CONTRIBUTING.md"><img src="https://img.shields.io/badge/PRs-Welcome-brightgreen.svg?style=flat-square" alt="PRs Welcome" /></a>
  </p>

  <img src="https://readme-typing-svg.demolab.com?font=Fira+Code&size=20&duration=2800&pause=1000&color=2196F3&center=true&vCenter=true&width=620&lines=Real-Time+Chat+%26+Reactions;Peer-to-Peer+WebRTC+Audio+%26+Video+Calls;Integrated+Google+Gemini+AI+Assistant;24h+Ephemeral+Status+Updates;Glassmorphic+UI+for+Mobile%2C+Web+%26+Desktop" alt="Cuqter Feature Typing" />
</div>

---

## 📖 Overview

**Cuqter** is an open-source, full-featured messaging, audio/video calling, and social networking application built from the ground up with **Flutter** and **Dart**. Designed with a modern glassmorphic aesthetic, Cuqter delivers a fluid, responsive user experience across **Mobile (Android & iOS)**, **Web**, and **Desktop (Windows, macOS & Linux)** environments.

Under the hood, Cuqter combines **Firebase** for low-latency message streaming, authentication, and push notifications, **WebRTC** for peer-to-peer encrypted audio and video calling, **Cloudinary** for non-blocking media storage, and **Google Gemini 1.5 Pro** for integrated conversational AI.

> [!TIP]
> 🌐 **Try the Live Web App**: [https://beatz-maaraz.github.io/cuqter.xz/](https://beatz-maaraz.github.io/cuqter.xz/)  
> Production web builds are continuously compiled and deployed to the [`cuqter.xz`](https://github.com/beatz-maaraz/cuqter.xz) GitHub Pages repository on every merge/push to `master`.

---

## ✨ Key Features

### 💬 Real-Time Messaging & Chat
* **Instant Delivery**: Powered by Cloud Firestore and Firebase Realtime Database for sub-second messaging.
* **Floating Message Actions**: Long-press any message for an intuitive context menu supporting emoji reactions (`❤️`, `👍`, `🔥`, `😂`, `😮`, `😢`), replies, message forwarding, pin, and delete.
* **Rich Media Sharing**:
  * Photos, animated GIFs, and high-definition videos.
  * Audio voice notes with inline streaming player and waveform feedback.
  * Documents (PDF, DOCX, XLSX, etc.) with in-app preview and direct browser download on Web.
  * Real-time GPS location sharing with direct Google Maps navigation.
* **Typing Indicators & Read Receipts**: Live presence tracking, last-seen timestamps, and blue double-check delivery states.
* **Chat Personalization**: Custom chat wallpapers, mute notifications, and message search.

### 📞 WebRTC Audio & Video Calling
* **Peer-to-Peer Connection**: High-definition, low-latency voice and video calls powered by `flutter_webrtc`.
* **CallKit Integration**: OS-level incoming call screens for mobile devices using `flutter_callkit_incoming`.
* **Real-Time Signaling**: Effortless handshake negotiation leveraging Firebase Realtime Database.
* **In-Call Controls**: Flip camera, mute microphone, toggle speaker, and floating picture-in-picture mode.

### 🤖 Gemini AI Chatbot
* **AI Conversations**: Chat directly with an intelligent virtual assistant powered by Google's `google_generative_ai` (Gemini 1.5 Pro).
* **Multilingual & Productive**: Ask questions, draft messages, summarize content, and brainstorm directly inside the app.

### 📸 Ephemeral Status & Stories
* **24-Hour Stories**: Share photos, videos, and captions that automatically expire after 24 hours.
* **Rich Story Viewer**: Segmented progress bars, gesture pauses, and reply-to-status integration.

### 🔒 Security, Privacy & Biometrics
* **Biometric App Lock**: Secure your chats using device fingerprint or FaceID via `local_auth`.
* **Active Session Management**: View all active web and mobile sessions; revoke unrecognized sessions with one tap.
* **Safety Controls**: Block unwanted contacts and submit in-app issue reports.
* **QR Profile Exchange**: Instant contact addition by scanning QR codes via `mobile_scanner` and `pretty_qr_code`.

### 🎨 Glassmorphic UI & Adaptive Architecture
* **Theme Engine**: Curated Dark (slate accents) and Light themes powered by Provider.
* **Adaptive Navigation**: Ergonomic bottom navigation on mobile devices; master-detail responsive sidebar layout on tablet, web, and desktop screens.

---

## 📱 Screenshots & Previews

<div align="center">
  <table>
    <tr>
      <td align="center"><b>Authentication & Onboarding</b></td>
      <td align="center"><b>Real-Time Chat & Actions</b></td>
      <td align="center"><b>WebRTC Video Calling</b></td>
    </tr>
    <tr>
      <td><img src="assets/icon/branding.png" width="240" alt="Auth Flow" /></td>
      <td><img src="assets/icon/branding.png" width="240" alt="Chat Room" /></td>
      <td><img src="assets/icon/branding.png" width="240" alt="Video Call" /></td>
    </tr>
    <tr>
      <td align="center"><b>Status / Stories</b></td>
      <td align="center"><b>AI Assistant (Gemini)</b></td>
      <td align="center"><b>Responsive Web & Desktop</b></td>
    </tr>
    <tr>
      <td><img src="assets/icon/branding.png" width="240" alt="Status Stories" /></td>
      <td><img src="assets/icon/branding.png" width="240" alt="AI Chatbot" /></td>
      <td><img src="assets/icon/branding.png" width="240" alt="Desktop Layout" /></td>
    </tr>
  </table>
  <p><i>Note: Replace preview placeholders with actual captured screenshots in <code>assets/screenshots/</code>.</i></p>
</div>

---

## 🛠️ Technology Stack

| Layer | Technologies |
| :--- | :--- |
| **Framework** | [Flutter](https://flutter.dev/) (v3.11+ SDK) |
| **Language** | [Dart](https://dart.dev/) (v3.x) |
| **Authentication** | [Firebase Auth](https://firebase.google.com/products/auth), Google Sign-In |
| **Database & Cache** | [Cloud Firestore](https://firebase.google.com/products/firestore), [Firebase Realtime Database](https://firebase.google.com/products/realtime-database) |
| **P2P Calling** | [Flutter WebRTC](https://pub.dev/packages/flutter_webrtc), [CallKit Incoming](https://pub.dev/packages/flutter_callkit_incoming) |
| **Cloud Storage** | [Cloudinary](https://cloudinary.com/), [Firebase Storage](https://firebase.google.com/products/storage) |
| **Artificial Intelligence** | [Google Generative AI](https://pub.dev/packages/google_generative_ai) (Gemini 1.5 Pro) |
| **State Management** | [Provider](https://pub.dev/packages/provider) |
| **Navigation** | [GoRouter](https://pub.dev/packages/go_router) |
| **Push Notifications** | [Firebase Cloud Messaging (FCM)](https://firebase.google.com/products/cloud-messaging), [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications) |
| **Hardware & Sensors** | Camera, Geolocator, Local Auth (Biometrics), Mobile Scanner |

---

## 📂 Architecture & Directory Structure

Cuqter follows a layered architectural pattern for scalability and testability:

```text
cuqter/
├── lib/
│   ├── Account/             # Authentication & multi-step onboarding wizard
│   │   ├── login.dart       # Glassmorphic login with Google & email sign-in
│   │   ├── signup.dart      # 3-step setup (Credentials, Username, Avatar)
│   │   └── forgot_password.dart
│   ├── Screen/              # UI presentation screens
│   │   ├── calls/           # WebRTC audio/video call room & call history
│   │   ├── chat/            # Chat room, AI assistant (chatai.dart), media menus
│   │   ├── home/            # Bottom navigation bar & desktop master-detail navigation
│   │   ├── media/           # Full-screen media viewer, in-app camera, video player
│   │   ├── profile/         # User profile, edit profile, contact list, QR scanner
│   │   ├── settings/        # App Lock, active sessions, storage, network usage
│   │   └── status/          # 24-hour status creator and story viewer
│   ├── modules/             # Data models (User, Message, Status, Wallpaper)
│   ├── providers/           # State management controllers (ThemeProvider, ChatProvider)
│   ├── responsive/          # Responsive layout wrappers (Mobile / Tablet / Desktop)
│   ├── services/            # Core business logic, APIs, and background managers
│   │   ├── biometric_service.dart     # Device fingerprint/FaceID AppLock
│   │   ├── cloudinary_service.dart    # Media upload and deletion pipeline
│   │   ├── deep_link_service.dart     # App Links & universal URL handling
│   │   ├── notification_service.dart  # Foreground/background push notifications
│   │   ├── signaling_service.dart     # WebRTC signaling negotiation
│   │   ├── web_lifecycle.dart         # Web browser lifecycle & file download service
│   │   └── session_service.dart       # Device tracking & multi-device signout
│   ├── utils/               # App configuration, theme tokens, helpers
│   ├── widgets/             # Reusable UI components across the application
│   ├── firebase_options.dart # Generated Firebase configuration
│   └── main.dart            # App entry point, MultiProvider setup, background isolate
```

---

## 🚀 Getting Started

### Prerequisites

* [Flutter SDK](https://flutter.dev/docs/get-started/install) (`^3.11.1` or newer)
* [Dart SDK](https://dart.dev/get-dart) (`^3.0.0`)
* A target device or emulator (Android Studio emulator, physical device, or Chrome browser)
* Accounts on [Firebase](https://firebase.google.com/) and [Cloudinary](https://cloudinary.com/)

---

### Step 1: Clone the Repository

```bash
git clone https://github.com/beatz-maaraz/cuqter.git
cd cuqter
```

---

### Step 2: Install Dependencies

```bash
flutter pub get
```

---

### Step 3: Configure Firebase

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/).
2. Enable the following services in your Firebase project:
   - **Authentication** (Email/Password and Google Provider)
   - **Cloud Firestore**
   - **Firebase Realtime Database** (used for WebRTC call signaling)
   - **Firebase Storage**
   - **Firebase Cloud Messaging (FCM)**
3. Install and run the FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
4. This command will update `lib/firebase_options.dart` and register platform configurations for Android, iOS, and Web.
5. *(Android only)* Ensure `android/app/google-services.json` is placed in `android/app/`.

---

### Step 4: Configure Cloudinary Media Storage

Cuqter uses Cloudinary for fast media, voice notes, and document delivery.

1. Create a free account at [Cloudinary](https://cloudinary.com/).
2. Navigate to your **Cloudinary Dashboard** and create an **Upload Preset**:
   - Go to **Settings** > **Upload** > **Upload Presets** > **Add Upload Preset**.
   - Set **Signing Mode** to `Unsigned`.
   - Name your preset (e.g., `cuqter_preset`).
3. Set your credentials in `lib/utils/cloudinary_config.dart`:
   ```dart
   class CloudinaryConfig {
     static const String cloudName = "YOUR_CLOUD_NAME";
     static const String apiKey = "YOUR_API_KEY";
     static const String apiSecret = "YOUR_API_SECRET";
     static const String uploadPreset = "YOUR_UPLOAD_PRESET";
   }
   ```
   *(Tip: You can also supply these via `--dart-define` for automated builds).*

---

### Step 5: Configure Google Gemini AI (Optional)

To enable the in-app AI assistant:

1. Obtain a free Gemini API key from [Google AI Studio](https://aistudio.google.com/).
2. Provide your key in `lib/providers/chat_provider.dart` or pass via environment variable:
   ```dart
   static const String _geminiApiKey = String.fromEnvironment(
     'GEMINI_API_KEY',
     defaultValue: 'YOUR_GEMINI_API_KEY_HERE',
   );
   ```

---

### Step 6: Run the App

Launch the application on your connected device or browser:

```bash
# Run on Android / iOS
flutter run

# Run on Web (Chrome)
flutter run -d chrome

# Run on Windows Desktop
flutter run -d windows
```

---

### Step 7: Web Build & Continuous Deployment (CI/CD)

Cuqter supports continuous automated deployment through GitHub Actions (`.github/workflows/firebase-hosting-merge.yml`).

#### Manual Web Builds
```bash
# Standard web build (for root hosting e.g., Firebase Hosting)
flutter build web --release

# GitHub Pages web build (serving under /cuqter.xz/ base href)
flutter build web --release --base-href "/cuqter.xz/"
```

#### Automated GitHub Actions Pipeline
Every push to `master` (or manual trigger via `workflow_dispatch`) triggers two independent parallel jobs:
1. **GitHub Pages ([cuqter.xz](https://github.com/beatz-maaraz/cuqter.xz))**:
   - Compiles web release with `--base-href "/cuqter.xz/"`.
   - Automatically pushes to [`beatz-maaraz/cuqter.xz`](https://github.com/beatz-maaraz/cuqter.xz) using the `WEB_DEPLOY_TOKEN` secret.
2. **Firebase Hosting**:
   - Compiles web release and deploys live to site `cuqterz` using `FIREBASE_SERVICE_ACCOUNT_CUQTER_2FA01`.

*(To enable automated push to cuqter.xz, configure `WEB_DEPLOY_TOKEN` in your repository secrets with a GitHub Personal Access Token granting repository write access).*

---

## 🤝 Contributing

Contributions are what make the open-source community an incredible place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

Please review our [Contribution Guidelines](CONTRIBUTING.md) before submitting a pull request.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more information.

---

## 🌟 Support & Acknowledgments

If you find this project helpful or inspiring, please give it a **⭐ Star** on [GitHub](https://github.com/beatz-maaraz/cuqter)!

* Built with [Flutter](https://flutter.dev) & [Firebase](https://firebase.google.com)
* Peer-to-peer calling powered by [WebRTC](https://webrtc.org)
* UI Icons provided by [Hugeicons](https://hugeicons.com) and [Material Symbols](https://fonts.google.com/icons)
* Maintained by [@beatz-maaraz](https://github.com/beatz-maaraz)
