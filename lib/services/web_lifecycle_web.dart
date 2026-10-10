import 'package:web/web.dart' as web;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:js_interop';

void setupWebLifecycle(String uid) {
  web.window.addEventListener('beforeunload', ((web.Event event) {
    // Attempt to quickly mark user offline when they close the web app
    FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }).toJS);
}
