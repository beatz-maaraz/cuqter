import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hugeicons/hugeicons.dart' as huge;
import 'call_screen.dart';
import 'chat_screen.dart';
import '../services/message_service.dart';

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

    final currentUid = _auth.currentUser?.uid;
    if (currentUid != null) {
      _database.ref('incoming_calls/$currentUid').remove();
      // Log call as missed for receiver
      final messageService = MessageService();
      messageService.logCall(
        currentUserId: currentUid,
        peerId: widget.callerId,
        type: widget.isVideoCall ? 'video' : 'voice',
        status: 'missed',
        roomId: widget.roomId,
      );
    }
    // Remove the call room so the caller's screen closes
    _database.ref('calls/${widget.roomId}').remove();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showReplyOptionsModal(BuildContext context) {
    final TextEditingController customMessageController = TextEditingController();
    final MessageService messageService = MessageService();
    final String currentUserId = _auth.currentUser?.uid ?? '';

    final List<String> quickReplies = [
      "Can't talk right now. What's up?",
      "I'll call you right back.",
      "I'm in a meeting.",
      "Can you text me instead?",
    ];

    Future<void> sendReplyAndOpenChat(String replyText) async {
      if (replyText.trim().isEmpty) return;
      if (_isActionTaken) return;
      
      _isActionTaken = true;
      _stopRingtone();

      // Stop call & clean nodes
      if (_auth.currentUser != null) {
        _database.ref('incoming_calls/${_auth.currentUser!.uid}').remove();
        messageService.logCall(
          currentUserId: _auth.currentUser!.uid,
          peerId: widget.callerId,
          type: widget.isVideoCall ? 'video' : 'voice',
          status: 'missed',
          roomId: widget.roomId,
        );
      }
      _database.ref('calls/${widget.roomId}').remove();

      // Send text message
      if (currentUserId.isNotEmpty) {
        String chatId = widget.callerId.compareTo(currentUserId) > 0
            ? '${widget.callerId}_$currentUserId'
            : '${currentUserId}_${widget.callerId}';

        await messageService.sendMessage(
          chatId: chatId,
          senderId: currentUserId,
          receiverId: widget.callerId,
          text: replyText.trim(),
          type: 'text',
        );
      }

      if (!mounted) return;
      Navigator.pop(context); // Close bottom sheet
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            receiverId: widget.callerId,
            receiverName: widget.callerName,
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Quick Reply',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...quickReplies.map(
                (text) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => sendReplyAndOpenChat(text),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            const huge.HugeIcon(
                              icon: huge.HugeIcons.strokeRoundedMessage01,
                              color: Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: customMessageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type custom message...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (val) => sendReplyAndOpenChat(val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => sendReplyAndOpenChat(customMessageController.text),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
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
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        backgroundImage: profilePic != null && profilePic.isNotEmpty
                            ? NetworkImage(profilePic)
                            : const AssetImage('assets/icon/default_profile.png') as ImageProvider,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.callerName,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Incoming ${widget.isVideoCall ? "Video" : "Voice"} Call...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply Pill Button (sketch: [ reply ] button placed above accept/decline)
                  GestureDetector(
                    onTap: () => _showReplyOptionsModal(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          huge.HugeIcon(
                            icon: huge.HugeIcons.strokeRoundedMessage01,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Reply',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline Button
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _declineCall,
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Transform.rotate(
                                angle: 2.356, // 135 deg hangup rotation
                                child: const huge.HugeIcon(
                                  icon: huge.HugeIcons.strokeRoundedCall,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Decline',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      // Accept Button
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _acceptCall,
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: huge.HugeIcon(
                                icon: widget.isVideoCall ? huge.HugeIcons.strokeRoundedVideo01 : huge.HugeIcons.strokeRoundedCall,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
