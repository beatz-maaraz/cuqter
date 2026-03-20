import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/colors.dart';
import '../services/message_service.dart';

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
  final MessageService _messageService = MessageService();
  int _wallpaperIndex = 0;
  String? _customWallpaperUrl;
  bool _isLoadingWallpaper = true;

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
      
      // Use MessageService to send message with isRead field
      await _messageService.sendMessage(
        chatId: chatId,
        senderId: _auth.currentUser!.uid,
        receiverId: widget.receiverId,
        text: _messageController.text,
      );

      // Update contacts
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

  Future<void> _deleteAllChat() async {
    String chatId = getChatId(_auth.currentUser!.uid, widget.receiverId);
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All messages deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error deleting all messages: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error deleting messages'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete All Chat?'),
          content: const Text(
            'Are you sure you want to delete all messages in this chat? This action cannot be undone.',
            style: TextStyle(color: Colors.black87),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteAllChat();
              },
              child: const Text(
                'Delete All',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadWallpaperPreference() async {
    try {
      String chatId = getChatId(_auth.currentUser!.uid, widget.receiverId);
      var doc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('chat_wallpapers')
          .doc(chatId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _customWallpaperUrl = doc['wallpaperUrl'] as String?;
          _wallpaperIndex = doc['colorIndex'] ?? 0;
          _isLoadingWallpaper = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingWallpaper = false;
        });
      }
    } catch (e) {
      print('Error loading wallpaper: $e');
      if (mounted) {
        setState(() {
          _isLoadingWallpaper = false;
        });
      }
    }
  }

  Future<void> _saveWallpaperPreference() async {
    try {
      String chatId = getChatId(_auth.currentUser!.uid, widget.receiverId);
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('chat_wallpapers')
          .doc(chatId)
          .set({
        'wallpaperUrl': _customWallpaperUrl,
        'colorIndex': _wallpaperIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving wallpaper: $e');
    }
  }

  void _showWallpaperOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Wallpaper'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Preset Colors:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _wallpapers.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _wallpaperIndex = index;
                            _customWallpaperUrl = null;
                          });
                          _saveWallpaperPreference();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: _wallpapers[index],
                            border: _wallpaperIndex == index && _customWallpaperUrl == null
                                ? Border.all(color: Colors.blue, width: 3)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _wallpaperIndex == index && _customWallpaperUrl == null
                              ? const Icon(Icons.check, color: Colors.blue)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Mark all unread messages as read when opening the chat
    String chatId = getChatId(_auth.currentUser!.uid, widget.receiverId);
    _messageService.markAllMessagesAsRead(chatId, _auth.currentUser!.uid);
    // Load saved wallpaper preference
    _loadWallpaperPreference();
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
            onPressed: _showWallpaperOptions,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'deleteAll') {
                _showDeleteConfirmation();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'deleteAll',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 12),
                    const Text(
                      'Drop Chat',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 12
                    ),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.white),
          )
        ],
      ),
      body: _isLoadingWallpaper
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : Container(
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
                
                // Mark received messages as read
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  for (var messageDoc in messages) {
                    var message = messageDoc.data() as Map<String, dynamic>;
                    bool isReceived = message['senderId'] != _auth.currentUser!.uid;
                    bool isRead = message['isRead'] ?? false;
                    
                    if (isReceived && !isRead) {
                      _messageService.markMessageAsRead(chatId, messageDoc.id);
                    }
                  }
                });
                
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index].data() as Map<String, dynamic>;
                    String docId = messages[index].id;
                    bool isMe = message['senderId'] == _auth.currentUser!.uid;
                    bool isRead = message['isRead'] ?? false;
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
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isMe)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 4.0),
                                          child: Icon(
                                            isRead ? Icons.done_all : Icons.done,
                                            size: 12,
                                            color: isRead ? Colors.blue : Colors.black54,
                                          ),
                                        ),
                                      Text(
                                        timeText,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
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
            padding: const EdgeInsets.all(15.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    hintLocales: [const Locale('en', 'US')],
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color.fromARGB(255, 182, 182, 182),
                      hintText: ' Type a message...',
                      
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                      icon: const Icon(Icons.send,
                       color: Colors.white),
                        tooltip: 'Send Message',
                       onPressed: sendMessage,
                  ),
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
