# Firebase Background Messaging Setup in Flutter

This guide explains the step-by-step setup instructions for creating a background message handler in a Flutter application using the `firebase_messaging` plugin.

---

## 1. Add Dependencies (`pubspec.yaml`)

Ensure the following packages are present in your `pubspec.yaml` under `dependencies`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^4.5.0
  firebase_messaging: ^16.3.0
```

Run `flutter pub get` after editing.

---

## 2. Define the Background Message Handler

The background message handler must satisfy the following strict requirements:
1. It **must be a top-level function** (meaning it is outside of any class, or a static method).
2. It **must be annotated with `@pragma('vm:entry-point')`** so the Dart compiler doesn't strip it away during tree-shaking for release builds.
3. It **must be a `Future<void>` function** accepting a `RemoteMessage` parameter.

Add this function near the top of your `lib/main.dart` or in a dedicated notifications service file:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you use Firebase services (like Firestore) inside the handler,
  // ensure Firebase is initialized within the background isolate context.
  await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");
  // Access message notification details or data payload:
  print("Title: ${message.notification?.title}");
  print("Body: ${message.notification?.body}");
  print("Data: ${message.data}");
}
```

---

## 3. Register the Handler in `main()`

Initialize `WidgetsFlutterBinding`, initialize Firebase, and register the callback using `FirebaseMessaging.onBackgroundMessage` inside your `main` method before `runApp`.

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (For Web, provide FirebaseOptions if necessary)
  await Firebase.initializeApp();

  // Register the background message handler (Skip on Web as it's handled via Service Workers)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  runApp(const MyApp());
}
```

---

## 4. Android Configuration

Configure your `AndroidManifest.xml` at `android/app/src/main/AndroidManifest.xml` to handle notification click intents.

### Update `AndroidManifest.xml`
Ensure you have the `FLUTTER_NOTIFICATION_CLICK` intent filter registered inside your `MainActivity` block:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">
    
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
    
    <!-- Intent filter to capture background notification click actions -->
    <intent-filter>
        <action android:name="FLUTTER_NOTIFICATION_CLICK" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
</activity>
```

---

## 5. iOS Configuration

To receive push notifications and handle background messages in the background/terminated states on iOS:

### 1. Enable Capabilities in Xcode
1. Open the project in Xcode using `ios/Runner.xcworkspace`.
2. Select the **Runner** project in the left navigation panel.
3. Click the **Signing & Capabilities** tab.
4. Click **`+ Capability`** in the top left:
   * Add **Push Notifications**
   * Add **Background Modes**
5. Under **Background Modes**, check the boxes for:
   * **Background fetch**
   * **Remote notifications**

### 2. Configure APNs Key in Firebase
1. Generate an **APNs Key (.p8 file)** or Push Certificates on your Apple Developer portal.
2. Upload this key to your **Firebase Console** under **Project Settings > Cloud Messaging > Apple app sharing settings**.

### 3. Update AppDelegate (`ios/Runner/AppDelegate.swift`)
Ensure Firebase is configured and user notifications delegate is registered:

```swift
import UIKit
import Flutter
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

---

## 6. Web Configuration

To support background push notifications on Flutter Web, you must load the Firebase Messaging library and define a service worker (`firebase-messaging-sw.js`).

### 1. Load Firebase Messaging SDK (`web/index.html`)
Make sure you include the `firebase-messaging-compat.js` script tag in the head of your `web/index.html` file along with the other Firebase compat SDKs:

```html
<!-- Firebase SDKs -->
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-analytics-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-auth-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-storage-compat.js"></script>
```

### 2. Create the Service Worker (`web/firebase-messaging-sw.js`)
Create a file named `firebase-messaging-sw.js` directly inside the `web` folder. This service worker runs in the background of the browser and catches push messages even when the website is closed:

```javascript
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_AUTH_DOMAIN",
  databaseURL: "YOUR_DATABASE_URL",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_STORAGE_BUCKET",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId: "YOUR_APP_ID",
  measurementId: "YOUR_MEASUREMENT_ID"
};

// Initialize Firebase App in service worker context
firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

// Background Message Handler
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message: ', payload);
  
  const notificationTitle = payload.data?.title || 'New Message';
  const notificationOptions = {
    body: payload.data?.body || '',
    icon: '/favicon.png',
    data: payload.data
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
```

---

## 7. Testing Background Messaging
* **Data-Only Messages**: For background handlers to trigger reliably on iOS, Android, and Web, send messages containing only a `data` payload without the top-level `notification` field.
* **Release Mode**: Ensure you test in `--release` mode (`flutter run --release`) to verify that tree-shaking has not stripped the `@pragma('vm:entry-point')` annotated handler.
