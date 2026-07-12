import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cuqter/modules/message.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all messages in a chat
  Stream<List<Message>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Message.fromJson(doc.id, doc.data()))
          .toList();
    });
  }

  /// Get unread messages (new messages)
  Stream<List<Message>> getUnreadMessages(String chatId, String currentUserId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Message.fromJson(doc.id, doc.data()))
          .toList();
    });
  }

  /// Get read messages (seen messages)
  Stream<List<Message>> getReadMessages(String chatId, String currentUserId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Message.fromJson(doc.id, doc.data()))
          .toList();
    });
  }

  /// Mark a message as read
  Future<void> markMessageAsRead(String chatId, String messageId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  /// Mark all messages in a chat as read for current user
  Future<void> markAllMessagesAsRead(String chatId, String currentUserId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all messages as read: $e');
    }
  }

  /// Filter messages by read status
  static List<Message> filterByReadStatus(List<Message> messages, bool isRead) {
    return messages.where((msg) => msg.isRead == isRead).toList();
  }

  /// Get count of unread messages
  Future<int> getUnreadMessageCount(String chatId, String currentUserId) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Get stream of unread message count
  Stream<int> getUnreadMessageCountStream(String chatId, String currentUserId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Send message with read tracking
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
    String type = 'text',
    String? replyToId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToType,
  }) async {
    try {
      final Map<String, dynamic> messageData = {
        'senderId': senderId,
        'receiverId': receiverId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': type,
      };

      if (replyToId != null) messageData['replyToId'] = replyToId;
      if (replyToText != null) messageData['replyToText'] = replyToText;
      if (replyToSenderId != null) messageData['replyToSenderId'] = replyToSenderId;
      if (replyToType != null) messageData['replyToType'] = replyToType;

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Ensure both users are in each other's contacts so they appear on the homepage
      await _firestore.collection('users').doc(senderId).set({
        'contacts': FieldValue.arrayUnion([receiverId])
      }, SetOptions(merge: true));
      await _firestore.collection('users').doc(receiverId).set({
        'contacts': FieldValue.arrayUnion([senderId])
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  /// Get last message in a chat
  Stream<Message?> getLastMessage(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return Message.fromJson(snapshot.docs.first.id, snapshot.docs.first.data());
    });
  }

  /// Log a call in user's call history
  Future<void> logCall({
    required String currentUserId,
    required String peerId,
    required String type, // 'video' or 'voice'
    required String status, // 'incoming' or 'outgoing'
    required String roomId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('call_history')
          .add({
        'peerId': peerId,
        'type': type,
        'status': status,
        'roomId': roomId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging call: $e');
    }
  }
}
