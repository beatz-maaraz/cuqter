import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cuqter/resources/auth_method.dart';
import 'package:cuqter/services/session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SessionValidatorWrapper extends StatefulWidget {
  final Widget child;

  const SessionValidatorWrapper({super.key, required this.child});

  @override
  State<SessionValidatorWrapper> createState() =>
      _SessionValidatorWrapperState();
}

class _SessionValidatorWrapperState extends State<SessionValidatorWrapper> {
  StreamSubscription<DocumentSnapshot>? _sessionSub;

  @override
  void initState() {
    super.initState();
    _initSessionListener();
  }

  Future<void> _initSessionListener() async {
    try {
      final deviceId = await SessionService().getDeviceId();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        _sessionSub = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sessions')
            .doc(deviceId)
            .snapshots()
            .listen((doc) {
              // If the session document is deleted remotely, log out
              if (!doc.exists) {
                AuthMethod().signOut();
              }
            });
      }
    } catch (e) {
      debugPrint('Error starting session listener: $e');
    }
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
