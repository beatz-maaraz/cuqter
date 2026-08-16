import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cuqter/Screen/chat/chat_screen.dart';

/// Handles incoming cuqter.com/<username> deep links and navigates
/// to the ChatScreen for the matched user.
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Call once from [main.dart] after the app is ready.
  void init(GlobalKey<NavigatorState> navigatorKey) {
    // Handle link that cold-started the app
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri, navigatorKey);
    });

    // Handle links while the app is already running
    _sub = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri, navigatorKey);
    });
  }

  void dispose() {
    _sub?.cancel();
  }

  Future<void> _handleUri(
      Uri uri, GlobalKey<NavigatorState> navigatorKey) async {
    // Only handle cuqter.com links
    if (uri.host != 'cuqter.com') return;

    // Extract slug: cuqter.com/<username>  or  cuqter.com/user/<uid>
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    String rawSlug = segments.last;
    // If the path is /user/<uid> use the uid segment
    if (segments.length >= 2 && segments.first == 'user') {
      rawSlug = segments[1];
    }

    if (rawSlug.isEmpty) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    try {
      String? targetUid;

      // Try direct UID lookup first
      final directDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(rawSlug)
          .get();

      if (directDoc.exists) {
        targetUid = rawSlug;
      } else {
        // Fall back to username field lookup
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: rawSlug)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) targetUid = q.docs.first.id;
      }

      if (targetUid == null || targetUid == currentUid) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .get();

      if (!userDoc.exists) return;

      final data = userDoc.data()!;
      final name = data['name'] ?? 'User';
      final profilePic = data['profilepic'] ?? '';
      final isOnline = data['isOnline'] as bool?;

      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            receiverId: targetUid!,
            receiverName: name,
            receiverProfilePic: profilePic,
            receiverIsOnline: isOnline,
          ),
        ),
      );
    } catch (_) {}
  }
}
