import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cuqter/modules/status.dart';
import 'package:cuqter/services/cloudinary_service.dart';

class StatusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add a new status
  Future<void> addStatus({
    required String uid,
    required String username,
    required String profilePic,
    required String mediaUrl,
    required String mediaType,
    required String caption,
  }) async {
    try {
      final docRef = _firestore.collection('statuses').doc();
      final status = Status(
        statusId: docRef.id,
        uid: uid,
        username: username,
        profilePic: profilePic,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        caption: caption,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );
      await docRef.set(status.toMap());
    } catch (e) {
      print('Error adding status: $e');
    }
  }

  /// Get active statuses
  Stream<List<Status>> getActiveStatuses() {
    _cleanupExpiredStatuses(); // Run cleanup asynchronously
    return _firestore
        .collection('statuses')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Status.fromMap(doc.data()))
          .toList();
    });
  }
  /// Delete a status
  Future<void> deleteStatus(Status status) async {
    try {
      if (status.mediaUrl.isNotEmpty && status.mediaType != 'text') {
        String? publicId = _extractPublicId(status.mediaUrl);
        if (publicId != null) {
          await CloudinaryService.deleteMedia(publicId, resourceType: status.mediaType);
        }
      }
      await _deleteStatusNotifications(status.statusId);
      await _firestore.collection('statuses').doc(status.statusId).delete();
    } catch (e) {
      print('Error deleting status: $e');
    }
  }

  Future<void> _cleanupExpiredStatuses() async {
    try {
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection('statuses')
          .where('expiresAt', isLessThanOrEqualTo: now)
          .get();
          
      for (var doc in snapshot.docs) {
        final status = Status.fromMap(doc.data());
        if (status.mediaUrl.isNotEmpty && status.mediaType != 'text') {
          String? publicId = _extractPublicId(status.mediaUrl);
          if (publicId != null) {
            await CloudinaryService.deleteMedia(publicId, resourceType: status.mediaType);
          }
        }
        await _deleteStatusNotifications(status.statusId);
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error cleaning up statuses: $e');
    }
  }

  Future<void> _deleteStatusNotifications(String statusId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('statusId', isEqualTo: statusId)
          .get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting notifications for status $statusId: $e');
    }
  }

  String? _extractPublicId(String url) {
    try {
      final uploadIndex = url.indexOf('/upload/');
      if (uploadIndex != -1) {
        String sub = url.substring(uploadIndex + 8);
        if (sub.startsWith('v') && sub.contains('/')) {
          sub = sub.substring(sub.indexOf('/') + 1);
        }
        final lastDot = sub.lastIndexOf('.');
        if (lastDot != -1) {
          sub = sub.substring(0, lastDot);
        }
        return Uri.decodeFull(sub);
      }
    } catch (e) {
      print('Error extracting public ID: $e');
    }
    return null;
  }

  /// Mark status as seen
  Future<void> markStatusAsSeen(String statusId, StatusViewer viewer) async {
    try {
      await _firestore.collection('statuses').doc(statusId).update({
        'viewers': FieldValue.arrayUnion([viewer.toMap()])
      });
    } catch (e) {
      print('Error marking status as seen: $e');
    }
  }

  /// Toggle like on status and send/remove notification
  Future<void> toggleLikeStatus({
    required String statusId,
    required String statusOwnerUid,
    required StatusLiker liker,
    required bool isLiking,
  }) async {
    try {
      final docRef = _firestore.collection('statuses').doc(statusId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final status = Status.fromMap(doc.data()!);
      List<StatusLiker> currentLikes = List.from(status.likes);

      if (isLiking) {
        currentLikes.removeWhere((l) => l.uid == liker.uid);
        currentLikes.add(liker);

        await docRef.update({
          'likes': currentLikes.map((l) => l.toMap()).toList(),
        });

        // Store notification for status owner if liker is not the owner
        if (liker.uid != statusOwnerUid) {
          final notificationId = 'status_like_${statusId}_${liker.uid}';
          await _firestore.collection('notifications').doc(notificationId).set({
            'notificationId': notificationId,
            'type': 'status_like',
            'statusId': statusId,
            'senderId': liker.uid,
            'senderName': liker.username,
            'senderProfilePic': liker.profilePic,
            'receiverId': statusOwnerUid,
            'title': 'Status Liked',
            'body': '${liker.username} liked your status',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      } else {
        currentLikes.removeWhere((l) => l.uid == liker.uid);
        await docRef.update({
          'likes': currentLikes.map((l) => l.toMap()).toList(),
        });

        // Remove notification
        final notificationId = 'status_like_${statusId}_${liker.uid}';
        await _firestore.collection('notifications').doc(notificationId).delete();
      }
    } catch (e) {
      print('Error toggling status like: $e');
    }
  }
}

