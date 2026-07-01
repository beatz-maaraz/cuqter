import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';

void setupWebLifecycle(String uid) {
  html.window.addEventListener('beforeunload', (event) {
    // Attempt to quickly mark user offline when they close the web app
    FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  });
}
