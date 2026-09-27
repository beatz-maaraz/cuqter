import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionService {
  static const String _deviceIdKey = 'local_device_id';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? _cachedDeviceId;

  /// Retrieves or generates a unique ID for this app installation
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Records the current login session in Firestore
  Future<void> recordLoginSession(String uid) async {
    try {
      final deviceId = await getDeviceId();
      final deviceInfo = await _getDeviceMetadata();

      final sessionRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .doc(deviceId);

      final sessionDoc = await sessionRef.get();
      final isNewDevice = !sessionDoc.exists;

      final sessionData = {
        'deviceId': deviceId,
        'deviceName': deviceInfo['name'],
        'deviceOs': deviceInfo['os'],
        'lastActive': FieldValue.serverTimestamp(),
      };

      await sessionRef.set(sessionData, SetOptions(merge: true));

      if (isNewDevice) {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final alertsEnabled = userData['loginAlertsEnabled'] == true;

          if (alertsEnabled) {
            final notificationId =
                'login_alert_${deviceId}_${DateTime.now().millisecondsSinceEpoch}';
            await _firestore.collection('notifications').doc(notificationId).set({
              'notificationId': notificationId,
              'type': 'login_alert',
              'senderId': 'system',
              'senderName': 'Security Alert',
              'senderProfilePic': '',
              'receiverId': uid,
              'title': 'New Login Detected',
              'body':
                  'Your account was just logged into from a new device: ${deviceInfo['name']} (${deviceInfo['os']}).',
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to record login session: $e');
    }
  }

  /// Deletes a specific session (used for remote logout)
  Future<void> logoutDevice(String uid, String targetDeviceId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .doc(targetDeviceId)
          .delete();
    } catch (e) {
      debugPrint('Failed to delete session: $e');
    }
  }

  /// Deletes the current device's session during explicit local logout
  Future<void> removeCurrentSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final deviceId = await getDeviceId();
      await logoutDevice(user.uid, deviceId);
    } catch (e) {
      debugPrint('Failed to remove current session: $e');
    }
  }

  /// Helper to get human readable device info
  Future<Map<String, String>> _getDeviceMetadata() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String name = 'Unknown Device';
    String os = 'Unknown OS';

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        name = webInfo.browserName.name;
        os = 'Web Browser';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        name = '${androidInfo.brand} ${androidInfo.model}';
        os = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        name = iosInfo.name;
        os = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      } else if (Platform.isWindows) {
        name = 'Windows PC';
        os = 'Windows';
      } else if (Platform.isMacOS) {
        name = 'Mac';
        os = 'macOS';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    return {'name': name, 'os': os};
  }
}
