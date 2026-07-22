import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';

typedef StreamStateCallback = void Function(MediaStream stream);

class SignalingService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? currentRoomId;
  StreamStateCallback? onAddRemoteStream;
  Function(String)? onRoomCreated;
  Function()? onCallEnded;
  bool _callEndedFired = false;

  void _fireCallEnded() {
    if (_callEndedFired) return;
    _callEndedFired = true;
    if (onCallEnded != null) onCallEnded!();
  }

  final Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302'
        ]
      }
    ]
  };

  Future<void> initLocalStream(bool isVideo) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': isVideo ? {'facingMode': 'user'} : false,
    };

    localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  Future<String> createRoom() async {
    DatabaseReference roomRef = _database.ref('calls').push();
    currentRoomId = roomRef.key;
    roomRef.onDisconnect().remove();

    peerConnection = await createPeerConnection(configuration);

    registerPeerConnectionListeners();

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    // Code for collecting ICE candidates
    DatabaseReference callerCandidatesRef = roomRef.child('callerCandidates');
    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      callerCandidatesRef.push().set(candidate.toMap());
    };

    // Add the RTCSessionDescription to the room
    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    Map<String, dynamic> roomWithOffer = {
      'offer': {
        'type': offer.type,
        'sdp': offer.sdp,
      }
    };
    await roomRef.update(roomWithOffer);
    
    if (onRoomCreated != null) {
      onRoomCreated!(currentRoomId!);
    }

    // Listen for remote answer
    roomRef.onValue.listen((event) async {
      if (event.snapshot.value == null) {
        _fireCallEnded();
        return;
      }
      var data = event.snapshot.value as Map<dynamic, dynamic>;
      
      var remoteDesc = await peerConnection?.getRemoteDescription();
      if (remoteDesc != null) {
        return; // Already set
      }

      if (data['answer'] != null) {
        var answer = data['answer'];
        var sdp = answer['sdp'];
        var type = answer['type'];
        
        RTCSessionDescription answerDescription = RTCSessionDescription(sdp, type);
        await peerConnection?.setRemoteDescription(answerDescription);
      }
    });

    // Listen for remote ICE candidates
    roomRef.child('calleeCandidates').onChildAdded.listen((event) {
      var data = event.snapshot.value as Map<dynamic, dynamic>;
      peerConnection!.addCandidate(
        RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        ),
      );
    });

    return currentRoomId!;
  }

  Future<void> joinRoom(String roomId, bool isVideo) async {
    currentRoomId = roomId;
    DatabaseReference roomRef = _database.ref('calls/$roomId');
    var roomSnapshot = await roomRef.get();
    
    if (!roomSnapshot.exists) {
      debugPrint('Room not found');
      return;
    }

    peerConnection = await createPeerConnection(configuration);
    registerPeerConnectionListeners();

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    // Code for collecting ICE candidates
    DatabaseReference calleeCandidatesRef = roomRef.child('calleeCandidates');
    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      calleeCandidatesRef.push().set(candidate.toMap());
    };

    // Set remote description from offer
    var roomData = roomSnapshot.value as Map<dynamic, dynamic>;
    if (roomData['offer'] != null) {
      var offer = roomData['offer'];
      await peerConnection?.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );
    }

    // Create Answer
    RTCSessionDescription answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);

    await roomRef.update({
      'answer': {
        'type': answer.type,
        'sdp': answer.sdp,
      }
    });

    // Listen for remote ICE candidates
    roomRef.child('callerCandidates').onChildAdded.listen((event) {
      var data = event.snapshot.value as Map<dynamic, dynamic>;
      peerConnection!.addCandidate(
        RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        ),
      );
    });

    // Listen for room deletion
    roomRef.onValue.listen((event) {
      if (event.snapshot.value == null) {
        _fireCallEnded();
      }
    });
  }

  void registerPeerConnectionListeners() {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint('ICE gathering state changed: $state');
    };

    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('Connection state change: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _fireCallEnded();
      }
    };

    peerConnection?.onSignalingState = (RTCSignalingState state) {
      debugPrint('Signaling state change: $state');
    };

    peerConnection?.onAddStream = (MediaStream stream) {
      debugPrint("Add remote stream");
      remoteStream = stream;
      if (onAddRemoteStream != null) {
        onAddRemoteStream!(stream);
      }
    };

    peerConnection?.onTrack = (RTCTrackEvent event) {
      debugPrint("Track added");
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        if (onAddRemoteStream != null) {
          onAddRemoteStream!(remoteStream!);
        }
      }
    };
  }

  Future<void> hangUp() async {
    _callEndedFired = true; // Prevent onCallEnded from firing on local hang-up
    try {
      if (currentRoomId != null) {
        var db = _database.ref('calls/$currentRoomId');
        await db.remove();
        currentRoomId = null;
      }

      // Stop every track explicitly — this is what turns off the OS mic/camera indicator
      if (localStream != null) {
        for (final track in localStream!.getTracks()) {
          await track.stop();
        }
        await localStream!.dispose();
        localStream = null;
      }

      if (remoteStream != null) {
        for (final track in remoteStream!.getTracks()) {
          await track.stop();
        }
        await remoteStream!.dispose();
        remoteStream = null;
      }

      await peerConnection?.close();
      peerConnection = null;
    } catch (e) {
      debugPrint('hangUp error: $e');
    }
  }
}
