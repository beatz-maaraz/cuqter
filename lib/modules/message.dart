class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
  });

  // Convert Message to JSON for Firestore
  Map<String, dynamic> toJson() => {
    'senderId': senderId,
    'receiverId': receiverId,
    'text': text,
    'timestamp': timestamp,
    'isRead': isRead,
  };

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
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
