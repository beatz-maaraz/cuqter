import 'package:cloud_firestore/cloud_firestore.dart';

class StatusViewer {
  final String uid;
  final String username;
  final String profilePic;
  final DateTime viewedAt;

  StatusViewer({
    required this.uid,
    required this.username,
    required this.profilePic,
    required this.viewedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'profilePic': profilePic,
      'viewedAt': viewedAt,
    };
  }

  factory StatusViewer.fromMap(Map<String, dynamic> map) {
    return StatusViewer(
      uid: map['uid'] ?? '',
      username: map['username'] ?? 'Unknown User',
      profilePic: map['profilePic'] ?? '',
      viewedAt: map['viewedAt'] != null ? (map['viewedAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }
}

class Status {
  final String statusId;
  final String uid;
  final String username;
  final String profilePic;
  final String mediaUrl;
  final String mediaType; // 'text', 'image', 'video'
  final String caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<StatusViewer> viewers;

  Status({
    required this.statusId,
    required this.uid,
    required this.username,
    required this.profilePic,
    required this.mediaUrl,
    required this.mediaType,
    required this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.viewers = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'statusId': statusId,
      'uid': uid,
      'username': username,
      'profilePic': profilePic,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'caption': caption,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'viewers': viewers.map((v) => v.toMap()).toList(),
    };
  }

  factory Status.fromMap(Map<String, dynamic> map) {
    return Status(
      statusId: map['statusId'] ?? '',
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      profilePic: map['profilePic'] ?? '',
      mediaUrl: map['mediaUrl'] ?? '',
      mediaType: map['mediaType'] ?? '',
      caption: map['caption'] ?? '',
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : DateTime.now(),
      expiresAt: map['expiresAt'] != null ? (map['expiresAt'] as Timestamp).toDate() : DateTime.now().add(const Duration(hours: 24)),
      viewers: (map['viewers'] as List?)?.map((v) {
        if (v is String) {
          // Fallback for old schema where viewers was a list of strings
          return StatusViewer(uid: v, username: 'User', profilePic: '', viewedAt: DateTime.now());
        }
        return StatusViewer.fromMap(Map<String, dynamic>.from(v));
      }).toList() ?? [],
    );
  }
}
