import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hugeicons/hugeicons.dart' as huge;
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerId;
  final String roomId;
  final bool isVideoCall;

  const IncomingCallScreen({
    Key? key,
    required this.callerName,
    required this.callerId,
    required this.roomId,
    required this.isVideoCall,
  }) : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final _database = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  StreamSubscription? _incomingCallSubscription;
  bool _isActionTaken = false;

  @override
  void initState() {
    super.initState();
    
    // Play ringtone for incoming call
    if (!kIsWeb) {
      try {
        FlutterRingtonePlayer().play(
          android: AndroidSounds.ringtone,
          ios: IosSounds.glass,
          looping: true,
          volume: 0.3,
        );
      } catch (e) {
        debugPrint('Incoming ringtone error: $e');
      }
    }

    if (_auth.currentUser != null) {
      _incomingCallSubscription = _database
          .ref('incoming_calls/${_auth.currentUser!.uid}')
          .onValue
          .listen((event) {
        if (event.snapshot.value == null && mounted && !_isActionTaken) {
          // Caller hung up
          _stopRingtone();
          Navigator.pop(context);
        }
      });
    }
  }

  void _stopRingtone() {
    if (!kIsWeb) {
      try {
        FlutterRingtonePlayer().stop();
      } catch (e) {
        debugPrint('Stop ringtone error: $e');
      }
    }
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    _stopRingtone();
    super.dispose();
  }

  void _acceptCall() {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _stopRingtone();

    // Remove the incoming call node so it stops ringing for other devices
    if (_auth.currentUser != null) {
      _database.ref('incoming_calls/${_auth.currentUser!.uid}').remove();
    }
    
    if (!mounted) return;
    
    // Replace current screen with CallScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          roomId: widget.roomId,
          isVideoCall: widget.isVideoCall,
          receiverName: widget.callerName,
          receiverId: widget.callerId,
        ),
      ),
    );
  }

  void _declineCall() {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _stopRingtone();

    // Remove the incoming call node to stop ringing and notify caller
    if (_auth.currentUser != null) {
      _database.ref('incoming_calls/${_auth.currentUser!.uid}').remove();
    }
    // Remove the call room so the caller's screen closes
    _database.ref('calls/${widget.roomId}').remove();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(widget.callerId).snapshots(),
                  builder: (context, snapshot) {
                    String? profilePic;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      var data = snapshot.data!.data() as Map<String, dynamic>?;
                      profilePic = data?['profilepic'];
                    }
                    return CircleAvatar(
                      radius: 64,
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: profilePic != null && profilePic.isNotEmpty
                          ? NetworkImage(profilePic)
                          : null,
                      child: profilePic == null || profilePic.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 64,
                              color: colorScheme.onPrimaryContainer,
                            )
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Incoming ${widget.isVideoCall ? "Video" : "Voice"} Call...',
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Decline Button
                Column(
                  children: [
                    GestureDetector(
                      onTap: _declineCall,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                // Accept Button
                Column(
                  children: [
                    GestureDetector(
                      onTap: _acceptCall,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: huge.HugeIcon(
                          icon: widget.isVideoCall ? huge.HugeIcons.strokeRoundedVideo01 : huge.HugeIcons.strokeRoundedCall02,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
