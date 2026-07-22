import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/signaling_service.dart';

class CallScreen extends StatefulWidget {
  final String? roomId;
  final bool isVideoCall;
  final String receiverName;
  final String? receiverId;
  final Function(String)? onRoomCreated;

  const CallScreen({
    Key? key,
    this.roomId,
    required this.isVideoCall,
    required this.receiverName,
    this.receiverId,
    this.onRoomCreated,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  SignalingService signaling = SignalingService();
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _isMicMuted = false;
  bool _isVideoDisabled = false;
  String? _roomId;
  
  Timer? _ringTimer;
  Timer? _callTimer;
  int _callDurationInSeconds = 0;
  bool _isConnected = false;
  bool _isHangingUp = false;
  bool _isDisposed = false; // guards against double-dispose

  @override
  void initState() {
    super.initState();
    _roomId = widget.roomId;
    
    signaling.onAddRemoteStream = ((stream) {
      _ringTimer?.cancel();
      if (!kIsWeb) {
        try {
          FlutterRingtonePlayer().stop();
        } catch (e) {
          debugPrint('Ringtone player error: $e');
        }
      }
      setState(() {
        _remoteRenderer.srcObject = stream;
        _isConnected = true;
      });
      _startCallTimer();
    });

    signaling.onCallEnded = () async {
      if (!mounted || _isHangingUp || _isDisposed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call ended')),
      );
      await _hangUp();
    };
    
    _initRenderers();
    _requestPermissionsAndStart();

    // Start playing ringback tone if we are the caller
    if (widget.roomId == null && !kIsWeb) {
      try {
        FlutterRingtonePlayer().play(
          android: AndroidSounds.ringtone,
          ios: IosSounds.glass,
          looping: true,
          volume: 0.15,
        );
      } catch (e) {
        debugPrint('Ringtone player error: $e');
      }
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _requestPermissionsAndStart() async {
    bool isGranted = false;
    
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux) {
      isGranted = true; // On web and desktop, getUserMedia will prompt natively or doesn't need explicit permission handler
    } else {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();
      isGranted = statuses[Permission.camera]!.isGranted || statuses[Permission.microphone]!.isGranted;
    }

    if (isGranted) {
      try {
        await signaling.initLocalStream(widget.isVideoCall);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera/Microphone access denied')),
          );
          Navigator.pop(context);
        }
        return;
      }
      
      _localRenderer.srcObject = signaling.localStream;
      setState(() {});

      if (_roomId != null) {
        // Join existing room
        await signaling.joinRoom(_roomId!, widget.isVideoCall);
      } else {
        // Create new room
        _roomId = await signaling.createRoom();
        if (widget.onRoomCreated != null) {
          widget.onRoomCreated!(_roomId!);
        }
        
        // Notify receiver
        if (widget.receiverId != null) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            // Fetch caller's real name from Firestore (displayName is often null)
            String callerName = currentUser.displayName ?? 'Unknown';
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .get();
              if (userDoc.exists && userDoc.data() != null) {
                callerName = userDoc.data()!['name'] ??
                    userDoc.data()!['username'] ??
                    currentUser.displayName ??
                    'Unknown';
              }
            } catch (e) {
              debugPrint('Error fetching caller name: $e');
            }

            final incomingCallRef = FirebaseDatabase.instance.ref('incoming_calls/${widget.receiverId}');
            await incomingCallRef.set({
              'roomId': _roomId,
              'callerId': currentUser.uid,
              'callerName': callerName,
              'isVideo': widget.isVideoCall,
              'timestamp': ServerValue.timestamp,
            });
            incomingCallRef.onDisconnect().remove();
          }
        }

        // Start 1 minute timer to end call if not connected
        _ringTimer = Timer(const Duration(minutes: 1), () async {
          if (!_isConnected && mounted && !_isHangingUp && !_isDisposed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Call ended: No answer')),
            );
            await _hangUp();
          }
        });

        setState(() {});
      }
    } else {
      // Handle permissions not granted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera and Microphone permissions are required')),
        );
        Navigator.pop(context);
      }
    }
  }

  /// Immediately stops all local audio/video tracks and releases mic/camera.
  /// Safe to call multiple times.
  void _releaseLocalMedia() {
    try {
      final stream = signaling.localStream;
      if (stream != null) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
      }
    } catch (e) {
      debugPrint('_releaseLocalMedia error: $e');
    }
    try {
      _localRenderer.srcObject = null;
    } catch (_) {}
    try {
      _remoteRenderer.srcObject = null;
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _ringTimer?.cancel();
    _callTimer?.cancel();
    if (!kIsWeb) {
      try { FlutterRingtonePlayer().stop(); } catch (_) {}
    }
    // Release mic/camera tracks BEFORE disposing renderers
    _releaseLocalMedia();
    try { _localRenderer.dispose(); } catch (_) {}
    try { _remoteRenderer.dispose(); } catch (_) {}
    if (!_isHangingUp) {
      // Caller cleanup
      if (widget.receiverId != null && widget.roomId == null) {
        FirebaseDatabase.instance.ref('incoming_calls/${widget.receiverId}').remove();
      }
      // Callee cleanup
      if (widget.roomId != null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          FirebaseDatabase.instance.ref('incoming_calls/${currentUser.uid}').remove();
        }
      }
      signaling.hangUp();
    }
    super.dispose();
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDurationInSeconds++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _updateCallDurationMessage() async {
    if (widget.receiverId == null || _roomId == null) return;
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;
      
      String chatId = currentUserId.compareTo(widget.receiverId!) > 0 
          ? '${currentUserId}_${widget.receiverId}' 
          : '${widget.receiverId}_$currentUserId';

      final querySnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('text', isEqualTo: _roomId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({'duration': _callDurationInSeconds});
      }
    } catch (e) {
      debugPrint('Error updating call duration: $e');
    }
  }

  void _toggleMic() {
    if (signaling.localStream != null) {
      bool enabled = signaling.localStream!.getAudioTracks()[0].enabled;
      signaling.localStream!.getAudioTracks()[0].enabled = !enabled;
      setState(() {
        _isMicMuted = enabled;
      });
    }
  }

  void _toggleCamera() {
    if (signaling.localStream != null && widget.isVideoCall) {
      bool enabled = signaling.localStream!.getVideoTracks()[0].enabled;
      signaling.localStream!.getVideoTracks()[0].enabled = !enabled;
      setState(() {
        _isVideoDisabled = enabled;
      });
    }
  }

  void _switchCamera() {
    if (signaling.localStream != null && widget.isVideoCall) {
      Helper.switchCamera(signaling.localStream!.getVideoTracks()[0]);
    }
  }

  Future<void> _hangUp() async {
    if (_isHangingUp || _isDisposed) return;
    _isHangingUp = true;
    _ringTimer?.cancel();
    if (!kIsWeb) {
      try { FlutterRingtonePlayer().stop(); } catch (_) {}
    }
    // 1. Stop tracks FIRST — releases mic/camera OS indicator immediately
    _releaseLocalMedia();

    // 2. Pop immediately so the UI doesn't hang waiting for network operations
    if (mounted && !_isDisposed) {
      Navigator.pop(context);
    }

    // 3. Fully tear down WebRTC (removes room from DB, disposes streams)
    signaling.hangUp().then((_) async {
      // 4. Remove incoming_calls nodes in background and update duration
      await _updateCallDurationMessage();
      if (widget.receiverId != null && widget.roomId == null) {
        await FirebaseDatabase.instance.ref('incoming_calls/${widget.receiverId}').remove();
      }
      if (widget.roomId != null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await FirebaseDatabase.instance.ref('incoming_calls/${currentUser.uid}').remove();
        }
      }
    }).catchError((e) {
      debugPrint('Error during background hangup: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote Video
            if (_remoteRenderer.srcObject != null && widget.isVideoCall)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.receiverId != null)
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(widget.receiverId).snapshots(),
                        builder: (context, snapshot) {
                          String? profilePic;
                          if (snapshot.hasData && snapshot.data!.exists) {
                            var data = snapshot.data!.data() as Map<String, dynamic>?;
                            profilePic = data?['profilepic'];
                          }
                          return RippleAnimation(
                            child: CircleAvatar(
                              radius: 50,
                              backgroundImage: profilePic != null && profilePic.isNotEmpty
                                  ? NetworkImage(profilePic)
                                  : null,
                              child: profilePic == null || profilePic.isEmpty
                                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                                  : null,
                            ),
                          );
                        },
                      )
                    else
                      RippleAnimation(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade800,
                          child: const Icon(Icons.person, size: 50, color: Colors.white),
                        ),
                      ),

                  ],
                ),
              ),
              
            // Local Video (Picture-in-Picture)
            if (_localRenderer.srcObject != null && widget.isVideoCall)
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  width: 100,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // Controls
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                    color: _isMicMuted ? Colors.red : Colors.white24,
                    onTap: _toggleMic,
                  ),
                  if (widget.isVideoCall) ...[
                    _buildControlButton(
                      icon: _isVideoDisabled ? Icons.videocam_off : Icons.videocam,
                      color: _isVideoDisabled ? Colors.red : Colors.white24,
                      onTap: _toggleCamera,
                    ),
                    _buildControlButton(
                      icon: Icons.switch_camera,
                      color: Colors.white24,
                      onTap: _switchCamera,
                    ),
                  ],
                  _buildControlButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    onTap: () => _hangUp(),
                  ),
                ],
              ),
            ),
            
            // Back Button
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => _hangUp(),
              ),
            ),
            
            // Name at top
            Positioned(
              top: 25,
              left: 60,
              right: 60,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.receiverName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1)),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      _remoteRenderer.srcObject == null
                          ? (widget.roomId == null ? 'Calling...' : 'Connecting...')
                          : _formatDuration(_callDurationInSeconds),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}

class RippleAnimation extends StatefulWidget {
  final Widget child;
  const RippleAnimation({Key? key, required this.child}) : super(key: key);

  @override
  _RippleAnimationState createState() => _RippleAnimationState();
}

class _RippleAnimationState extends State<RippleAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1, milliseconds: 500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100 + (_controller.value * 50),
              height: 100 + (_controller.value * 50),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: (1 - _controller.value) * 0.5),
              ),
            ),
            Container(
              width: 120 + (_controller.value * 80),
              height: 120 + (_controller.value * 80),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: (1 - _controller.value) * 0.2),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}
