import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
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
  bool _isSpeakerOn = true;
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
            String callerPic = '';
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
                callerPic = userDoc.data()!['profilepic'] ?? '';
              }
            } catch (e) {
              debugPrint('Error fetching caller name: $e');
            }

            final incomingCallRef = FirebaseDatabase.instance.ref('incoming_calls/${widget.receiverId}');
            await incomingCallRef.set({
              'roomId': _roomId,
              'callerId': currentUser.uid,
              'callerName': callerName,
              'callerPic': callerPic,
              'isVideo': widget.isVideoCall,
              'timestamp': ServerValue.timestamp,
            });
            incomingCallRef.onDisconnect().remove();
          }
        }

        // Start 35 second timer to end call if unanswered
        _ringTimer = Timer(const Duration(seconds: 35), () async {
          if (!_isConnected && mounted && !_isHangingUp && !_isDisposed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Call ended: No answer (35s timeout)')),
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
      final audioTracks = signaling.localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final currentlyEnabled = audioTracks[0].enabled;
        for (var track in audioTracks) {
          track.enabled = !currentlyEnabled;
        }
        setState(() {
          _isMicMuted = currentlyEnabled;
        });
      }
    }
  }

  void _toggleSpeaker() {
    final nextSpeakerState = !_isSpeakerOn;
    setState(() {
      _isSpeakerOn = nextSpeakerState;
    });
    if (!kIsWeb) {
      try {
        Helper.setSpeakerphoneOn(nextSpeakerState);
      } catch (e) {
        debugPrint('Error toggling speaker: $e');
      }
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
                                radius: 64,
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                backgroundImage: profilePic != null && profilePic.isNotEmpty
                                    ? NetworkImage(profilePic)
                                    : const AssetImage('assets/icon/default_profile.png') as ImageProvider,
                              ),
                            );
                          },
                        )
                      else
                        RippleAnimation(
                          child: CircleAvatar(
                            radius: 64,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            backgroundImage: const AssetImage('assets/icon/default_profile.png'),
                          ),
                        ),
                    ],
                  ),
                ),
                
              // Local Video (Picture-in-Picture)
              if (_localRenderer.srcObject != null && widget.isVideoCall)
                Positioned(
                  top: 70,
                  right: 20,
                  child: Container(
                    width: 110,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white30, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: RTCVideoView(
                        _localRenderer,
                        mirror: true,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),

              // Header Bar (sketch: Left 'v' down arrow, Center Name & Timer, Right '+' Add user)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 'v' icon (Chevron down / Minimize / Back button)
                    IconButton(
                      icon: const huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedArrowDown01,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => _hangUp(),
                    ),
                    
                    // Center Name and Duration
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.receiverName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _remoteRenderer.srcObject == null
                              ? (widget.roomId == null ? 'Calling...' : 'Connecting...')
                              : _formatDuration(_callDurationInSeconds),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    // '+' Add Participant icon
                    IconButton(
                      icon: const huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedUserAdd01,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Add participant feature coming soon!')),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Bottom Controls Pill Container Bar (sketch: Rounded pill shape containing Speaker, Mute, End Call)
              Positioned(
                bottom: 36,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 25,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Speaker Button
                        _buildPillControlButton(
                          icon: _isSpeakerOn ? huge.HugeIcons.strokeRoundedVolumeHigh : huge.HugeIcons.strokeRoundedVolumeOff,
                          color: _isSpeakerOn ? Colors.white.withValues(alpha: 0.25) : Colors.white12,
                          iconColor: Colors.white,
                          onTap: _toggleSpeaker,
                        ),
                        const SizedBox(width: 16),
                        
                        // Mute Mic Button
                        _buildPillControlButton(
                          icon: _isMicMuted ? huge.HugeIcons.strokeRoundedMicOff01 : huge.HugeIcons.strokeRoundedMic01,
                          color: _isMicMuted ? Colors.red.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.25),
                          iconColor: Colors.white,
                          onTap: _toggleMic,
                        ),
                        
                        if (widget.isVideoCall) ...[
                          const SizedBox(width: 16),
                          _buildPillControlButton(
                            icon: _isVideoDisabled ? huge.HugeIcons.strokeRoundedVideo01 : huge.HugeIcons.strokeRoundedVideo01,
                            color: _isVideoDisabled ? Colors.red.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.25),
                            iconColor: Colors.white,
                            onTap: _toggleCamera,
                          ),
                          const SizedBox(width: 16),
                          _buildPillControlButton(
                            icon: huge.HugeIcons.strokeRoundedCameraRotated01,
                            color: Colors.white.withValues(alpha: 0.25),
                            iconColor: Colors.white,
                            onTap: _switchCamera,
                          ),
                        ],
                        
                        const SizedBox(width: 16),
                        
                        // End Call Button (Red circle)
                        _buildPillControlButton(
                          icon: huge.HugeIcons.strokeRoundedCall,
                          isRotatedCallEnd: true,
                          color: Colors.red,
                          iconColor: Colors.white,
                          size: 54,
                          iconSize: 26,
                          onTap: () => _hangUp(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillControlButton({
    required dynamic icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    bool isRotatedCallEnd = false,
    double size = 48,
    double iconSize = 22,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isRotatedCallEnd
              ? Transform.rotate(
                  angle: 2.356, // 135 deg hang up rotation
                  child: huge.HugeIcon(
                    icon: icon,
                    color: iconColor,
                    size: iconSize,
                  ),
                )
              : (icon is IconData
                  ? Icon(icon, color: iconColor, size: iconSize)
                  : huge.HugeIcon(
                      icon: icon,
                      color: iconColor,
                      size: iconSize,
                    )),
        ),
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
              width: 120 + (_controller.value * 50),
              height: 120 + (_controller.value * 50),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: (1 - _controller.value) * 0.3),
              ),
            ),
            Container(
              width: 140 + (_controller.value * 80),
              height: 140 + (_controller.value * 80),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: (1 - _controller.value) * 0.15),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}
