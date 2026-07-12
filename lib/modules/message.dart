class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final String type;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderId;
  final String? replyToType;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.type = 'text',
    this.replyToId,
    this.replyToText,
    this.replyToSenderId,
    this.replyToType,
  });

  // Convert Message to JSON for Firestore
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp,
      'isRead': isRead,
      'type': type,
    };
    if (replyToId != null) data['replyToId'] = replyToId;
    if (replyToText != null) data['replyToText'] = replyToText;
    if (replyToSenderId != null) data['replyToSenderId'] = replyToSenderId;
    if (replyToType != null) data['replyToType'] = replyToType;
    return data;
  }

  // Create Message from Firestore document
  factory Message.fromJson(String id, Map<String, dynamic> json) {
    return Message(
      id: id,
      senderId: json['senderId'] ?? '',
      receiverId: json['receiverId'] ?? '',
      text: json['text'] ?? '',
      timestamp: (json['timestamp'] != null) 
          ? (json['timestamp']).toDate() 
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
      type: json['type'] ?? 'text',
      replyToId: json['replyToId'],
      replyToText: json['replyToText'],
      replyToSenderId: json['replyToSenderId'],
      replyToType: json['replyToType'],
    );
  }

  // Copy with method for creating modified copies
  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? text,
    DateTime? timestamp,
    bool? isRead,
    String? type,
    String? replyToId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToType,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      replyToType: replyToType ?? this.replyToType,
    );
  }
}
