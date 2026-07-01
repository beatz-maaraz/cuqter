import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cuqter/main.dart';
import 'package:cuqter/Screen/chat_screen.dart';

/// Top-level background action handler for notification taps (must be a top-level or static function)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  if (response.actionId == 'reply_action' && response.input != null && response.input!.isNotEmpty) {
    final text = response.input!;
    try {
      final Map<String, dynamic> data = jsonDecode(response.payload!);
      final chatId = data['chatId'];
      final originalSenderId = data['senderId'];
      final originalReceiverId = data['receiverId'];

      // When replying from notification, the sender of the reply is the original receiver (us)
      // and the receiver of the reply is the original sender.
      final senderId = originalReceiverId;
      final receiverId = originalSenderId;

      WidgetsFlutterBinding.ensureInitialized();
      if (Firebase.apps.isEmpty) {
        if (kIsWeb) {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: "AIzaSyBOvtzNFHyoCeq8pZZ_JdaG0dmd4a1DPHs",
              authDomain: "cuqter-2fa01.firebaseapp.com",
              databaseURL: "https://cuqter-2fa01-default-rtdb.firebaseio.com",
              projectId: "cuqter-2fa01",
              storageBucket: "cuqter-2fa01.firebasestorage.app",
              messagingSenderId: "921725231252",
              appId: "1:921725231252:web:a2dbfa0c97694cbf299481",
              measurementId: "G-5TKLZ0RS2M",
            ),
          );
        } else {
          await Firebase.initializeApp();
        }
      }

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': senderId,
        'receiverId': receiverId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'text',
      });

      // Ensure both users are in each other's contacts so they appear on the homepage
      await FirebaseFirestore.instance.collection('users').doc(senderId).set({
        'contacts': FieldValue.arrayUnion([receiverId])
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('users').doc(receiverId).set({
        'contacts': FieldValue.arrayUnion([senderId])
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('Background inline reply sent successfully: $text');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling background inline reply: $e');
      }
    }
  }
}

Future<Uint8List?> _getProfilePicBytes(String? pathOrUrl) async {
  if (pathOrUrl == null || pathOrUrl.isEmpty) return null;
  try {
    if (pathOrUrl.startsWith('http')) {
      final HttpClient client = HttpClient();
      final HttpClientRequest request = await client.getUrl(Uri.parse(pathOrUrl));
      final HttpClientResponse response = await request.close();
      if (response.statusCode == 200) {
        final List<int> bytes = await response.fold<List<int>>([], (previous, element) => previous..addAll(element));
        return Uint8List.fromList(bytes);
      }
    } else if (pathOrUrl.startsWith('assets/')) {
      try {
        final byteData = await rootBundle.load(pathOrUrl);
        return byteData.buffer.asUint8List();
      } catch (e) {
        if (kDebugMode) {
          print('Error loading asset in isolate: $e');
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error getting profile pic bytes: $e');
    }
  }
  return null;
}

@pragma('vm:entry-point')
Future<void> showMessageNotification(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (kIsWeb) {
      if (kDebugMode) {
        print('Web message received: ${message.notification?.title} - ${message.notification?.body}');
      }
      return;
    }
    await Firebase.initializeApp();

    final data = message.data;

    // Resolve title and body from the notification block if available, fallback to data payload
    final String title = message.notification?.title ?? data['title'] ?? 'New Message';
    String body = message.notification?.body ?? data['body'] ?? '';
    final String? messageType = data['type'];

    // Client-side fallback: if body looks like a URL or is empty, show a friendly type label
    if (messageType != null && messageType != 'text') {
      switch (messageType) {
        case 'image':    body = '📷 Photo'; break;
        case 'video':    body = '🎥 Video'; break;
        case 'audio':    body = '🎵 Audio'; break;
        case 'document': body = '📄 Document'; break;
        case 'location': body = '📍 Shared a location'; break;
      }
    } else if (body.startsWith('http')) {
      // Legacy: body is a raw URL, convert based on URL pattern
      final lower = body.toLowerCase();
      if (lower.contains('/image/upload') || lower.endsWith('.jpg') || lower.endsWith('.png') || lower.endsWith('.jpeg')) {
        body = '📷 Photo';
      } else if (lower.contains('/video/upload') || lower.endsWith('.mp4') || lower.endsWith('.mov')) {
        body = '🎥 Video';
      } else if (lower.endsWith('.mp3') || lower.endsWith('.m4a') || lower.endsWith('.wav')) {
        body = '🎵 Audio';
      } else if (lower.contains('/raw/upload') || lower.endsWith('.pdf') || lower.endsWith('.doc')) {
        body = '📄 Document';
      } else {
        body = '📎 Shared a file';
      }
    } else {
      // Strip any pipe-separated filesize from text messages
      body = body.split('|').first;
    }
    final chatId = data['chatId'];
    final senderId = data['senderId'];
    final receiverId = data['receiverId'];

    // 1. Fetch sender's profile picture (use payload directly, fallback to Firestore)
    String? profilePicUrl = data['senderProfilePic'];
    if ((profilePicUrl == null || profilePicUrl.isEmpty) && senderId != null) {
      try {
        final senderDoc = await FirebaseFirestore.instance.collection('users').doc(senderId).get();
        if (senderDoc.exists && senderDoc.data() != null) {
          profilePicUrl = senderDoc.data()!['profilepic'];
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching sender document in background: $e');
        }
      }
    }

    // 2. Download profile image bytes
    Uint8List? profilePicBytes;
    if (profilePicUrl != null && profilePicUrl.isNotEmpty) {
      profilePicBytes = await _getProfilePicBytes(profilePicUrl);
    }

    // 3. Write to temporary file for FilePathAndroidBitmap and DarwinNotificationAttachment
    String? tempFilePath;
    if (profilePicBytes != null) {
      try {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/notification_profile_${senderId ?? 'user'}.jpg');
        await file.writeAsBytes(profilePicBytes);
        tempFilePath = file.path;
      } catch (e) {
        if (kDebugMode) {
          print('Error saving temp notification image: $e');
        }
      }
    }

    // 4. Configure Android Messaging Style & Person Details
    final Person senderPerson = Person(
      name: title,
      key: senderId,
      icon: profilePicBytes != null ? ByteArrayAndroidIcon(profilePicBytes) : null,
    );

    final Message messageItem = Message(
      body,
      DateTime.now(),
      senderPerson,
    );

    final MessagingStyleInformation messagingStyle = MessagingStyleInformation(
      senderPerson,
      messages: [messageItem],
    );

    // Initialize local notifications if not already done in this isolate
    await NotificationService.initializeLocalNotifications();

    // Configure Android Inline Reply Actions
    final List<AndroidNotificationAction> androidActions = [
      const AndroidNotificationAction(
        'reply_action',
        'Reply',
        inputs: [
          AndroidNotificationActionInput(
            label: 'Type your reply...',
          ),
        ],
        showsUserInterface: false,
      ),
    ];

    // Payload containing metadata to identify the thread and parties
    final payloadData = {
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'title': title,
    };

    // Present the Notification
    await NotificationService.localNotifications.show(
      id: message.messageId.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'chats_messages_channel',
          'Chat Messages',
          channelDescription: 'This channel is used for real-time chat message push notifications.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          largeIcon: tempFilePath != null ? FilePathAndroidBitmap(tempFilePath) : null,
          playSound: true,
          actions: androidActions,
          styleInformation: messagingStyle,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'chats_messages_category',
          attachments: tempFilePath != null ? [DarwinNotificationAttachment(tempFilePath)] : null,
        ),
      ),
      payload: jsonEncode(payloadData),
    );
  } catch (e) {
    if (kDebugMode) {
      print('Error displaying notification in isolate: $e');
    }
  }
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  static bool _isLocalNotificationsInitialized = false;

  static void _handleLocalNotificationClick(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(response.payload!);
        final chatId = data['chatId'];
        final senderId = data['senderId'];
        final senderName = data['title'] ?? 'Chat';

        if (chatId != null && senderId != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                receiverId: senderId,
                receiverName: senderName,
              ),
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error handling local notification click: $e');
        }
      }
    }
  }

  static Future<void> initializeLocalNotifications() async {
    if (kIsWeb) return;
    if (_isLocalNotificationsInitialized) return;

    final List<DarwinNotificationCategory> darwinCategories = [
      DarwinNotificationCategory(
        'chats_messages_category',
        actions: [
          DarwinNotificationAction.text(
            'reply_action',
            'Reply',
            buttonTitle: 'Send',
            placeholder: 'Type your reply...',
          ),
        ],
      ),
    ];

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      notificationCategories: darwinCategories,
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.actionId == 'reply_action' && response.input != null && response.input!.isNotEmpty) {
          notificationTapBackground(response);
        } else {
          _handleLocalNotificationClick(response);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Configure Android High-Importance Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'chats_messages_channel',
      'Chat Messages',
      description: 'This channel is used for real-time chat message push notifications.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    if (Platform.isAndroid) {
      await localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    _isLocalNotificationsInitialized = true;
  }

  /// Initializes permissions, retrieves tokens, and sets up message listeners.
  Future<void> initialize() async {
    // 1. Initialize local notifications for early callback registration (main isolate)
    await initializeLocalNotifications();
    // Enable foreground notification alerts (banners/sound/badge)
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Request notification permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Request Android local notification permissions explicitly on Android 13+
    if (!kIsWeb && Platform.isAndroid) {
      await localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      if (kDebugMode) {
        print('Notification permissions granted: ${settings.authorizationStatus}');
      }

      // 2. Fetch and save active device token
      await saveDeviceToken();

      // 3. Handle token refreshes in the future
      _fcm.onTokenRefresh.listen((newToken) async {
        await _updateTokenInFirestore(newToken);
      });

      // 4. Handle Foreground Messages (Fires when app is open)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Foreground message received: ${message.messageId}');
        }
        showMessageNotification(message);
      });

      // 5. Handle notification tap when app is in background but not terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('App opened from background notification: ${message.messageId}');
        }
        _handleNotificationClick(message);
      });

      // 6. Handle notification tap when app was completely terminated
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          print('App launched from terminated state via notification: ${initialMessage.messageId}');
        }
        _handleNotificationClick(initialMessage);
      }

      // 7. Handle app launch from terminated state via local notification tap
      final NotificationAppLaunchDetails? notificationAppLaunchDetails =
          await localNotifications.getNotificationAppLaunchDetails();
      if (notificationAppLaunchDetails != null &&
          notificationAppLaunchDetails.didNotificationLaunchApp) {
        final NotificationResponse? response =
            notificationAppLaunchDetails.notificationResponse;
        if (response != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleLocalNotificationClick(response);
          });
        }
      }
    } else {
      if (kDebugMode) {
        print('Notification permissions denied.');
      }
    }
  }

  /// Logic to handle app navigation/routing when a notification is clicked (not inline replied)
  void _handleNotificationClick(RemoteMessage message) {
    if (kDebugMode) {
      print('Notification clicked, data payload: ${message.data}');
    }
    // Deep link or navigate to the chat page based on message.data['chatId'] if desired
  }

  /// Fetches the active FCM Token and stores it in Firestore.
  Future<void> saveDeviceToken() async {
    try {
      String? token;
      if (!kIsWeb && Platform.isIOS) {
        token = await _fcm.getAPNSToken();
      }
      token = await _fcm.getToken();

      if (token != null) {
        await _updateTokenInFirestore(token);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
    }
  }

  /// Persists token to Firestore users collection
  Future<void> _updateTokenInFirestore(String token) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .update({'fcmToken': token});
        if (kDebugMode) {
          print('FCM Token successfully stored to Firestore: $token');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM token to Firestore: $e');
      }
    }
  }
}
