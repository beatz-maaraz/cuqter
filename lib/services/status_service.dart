import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cuqter/modules/status.dart';

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
    return _firestore
        .collection('statuses')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Status.fromMap(doc.data()))
          .toList();
    });
  }
  /// Delete a status
  Future<void> deleteStatus(String statusId) async {
    try {
      await _firestore.collection('statuses').doc(statusId).delete();
    } catch (e) {
      print('Error deleting status: $e');
    }
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
}

