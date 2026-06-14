import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/animated_send_button.dart';
import '../widgets/chat_message_text.dart';

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
  Stream<QuerySnapshot>? _messageStream;
  Stream<DocumentSnapshot>? _receiverStream;
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();
  bool _enterIsSend = false;
  double _fontSize = 20.0;

  Future<void> _loadChatPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _enterIsSend = prefs.getBool('chat_enter_is_send') ?? false;
        _fontSize = prefs.getDouble('chat_font_size') ?? 20.0;
      });
    } catch (_) {}
  }

  final List<Color> _wallpapers = [
    Colors.white,
    Colors.amber[50]!,
    Colors.blue[50]!,
    Colors.green[50]!,
    Colors.purple[50]!,
  ];

  String _formatDateDivider(DateTime date) {
    DateTime now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    DateTime yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

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
    final colorScheme = Theme.of(context).colorScheme;

    final result = await showMenu(
      context: context,
      position: positionRect,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: colorScheme.surface,
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
                  color: Colors.redAccent.withValues(alpha: 0.1),
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
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete All Chat?'),
          content: Text(
            'Are you sure you want to delete all messages in this chat? This action cannot be undone.',
            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.8)),
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
      final prefs = await SharedPreferences.getInstance();
      
      final localUrl = prefs.getString('wallpaper_${chatId}_url');
      final localIndex = prefs.getInt('wallpaper_${chatId}_index');
      
      if (mounted) {
        setState(() {
          _customWallpaperUrl = localUrl ?? prefs.getString('global_wallpaper_url');
          _wallpaperIndex = localIndex ?? prefs.getInt('global_wallpaper_index') ?? 0;
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
      final prefs = await SharedPreferences.getInstance();
      
      if (_customWallpaperUrl != null) {
        await prefs.setString('wallpaper_${chatId}_url', _customWallpaperUrl!);
      } else {
        await prefs.remove('wallpaper_${chatId}_url');
      }
      await prefs.setInt('wallpaper_${chatId}_index', _wallpaperIndex);
    } catch (e) {
      print('Error saving wallpaper: $e');
    }
  }

  void _showWallpaperOptions() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Text(
                'Chat Wallpaper',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Personalize your conversation background',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setState(() {
                      _customWallpaperUrl = image.path;
                    });
                    _saveWallpaperPreference();
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.photo_library_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 16),
                      Text(
                        'Pick from Gallery',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Solid Colors',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _wallpapers.length,
                  itemBuilder: (context, index) {
                    bool isSelected = _wallpaperIndex == index && _customWallpaperUrl == null;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _wallpaperIndex = index;
                          _customWallpaperUrl = null;
                        });
                        _saveWallpaperPreference();
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 70,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: _wallpapers[index],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.1),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(Icons.check_rounded, color: colorScheme.primary, size: 28)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  void _showCallComingSoon(BuildContext context, {required bool isVideo}) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              // Icon with gradient glow
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isVideo
                        ? [colorScheme.primary, colorScheme.tertiary]
                        : [colorScheme.secondary, colorScheme.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),
              // Coming Soon badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'COMING SOON',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onPrimaryContainer,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isVideo ? 'Video Calls' : 'Voice Calls',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isVideo
                    ? 'HD video calling is on its way.\nStay tuned for face-to-face conversations!'
                    : 'Crystal-clear voice calling is coming.\nWe\'re working hard to bring it to you!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
    String chatId = getChatId(_auth.currentUser!.uid, widget.receiverId);
    _messageStream = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
    _receiverStream = _firestore.collection('users').doc(widget.receiverId).snapshots();

    // Mark all unread messages as read when opening the chat
    _messageService.markAllMessagesAsRead(chatId, _auth.currentUser!.uid);
    // Load saved wallpaper preference
    _loadWallpaperPreference();
    _loadChatPreferences();
  }

  @override
  Widget build(BuildContext context) {
    String chatId = getChatId(_auth.currentUser!.uid, widget.receiverId);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: _receiverStream,
          builder: (context, snapshot) {
            String status = 'Offline';
            Map<String, dynamic>? data;
            if (snapshot.hasData && snapshot.data!.exists) {
              data = snapshot.data!.data() as Map<String, dynamic>?;
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
                Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: data != null && data['profilepic'] != null && data['profilepic'].toString().isNotEmpty
                          ? (data['profilepic'].toString().startsWith('http')
                              ? NetworkImage(data['profilepic'].toString()) as ImageProvider
                              : AssetImage(data['profilepic'].toString()) as ImageProvider)
                          : null,
                      child: data == null || data['profilepic'] == null || data['profilepic'].toString().isEmpty
                          ? Text(
                              widget.receiverName[0].toUpperCase(),
                              style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    if (data != null && data['isOnline'] == true)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.primary, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.receiverName,
                      style: TextStyle(fontSize: 18, color: colorScheme.onPrimary),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        color: status == 'Active Now' ? Colors.green[300] : colorScheme.onPrimary.withValues(alpha: 0.7),
                        fontWeight: status == 'Active Now' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        backgroundColor: colorScheme.primary,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        actions: [
          IconButton(
            icon: huge.HugeIcon(
              icon: huge.HugeIcons.strokeRoundedCall,
              color: colorScheme.onPrimary,
              size: 22,
            ),
            tooltip: 'Voice Call',
            onPressed: () => _showCallComingSoon(context, isVideo: false),
          ),
          IconButton(
            icon: huge.HugeIcon(
              icon: huge.HugeIcons.strokeRoundedVideo01,
              color: colorScheme.onPrimary,
              size: 22,
            ),
            tooltip: 'Video Call',
            onPressed: () => _showCallComingSoon(context, isVideo: true),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'wallpaper') {
                _showWallpaperOptions();
              } else if (value == 'deleteAll') {
                _showDeleteConfirmation();
              }
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'wallpaper',
                child: Row(
                  children: [
                    huge.HugeIcon(
                      icon: huge.HugeIcons.strokeRoundedImage01,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Change Wallpaper',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'deleteAll',
                child: Row(
                  children: [
                    huge.HugeIcon(
                      icon: huge.HugeIcons.strokeRoundedDelete01,
                      color: colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Drop Chat',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            icon: huge.HugeIcon(
              icon: huge.HugeIcons.strokeRoundedMore03,
              color: colorScheme.onPrimary,
              size: 22,
            ),
          )
        ],
      ),
      body: _isLoadingWallpaper
          ? const Center(child: CircularProgressIndicator())
          : PopScope(
              canPop: !_showEmojiPicker,
              onPopInvokedWithResult: (bool didPop, dynamic result) {
                if (didPop) return;
                if (_showEmojiPicker) {
                  setState(() {
                    _showEmojiPicker = false;
                  });
                }
              },
              child: Container(
              decoration: BoxDecoration(
                color: _customWallpaperUrl == null ? (_wallpaperIndex == 0 ? colorScheme.surface : _wallpapers[_wallpaperIndex]) : null,
                image: _customWallpaperUrl != null
                    ? DecorationImage(
                        image: kIsWeb
                            ? NetworkImage(_customWallpaperUrl!) as ImageProvider
                            : FileImage(File(_customWallpaperUrl!)) as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _messageStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              'No messages yet.',
                              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                            ),
                          );
                        }

                        var messages = snapshot.data!.docs;

                        // Mark received messages as read in a single batch if there are any unread ones
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          bool hasUnread = false;
                          for (var messageDoc in messages) {
                            var message = messageDoc.data() as Map<String, dynamic>;
                            bool isReceived = message['senderId'] != _auth.currentUser!.uid;
                            bool isRead = message['isRead'] ?? false;

                            if (isReceived && !isRead) {
                              hasUnread = true;
                              break;
                            }
                          }
                          if (hasUnread) {
                            _messageService.markAllMessagesAsRead(chatId, _auth.currentUser!.uid);
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

                            bool showDivider = false;
                            DateTime? currentDt = (message['timestamp'] as Timestamp?)?.toDate();
                            
                            if (index == messages.length - 1) {
                              showDivider = true;
                            } else {
                              var olderMsg = messages[index + 1].data() as Map<String, dynamic>;
                              DateTime? olderDt = (olderMsg['timestamp'] as Timestamp?)?.toDate();
                              if (currentDt != null && olderDt != null) {
                                if (currentDt.year != olderDt.year || 
                                    currentDt.month != olderDt.month || 
                                    currentDt.day != olderDt.day) {
                                  showDivider = true;
                                }
                              } else if (currentDt != null && olderDt == null) {
                                showDivider = true;
                              }
                            }

                            Widget messageWidget = Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: GestureDetector(
                                onLongPressStart: isMe
                                    ? (details) => _showDropMenu(context, details.globalPosition, docId)
                                    : null,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: isMe ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(20),
                                        topRight: const Radius.circular(20),
                                        bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                                        bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: ChatMessageText(
                                      text: message['text'] ?? '',
                                      baseStyle: TextStyle(
                                        fontSize: _fontSize,
                                        color: isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                                      ),
                                      linkColor: isMe
                                          ? (Theme.of(context).brightness == Brightness.dark
                                              ? Colors.blue[300]!
                                              : Colors.blue[800]!)
                                          : (Theme.of(context).brightness == Brightness.dark
                                              ? Colors.blue[300]!
                                              : Colors.blue[800]!),
                                      trailing: timeText.isNotEmpty
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  timeText,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isMe
                                                        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                                                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                                  ),
                                                ),
                                                if (isMe)
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 4.0),
                                                    child: Icon(
                                                      isRead ? Icons.done_all : Icons.done,
                                                      size: 14,
                                                      color: isRead ? Colors.blue : colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
                                                    ),
                                                  ),
                                              ],
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            );

                            if (showDivider && currentDt != null) {
                              String dateText = _formatDateDivider(currentDt);
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        dateText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                  messageWidget,
                                ],
                              );
                            }

                            return messageWidget;
                          },
                        );
                      },
                    ),
                  ),
                  _buildMessageInput(context),
                ],
              ),
            ),
            ),
    );
  }

  Widget _buildMessageInput(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    focusNode: _focusNode,
                    controller: _messageController,
                    style: TextStyle(color: colorScheme.onSurface),
                    onSubmitted: (value) {
                      if (_enterIsSend) {
                        sendMessage();
                      }
                    },
                    decoration: InputDecoration(
                      prefixIcon: IconButton(
                        icon: Icon(
                          _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                          color: colorScheme.primary,
                        ),
                        onPressed: () {
                          if (_showEmojiPicker) {
                            _focusNode.requestFocus();
                          } else {
                            _focusNode.unfocus();
                            setState(() {
                              _showEmojiPicker = !_showEmojiPicker;
                            });
                          }
                        },
                      ),
                      hintText: 'Text a Message...',
                      hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSendButton(
                  onTap: sendMessage,
                  backgroundColor: colorScheme.primary,
                  iconColor: colorScheme.onPrimary,
                  iconSize: 22.0,
                  radius: 24.0,
                ),
              ],
            ),
          ),
        ),
        if (_showEmojiPicker)
          SafeArea(
            child: SizedBox(
              height: 250,
              child: EmojiPicker(
                textEditingController: _messageController,
                config: Config(
                  height: 250,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 7,
                    emojiSizeMax: 36 * (kIsWeb ? 1.0 : (Platform.isIOS ? 1.20 : 1.0)),
                    backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
