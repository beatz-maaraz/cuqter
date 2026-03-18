import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    Key? key,
    required this.receiverId,
    required this.receiverName,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _wallpaperIndex = 0;

  final List<Color> _wallpapers = [
    Colors.white,
    Colors.amber[50]!,
    Colors.blue[50]!,
    Colors.green[50]!,
    Colors.purple[50]!,
  ];

  String getChatId(String uid1, String uid2) {
    if (uid1.compareTo(uid2) > 0) {
      return '${uid1}_$uid2';
    } else {
      return '${uid2}_$uid1';
    }
  }

  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      String chatId = getChatId(_auth.currentUser!.uid, widget.receiverId);
      
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': _auth.currentUser!.uid,
        'receiverId': widget.receiverId,
        'text': _messageController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(_auth.currentUser!.uid).set({
        'contacts': FieldValue.arrayUnion([widget.receiverId])
      }, SetOptions(merge: true));
      
      await _firestore.collection('users').doc(widget.receiverId).set({
        'contacts': FieldValue.arrayUnion([_auth.currentUser!.uid])
      }, SetOptions(merge: true));

      _messageController.clear();
    }
  }

  void _showDropMenu(BuildContext context, Offset position, String docId) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect positionRect = RelativeRect.fromRect(
      Rect.fromPoints(position, position),
      Offset.zero & overlay.size,
    );

    final result = await showMenu(
      context: context,
      position: positionRect,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      elevation: 8,
      items: [
        PopupMenuItem(
          value: 'drop',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Drop Message', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );

    if (result == 'drop') {
      String chatId = getChatId(_auth.currentUser!.uid, widget.receiverId);
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(docId)
          .delete();
    }
  }

  String _formatLastSeen(Timestamp? timestamp) {
    if (timestamp == null) return 'Offline';
    DateTime date = timestamp.toDate();
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Active just now';
    if (diff.inHours < 1) return 'Active ${diff.inMinutes}m';
    if (diff.inDays < 1) return 'Active ${diff.inHours}h';
    if (diff.inDays < 7) return 'Active ${diff.inDays}d';
    return 'Offline';
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime date = timestamp.toDate();
    String hour = date.hour > 12 ? (date.hour - 12).toString() : (date.hour == 0 ? '12' : date.hour.toString());
    String minute = date.minute.toString().padLeft(2, '0');
    String amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    String chatId = getChatId(_auth.currentUser!.uid, widget.receiverId);

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('users').doc(widget.receiverId).snapshots(),
          builder: (context, snapshot) {
            String status = 'Offline';
            if (snapshot.hasData && snapshot.data!.exists) {
              var data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null) {
                if (data['isOnline'] == true) {
                  status = 'Active Now';
                } else {
                  status = _formatLastSeen(data['lastSeen'] as Timestamp?);
                }
              }
            }
            return Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Text(widget.receiverName[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.receiverName, style: const TextStyle(fontSize: 18, color: Colors.white)),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        color: status == 'Active Now' ? Colors.green[300] : Colors.white70,
                        fontWeight: status == 'Active Now' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.wallpaper, color: Colors.white),
            tooltip: 'Change Wallpaper',
            onPressed: () {
              setState(() {
                _wallpaperIndex = (_wallpaperIndex + 1) % _wallpapers.length;
              });
            },
          )
        ],
      ),
      body: Container(
        color: _wallpapers[_wallpaperIndex],
        child: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No messages yet.'));
                }

                var messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index].data() as Map<String, dynamic>;
                    String docId = messages[index].id;
                    bool isMe = message['senderId'] == _auth.currentUser!.uid;
                    String timeText = _formatTime(message['timestamp'] as Timestamp?);

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPressStart: isMe ? (details) => _showDropMenu(context, details.globalPosition, docId) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.teal[100] : Colors.grey[200],
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(15),
                              topRight: const Radius.circular(15),
                              bottomLeft: isMe ? const Radius.circular(15) : const Radius.circular(0),
                              bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                message['text'] ?? '',
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (timeText.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    timeText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.send, color: Colors.teal),
                     onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
