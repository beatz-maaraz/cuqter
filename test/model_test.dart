import 'package:flutter_test/flutter_test.dart';
import 'package:cuqter/modules/message.dart';

void main() {
  group('Message Model Unit Tests', () {
    test('Message instantiates and serializes to JSON correctly', () {
      final now = DateTime.now();
      final message = Message(
        id: 'msg_001',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Hello from Cuqter!',
        timestamp: now,
        isRead: false,
        type: 'text',
      );

      final json = message.toJson();

      expect(json['senderId'], equals('user_a'));
      expect(json['receiverId'], equals('user_b'));
      expect(json['text'], equals('Hello from Cuqter!'));
      expect(json['isRead'], isFalse);
      expect(json['type'], equals('text'));
      expect(json['timestamp'], equals(now));
    });

    test('Message handles reply fields in JSON serialization', () {
      final message = Message(
        id: 'msg_002',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'This is a reply',
        timestamp: DateTime.now(),
        replyToId: 'msg_001',
        replyToText: 'Original message',
        replyToSenderId: 'user_b',
        replyToType: 'text',
      );

      final json = message.toJson();

      expect(json['replyToId'], equals('msg_001'));
      expect(json['replyToText'], equals('Original message'));
      expect(json['replyToSenderId'], equals('user_b'));
      expect(json['replyToType'], equals('text'));
    });
  });
}
