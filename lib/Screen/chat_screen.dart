import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/animated_send_button.dart';
import '../widgets/chat_message_text.dart';
import '../widgets/full_screen_profile_pic_page.dart';
import 'full_screen_video_page.dart';
import 'userprofile.dart';

import '../services/message_service.dart';
import '../services/cloudinary_service.dart';
import '../services/local_storage_service.dart';

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
  bool _isAttachmentMenuOpen = false;
  bool _isUploading = false;
  bool _uploadCancelled = false;
  String? _uploadingFileName;
  String? _uploadingFileSize;
  String? _uploadingFileType;
  double _uploadProgress = 0.0;
  final Map<String, double> _downloadProgress = {};
  final Map<String, String?> _localFilePaths = {};
  final Set<String> _checkingFiles = {};

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
          _isAttachmentMenuOpen = false;
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
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfilePage(
                      name: widget.receiverName,
                      username: data?['username']?.toString() ?? '',
                      bio: data?['bio']?.toString() ?? '',
                      profilepic: data?['profilepic']?.toString() ?? '',
                    ),
                  ),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      final pic = data?['profilepic']?.toString() ?? '';
                      if (pic.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenProfilePicPage(
                            imageUrl: pic,
                            heroTag: 'profile_pic_hero_${widget.receiverId}',
                          ),
                        ),
                      );
                    }
                  },
                  child: Stack(
                    children: [
                      Hero(
                        tag: 'profile_pic_hero_${widget.receiverId}',
                        child: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          backgroundImage: data != null && data['profilepic'] != null && data['profilepic'].toString().isNotEmpty
                              ? (data['profilepic'].toString().startsWith('http')
                                  ? CachedNetworkImageProvider(data['profilepic'].toString())
                                  : AssetImage(data['profilepic'].toString()) as ImageProvider)
                              : null,
                          child: data == null || data['profilepic'] == null || data['profilepic'].toString().isEmpty
                              ? Text(
                                  widget.receiverName[0].toUpperCase(),
                                  style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
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
            ));
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
                            ? CachedNetworkImageProvider(_customWallpaperUrl!)
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
                          itemCount: _isUploading ? messages.length + 1 : messages.length,
                          itemBuilder: (context, index) {
                            if (_isUploading && index == 0) {
                              return Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer.withValues(alpha: 0.85),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20),
                                      bottomLeft: Radius.circular(20),
                                      bottomRight: Radius.circular(4),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getUploadIcon(_uploadingFileType),
                                            size: 20,
                                            color: colorScheme.onPrimaryContainer,
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            constraints: const BoxConstraints(maxWidth: 180),
                                            child: Text(
                                              _uploadingFileName ?? 'Uploading...',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _uploadingFileSize != null && _uploadingFileSize!.isNotEmpty
                                                ? '$_uploadingFileSize • ${(_uploadProgress * 100).toInt()}%'
                                                : '${(_uploadProgress * 100).toInt()}%',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              value: _uploadProgress,
                                              strokeWidth: 2.0,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                colorScheme.onPrimaryContainer,
                                              ),
                                              backgroundColor: colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _uploadCancelled = true;
                                                _isUploading = false;
                                              });
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Upload cancelled'),
                                                  duration: Duration(seconds: 2),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: 12,
                                                color: colorScheme.onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final int msgIndex = _isUploading ? index - 1 : index;
                            var message = messages[msgIndex].data() as Map<String, dynamic>;
                            String docId = messages[msgIndex].id;
                            bool isMe = message['senderId'] == _auth.currentUser!.uid;
                            bool isRead = message['isRead'] ?? false;
                            String timeText = _formatTime(message['timestamp'] as Timestamp?);

                            bool showDivider = false;
                            DateTime? currentDt = (message['timestamp'] as Timestamp?)?.toDate();
                            
                            if (msgIndex == messages.length - 1) {
                              showDivider = true;
                            } else {
                              var olderMsg = messages[msgIndex + 1].data() as Map<String, dynamic>;
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
                                    padding: (message['type'] == 'image' || message['type'] == 'video')
                                        ? const EdgeInsets.all(4)
                                        : const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
                                    child: _buildMessageBubbleBody(
                                      message: message,
                                      isMe: isMe,
                                      colorScheme: colorScheme,
                                      timeText: timeText,
                                      isRead: isRead,
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
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentItem(
                  icon: Icons.image_rounded,
                  label: 'Image',
                  color: Colors.purple,
                  onTap: _sendPhoto,
                ),
                _buildAttachmentItem(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  color: Colors.red,
                  onTap: _sendVideo,
                ),
                _buildAttachmentItem(
                  icon: Icons.audiotrack_rounded,
                  label: 'Audio',
                  color: Colors.orange,
                  onTap: _sendAudio,
                ),
                _buildAttachmentItem(
                  icon: Icons.description_rounded,
                  label: 'Document',
                  color: Colors.blue,
                  onTap: _sendDocument,
                ),
                _buildAttachmentItem(
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  color: Colors.teal,
                  onTap: _sendLocation,
                ),
              ],
            ),
          ),
          crossFadeState: _isAttachmentMenuOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
          sizeCurve: Curves.easeInOut,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: SafeArea(
            child: Row(
              children: [
                 AnimatedRotation(
                  turns: _isAttachmentMenuOpen ? 0.125 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: _isAttachmentMenuOpen
                          ? colorScheme.error.withValues(alpha: 0.1)
                          : colorScheme.primary.withValues(alpha: 0.1),
                      shape: const CircleBorder(),
                    ),
                    icon: huge.HugeIcon(
                      icon: huge.HugeIcons.strokeRoundedAdd01,
                      color: _isAttachmentMenuOpen ? colorScheme.error : colorScheme.primary,
                      size: 24,
                      strokeWidth: 3.0,
                    ),
                    onPressed: () {
                      setState(() {
                        _isAttachmentMenuOpen = !_isAttachmentMenuOpen;
                        if (_isAttachmentMenuOpen) {
                          _showEmojiPicker = false;
                          _focusNode.unfocus();
                        }
                      });
                    },
                  ),
                ),
                SizedBox(width: 10,),
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
                              _isAttachmentMenuOpen = false;
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

  Widget _buildAttachmentItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (bytes > 0) ? (bytes / 1024).floor().toString().length ~/ 3 : 0;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double size = bytes / (1 << (10 * i));
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _startDownload(String url, String fileType) async {
    if (kIsWeb) return;
    setState(() {
      _downloadProgress[url] = 0.0;
    });

    final path = await LocalStorageService.downloadAndSaveFile(
      url,
      fileType,
      (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress[url] = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _downloadProgress.remove(url);
        if (path != null) {
          _localFilePaths[url] = path;
        }
      });
      if (path == null) {
        _showErrorSnackBar('Download failed');
      }
    }
  }

  IconData _getUploadIcon(String? type) {
    switch (type) {
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.video_library_rounded;
      case 'audio':
        return Icons.audiotrack_rounded;
      case 'document':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String? _getVideoThumbnailUrl(String videoUrl) {
    if (videoUrl.startsWith('http://')) {
      videoUrl = 'https://' + videoUrl.substring(7);
    }
    if (videoUrl.contains('res.cloudinary.com')) {
      final int lastDot = videoUrl.lastIndexOf('.');
      if (lastDot != -1) {
        return videoUrl.substring(0, lastDot) + '.jpg';
      }
    }
    return null;
  }

  Widget _buildVideoPlaceholderFallback(ColorScheme colorScheme, String fileName, String fileSize) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_rounded, size: 40, color: Colors.red),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                fileSize.isNotEmpty ? '$fileName • $fileSize' : fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendPhoto() async {
    if (_isUploading) return;
    setState(() {
      _isAttachmentMenuOpen = false;
    });

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      Uint8List bytes = await image.readAsBytes();
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name.replaceAll(' ', '_')}';
      
      setState(() {
        _isUploading = true;
        _uploadCancelled = false;
        _uploadingFileName = image.name;
        _uploadingFileSize = _formatFileSize(bytes.length);
        _uploadingFileType = 'image';
        _uploadProgress = 0.0;
      });

      String? localPath;
      if (!kIsWeb) {
        localPath = await LocalStorageService.saveFileLocally(fileName, bytes, 'image');
      }

      final uploadResult = await CloudinaryService.uploadFile(
        fileBytes: bytes,
        folderPath: 'cuqter_media/Photo',
        fileName: fileName,
        resourceType: 'image',
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      if (_uploadCancelled) return;

      if (uploadResult != null && uploadResult['url'] != null) {
        final String fileUrl = uploadResult['url']!;
        if (localPath != null) {
          _localFilePaths[fileUrl] = localPath;
        }
        String chatId = getChatId(_auth.currentUser!.uid, widget.receiverId);
        await _messageService.sendMessage(
          chatId: chatId,
          senderId: _auth.currentUser!.uid,
          receiverId: widget.receiverId,
          text: '$fileUrl|${_formatFileSize(bytes.length)}',
          type: 'image',
        );
      } else {
        if (!_uploadCancelled) {
          _showErrorSnackBar('Failed to upload photo to Cloudinary');
        }
      }
    } catch (e) {
      if (!_uploadCancelled) {
        _showErrorSnackBar('Error sending photo: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _sendVideo() async {
    if (_isUploading) return;
    setState(() {
      _isAttachmentMenuOpen = false;
    });

    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    try {
      Uint8List bytes = await video.readAsBytes();
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${video.name.replaceAll(' ', '_')}';

      setState(() {
        _isUploading = true;
        _uploadCancelled = false;
        _uploadingFileName = video.name;
        _uploadingFileSize = _formatFileSize(bytes.length);
        _uploadingFileType = 'video';
        _uploadProgress = 0.0;
      });

      String? localPath;
      if (!kIsWeb) {
        localPath = await LocalStorageService.saveFileLocally(fileName, bytes, 'video');
      }

      final uploadResult = await CloudinaryService.uploadFile(
        fileBytes: bytes,
        folderPath: 'cuqter_media/Video',
        fileName: fileName,
        resourceType: 'video',
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      if (_uploadCancelled) return;

      if (uploadResult != null && uploadResult['url'] != null) {
        final String fileUrl = uploadResult['url']!;
        if (localPath != null) {
          _localFilePaths[fileUrl] = localPath;
        }
        String chatId = getChatId(_auth.currentUser!.uid, widget.receiverId);
        await _messageService.sendMessage(
          chatId: chatId,
          senderId: _auth.currentUser!.uid,
          receiverId: widget.receiverId,
          text: '$fileUrl|${_formatFileSize(bytes.length)}',
          type: 'video',
        );
      } else {
        if (!_uploadCancelled) {
          _showErrorSnackBar('Failed to upload video to Cloudinary');
        }
      }
    } catch (e) {
      if (!_uploadCancelled) {
        _showErrorSnackBar('Error sending video: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _sendAudio() async {
    if (_isUploading) return;
    setState(() {
      _isAttachmentMenuOpen = false;
    });

    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.audio,
      );
      if (result == null) return;

      PlatformFile file = result.files.first;
      final Uint8List bytes;
      if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        bytes = await file.readAsBytes();
      }

      final fileBytes = bytes;

      setState(() {
        _isUploading = true;
        _uploadCancelled = false;
        _uploadingFileName = file.name;
        _uploadingFileSize = _formatFileSize(fileBytes.length);
        _uploadingFileType = 'audio';
        _uploadProgress = 0.0;
      });

      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(' ', '_')}';
      
      String? localPath;
      if (!kIsWeb) {
        localPath = await LocalStorageService.saveFileLocally(fileName, fileBytes, 'audio');
      }

      final uploadResult = await CloudinaryService.uploadFile(
        fileBytes: fileBytes,
        folderPath: 'cuqter_media/Audio',
        fileName: fileName,
        resourceType: 'video',
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      if (_uploadCancelled) return;

      if (uploadResult != null && uploadResult['url'] != null) {
        final String fileUrl = uploadResult['url']!;
        if (localPath != null) {
          _localFilePaths[fileUrl] = localPath;
        }
        String chatId = getChatId(_auth.currentUser!.uid, widget.receiverId);
        await _messageService.sendMessage(
          chatId: chatId,
          senderId: _auth.currentUser!.uid,
          receiverId: widget.receiverId,
          text: '$fileUrl|${_formatFileSize(fileBytes.length)}',
          type: 'audio',
        );
      } else {
        if (!_uploadCancelled) {
          _showErrorSnackBar('Failed to upload audio to Cloudinary');
        }
      }
    } catch (e) {
      if (!_uploadCancelled) {
        _showErrorSnackBar('Error sending audio: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _sendDocument() async {
    if (_isUploading) return;
    setState(() {
      _isAttachmentMenuOpen = false;
    });

    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (result == null) return;

      PlatformFile file = result.files.first;
      final Uint8List bytes;
      if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        bytes = await file.readAsBytes();
      }

      final fileBytes = bytes;

      setState(() {
        _isUploading = true;
        _uploadCancelled = false;
        _uploadingFileName = file.name;
        _uploadingFileSize = _formatFileSize(fileBytes.length);
        _uploadingFileType = 'document';
        _uploadProgress = 0.0;
      });

      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(' ', '_')}';

      String? localPath;
      if (!kIsWeb) {
        localPath = await LocalStorageService.saveFileLocally(fileName, fileBytes, 'document');
      }

      final uploadResult = await CloudinaryService.uploadFile(
        fileBytes: fileBytes,
        folderPath: 'cuqter_media/Document',
        fileName: fileName,
        resourceType: 'auto',
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      if (_uploadCancelled) return;

      if (uploadResult != null && uploadResult['url'] != null) {
        final String fileUrl = uploadResult['url']!;
        if (localPath != null) {
          _localFilePaths[fileUrl] = localPath;
        }
        String chatId = getChatId(_auth.currentUser!.uid, widget.receiverId);
        await _messageService.sendMessage(
          chatId: chatId,
          senderId: _auth.currentUser!.uid,
          receiverId: widget.receiverId,
          text: '$fileUrl|${_formatFileSize(fileBytes.length)}',
          type: 'document',
        );
      } else {
        if (!_uploadCancelled) {
          _showErrorSnackBar('Failed to upload document to Cloudinary');
        }
      }
    } catch (e) {
      if (!_uploadCancelled) {
        _showErrorSnackBar('Error sending document: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _sendLocation() async {
    setState(() {
      _isAttachmentMenuOpen = false;
    });

    try {
      // Request and check location permission on all platforms (including web)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('Location permission denied. Please allow location access.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!kIsWeb) {
          // On mobile, guide user to app settings
          _showErrorSnackBar('Location permission permanently denied. Please enable it in app settings.');
          await Geolocator.openAppSettings();
        } else {
          _showErrorSnackBar('Location permission is blocked. Please allow location in your browser settings.');
        }
        return;
      }

      if (!kIsWeb) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _showErrorSnackBar('Location services are disabled. Please enable GPS.');
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      String chatId = getChatId(_auth.currentUser!.uid, widget.receiverId);
      await _messageService.sendMessage(
        chatId: chatId,
        senderId: _auth.currentUser!.uid,
        receiverId: widget.receiverId,
        text: '${position.latitude},${position.longitude}',
        type: 'location',
      );
    } catch (e) {
      _showErrorSnackBar('Error getting location: $e');
    }
  }

  String _getFileNameFromUrl(String url) {
    try {
      String decoded = Uri.decodeFull(url);
      String filename = decoded.split('/').last.split('?').first;

      // Clean up double extensions if any (e.g. "my_video.mp4.mp4" -> "my_video.mp4")
      final List<String> parts = filename.split('.');
      if (parts.length > 2 && parts[parts.length - 1].toLowerCase() == parts[parts.length - 2].toLowerCase()) {
        filename = parts.sublist(0, parts.length - 1).join('.');
      }

      final int underscoreIdx = filename.indexOf('_');
      if (underscoreIdx != -1 && underscoreIdx < 15) {
        final prefix = filename.substring(0, underscoreIdx);
        if (RegExp(r'^\d+$').hasMatch(prefix)) {
          return filename.substring(underscoreIdx + 1);
        }
      }
      return filename;
    } catch (_) {
      return 'Shared File';
    }
  }

  Widget _buildDownloadPlaceholder({
    required ColorScheme colorScheme,
    required String url,
    required String fileType,
    required String fileName,
    required String fileSize,
    required bool isMe,
  }) {
    final bool isDownloading = _downloadProgress.containsKey(url);
    final double progress = _downloadProgress[url] ?? 0.0;

    IconData typeIcon;
    switch (fileType) {
      case 'image':
        typeIcon = Icons.image_rounded;
        break;
      case 'video':
        typeIcon = Icons.video_library_rounded;
        break;
      case 'audio':
        typeIcon = Icons.audiotrack_rounded;
        break;
      default:
        typeIcon = Icons.description_rounded;
    }

    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe 
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe 
              ? colorScheme.primary.withValues(alpha: 0.15) 
              : colorScheme.outlineVariant.withValues(alpha: 0.5)
        ),
      ),
      child: Row(
        children: [
          isDownloading
              ? SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3.0,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMe ? colorScheme.onPrimaryContainer : colorScheme.primary,
                        ),
                        backgroundColor: (isMe ? colorScheme.onPrimaryContainer : colorScheme.primary).withValues(alpha: 0.2),
                      ),
                      Text(
                        '${(progress * 100).toInt()}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isMe ? colorScheme.onPrimaryContainer : colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isMe ? colorScheme.onPrimaryContainer : colorScheme.primary).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    typeIcon, 
                    color: isMe ? colorScheme.onPrimaryContainer : colorScheme.primary, 
                    size: 20
                  ),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fileSize.isNotEmpty ? fileSize : 'Media File',
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe 
                        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isDownloading)
            IconButton(
              icon: Icon(
                Icons.download_rounded, 
                color: isMe ? colorScheme.onPrimaryContainer : colorScheme.primary
              ),
              onPressed: () => _startDownload(url, fileType),
            ),
        ],
      ),
    );
  }

  Future<void> _openLocalFile(String localPath) async {
    try {
      final Uri fileUri = Uri.file(localPath);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('No application found to open this file. Path: $localPath');
      }
    } catch (e) {
      _showErrorSnackBar('Error opening file: $e');
    }
  }

  Widget _buildDownloadPlaceholderCard(
    String url,
    String fileType,
    String fileSize,
    ColorScheme colorScheme,
    bool isMe,
    String timeText,
    bool isRead,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDownloadPlaceholder(
          colorScheme: colorScheme,
          url: url,
          fileType: fileType,
          fileName: _getFileNameFromUrl(url),
          fileSize: fileSize,
          isMe: isMe,
        ),
        const SizedBox(height: 4),
        _buildTimeAndStatusRow(isMe, colorScheme, timeText, isRead, isOverMedia: false),
      ],
    );
  }

  Widget _buildLocalImageBubble(String localPath, ColorScheme colorScheme, String timeText, bool isMe, bool isRead, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenProfilePicPage(
                  imageUrl: localPath,
                  heroTag: text,
                ),
              ),
            );
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 300,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Hero(
                tag: text,
                child: Image.file(
                  File(localPath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 100,
                      color: colorScheme.surfaceContainerHighest,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Failed to load cached image'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _buildTimeAndStatusRow(isMe, colorScheme, timeText, isRead, isOverMedia: true),
      ],
    );
  }

  Widget _buildLocalVideoBubble(String localPath, ColorScheme colorScheme, String timeText, bool isMe, bool isRead, String text, String fileName, String fileSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenVideoPage(
                  videoUrl: text,
                  localFilePath: localPath,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  color: colorScheme.surfaceContainerHighest,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_getVideoThumbnailUrl(text) != null)
                        Image.network(
                          Uri.encodeFull(Uri.decodeFull(_getVideoThumbnailUrl(text)!)),
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildVideoPlaceholderFallback(colorScheme, fileName, fileSize);
                          },
                        )
                      else
                        _buildVideoPlaceholderFallback(colorScheme, fileName, fileSize),
                      Container(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        right: 12,
                        child: Text(
                          fileSize.isNotEmpty ? '$fileName • $fileSize' : fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        _buildTimeAndStatusRow(isMe, colorScheme, timeText, isRead, isOverMedia: true),
      ],
    );
  }

  Widget _buildLocalAudioBubble(String localPath, ColorScheme colorScheme, String timeText, bool isMe, bool isRead, String fileName, String fileSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            _openLocalFile(localPath);
          },
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileSize.isNotEmpty ? 'Cached Audio • $fileSize' : 'Cached Audio Message',
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe
                            ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                            : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _buildTimeAndStatusRow(isMe, colorScheme, timeText, isRead),
      ],
    );
  }

  Widget _buildLocalDocumentBubble(String localPath, ColorScheme colorScheme, String timeText, bool isMe, bool isRead, String fileName, String fileSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            _openLocalFile(localPath);
          },
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.description_rounded, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileSize.isNotEmpty ? 'Cached Document • $fileSize' : 'Cached Document',
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe
                            ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                            : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _buildTimeAndStatusRow(isMe, colorScheme, timeText, isRead),
      ],
    );
  }

  // ── Network / Remote bubble builders (no local copy) ──────────────────────

  /// Like WhatsApp: images load from network automatically
  Widget _buildNetworkImageBubble(String url, ColorScheme colorScheme, String timeText, bool isMe, bool isRead) {
    final String safeUrl = Uri.encodeFull(Uri.decodeFull(
      url.startsWith('http://') ? 'https://' + url.substring(7) : url,
    ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenProfilePicPage(
                  imageUrl: url,
                  heroTag: url,
                ),
              ),
            );
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Hero(
                tag: url,
                child: CachedNetworkImage(
                  imageUrl: safeUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 100,
                    color: colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _buildTimeAndStatusRow(isMe, colorScheme, timeText, isRead, isOverMedia: true),
      ],
    );
  }



  Widget _buildWebImageBubble(String text, ColorScheme colorScheme, String timeText, bool isMe, bool isRead) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenProfilePicPage(
                  imageUrl: text,
                  heroTag: text,
                ),
              ),
            );
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 300,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Hero(
                tag: text,
                child: Image.network(
                  Uri.encodeFull(Uri.decodeFull(text.startsWith('http://') ? 'https://' + text.substring(7) : text)),
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 150,
                      color: colorScheme.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 100,
                      color: colorScheme.surfaceContainerHighest,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Failed to load image'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _buildTimeAndStatusRow(isMe, colorScheme, timeText, isRead, isOverMedia: true),
      ],
    );
  }

  Widget _buildWebVideoBubble(String text, String fileName, String fileSize, ColorScheme colorScheme, String timeText, bool isMe, bool isRead) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenVideoPage(
                  videoUrl: text,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  color: colorScheme.surfaceContainerHighest,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_getVideoThumbnailUrl(text) != null)
                        Image.network(
                          Uri.encodeFull(Uri.decodeFull(_getVideoThumbnailUrl(text)!)),
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildVideoPlaceholderFallback(colorScheme, fileName, fileSize);
                          },
                        )
                      else
                        _buildVideoPlaceholderFallback(colorScheme, fileName, fileSize),
                      Container(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        right: 12,
                        child: Text(
                          fileSize.isNotEmpty ? '$fileName • $fileSize' : fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        _buildTimeAndStatusRow(isMe, colorScheme, timeText, isRead, isOverMedia: true),
      ],
    );
  }

  Widget _buildWebAudioBubble(String text, String fileName, String fileSize, ColorScheme colorScheme, String timeText, bool isMe, bool isRead) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            _launchURL(text);
          },
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileSize.isNotEmpty ? 'Audio • $fileSize' : 'Audio Message',
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe
                            ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                            : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _buildTimeAndStatusRow(isMe, colorScheme, timeText, isRead),
      ],
    );
  }

  Widget _buildWebDocumentBubble(String text, String fileName, String fileSize, ColorScheme colorScheme, String timeText, bool isMe, bool isRead) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            _launchURL(text);
          },
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.description_rounded, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileSize.isNotEmpty ? 'Document • $fileSize' : 'Document',
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe
                            ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                            : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _buildTimeAndStatusRow(isMe, colorScheme, timeText, isRead),
      ],
    );
  }

  void _triggerFileCheck(String text, String type) {
    if (!_checkingFiles.contains(text)) {
      _checkingFiles.add(text);
      LocalStorageService.checkFileExists(text, type).then((path) {
        if (mounted) {
          setState(() {
            _localFilePaths[text] = path;
            _checkingFiles.remove(text);
          });
        }
      });
    }
  }

  Widget _buildMessageBubbleBody({
    required Map<String, dynamic> message,
    required bool isMe,
    required ColorScheme colorScheme,
    required String timeText,
    required bool isRead,
  }) {
    final String type = message['type'] ?? 'text';
    final String rawText = message['text'] ?? '';
    final List<String> parts = rawText.split('|');
    final String text = parts[0];
    final String fileSize = parts.length > 1 ? parts[1] : '';

    switch (type) {
      case 'image':
        if (kIsWeb) {
          return _buildWebImageBubble(text, colorScheme, timeText, isMe, isRead);
        }
        final bool isDownloadingImage = _downloadProgress.containsKey(text);
        if (isDownloadingImage) {
          return _buildDownloadPlaceholderCard(text, 'image', fileSize, colorScheme, isMe, timeText, isRead);
        }
        if (_localFilePaths.containsKey(text)) {
          final String? localPath = _localFilePaths[text];
          if (localPath != null) {
            return _buildLocalImageBubble(localPath, colorScheme, timeText, isMe, isRead, text);
          } else {
            return _buildNetworkImageBubble(text, colorScheme, timeText, isMe, isRead);
          }
        }
        _triggerFileCheck(text, 'image');
        return _buildNetworkImageBubble(text, colorScheme, timeText, isMe, isRead);

      case 'video':
        String fileName = _getFileNameFromUrl(text);
        if (kIsWeb) {
          return _buildWebVideoBubble(text, fileName, fileSize, colorScheme, timeText, isMe, isRead);
        }
        final bool isDownloadingVideo = _downloadProgress.containsKey(text);
        if (isDownloadingVideo) {
          return _buildDownloadPlaceholderCard(text, 'video', fileSize, colorScheme, isMe, timeText, isRead);
        }
        if (_localFilePaths.containsKey(text)) {
          final String? localPath = _localFilePaths[text];
          if (localPath != null) {
            return _buildLocalVideoBubble(localPath, colorScheme, timeText, isMe, isRead, text, fileName, fileSize);
          } else {
            return _buildDownloadPlaceholderCard(text, 'video', fileSize, colorScheme, isMe, timeText, isRead);
          }
        }
        _triggerFileCheck(text, 'video');
        return _buildDownloadPlaceholderCard(text, 'video', fileSize, colorScheme, isMe, timeText, isRead);

      case 'audio':
        String fileName = _getFileNameFromUrl(text);
        if (kIsWeb) {
          return _buildWebAudioBubble(text, fileName, fileSize, colorScheme, timeText, isMe, isRead);
        }
        final bool isDownloadingAudio = _downloadProgress.containsKey(text);
        if (isDownloadingAudio) {
          return _buildDownloadPlaceholderCard(text, 'audio', fileSize, colorScheme, isMe, timeText, isRead);
        }
        if (_localFilePaths.containsKey(text)) {
          final String? localPath = _localFilePaths[text];
          if (localPath != null) {
            return _buildLocalAudioBubble(localPath, colorScheme, timeText, isMe, isRead, fileName, fileSize);
          } else {
            return _buildDownloadPlaceholderCard(text, 'audio', fileSize, colorScheme, isMe, timeText, isRead);
          }
        }
        _triggerFileCheck(text, 'audio');
        return _buildDownloadPlaceholderCard(text, 'audio', fileSize, colorScheme, isMe, timeText, isRead);

      case 'document':
        String fileName = _getFileNameFromUrl(text);
        if (kIsWeb) {
          return _buildWebDocumentBubble(text, fileName, fileSize, colorScheme, timeText, isMe, isRead);
        }
        final bool isDownloadingDocument = _downloadProgress.containsKey(text);
        if (isDownloadingDocument) {
          return _buildDownloadPlaceholderCard(text, 'document', fileSize, colorScheme, isMe, timeText, isRead);
        }
        if (_localFilePaths.containsKey(text)) {
          final String? localPath = _localFilePaths[text];
          if (localPath != null) {
            return _buildLocalDocumentBubble(localPath, colorScheme, timeText, isMe, isRead, fileName, fileSize);
          } else {
            return _buildDownloadPlaceholderCard(text, 'document', fileSize, colorScheme, isMe, timeText, isRead);
          }
        }
        _triggerFileCheck(text, 'document');
        return _buildDownloadPlaceholderCard(text, 'document', fileSize, colorScheme, isMe, timeText, isRead);

      case 'location':
        List<String> latLng = text.split(',');
        String displayCoords = text;
        if (latLng.length == 2) {
          displayCoords = '${double.tryParse(latLng[0])?.toStringAsFixed(4) ?? latLng[0]}, ${double.tryParse(latLng[1])?.toStringAsFixed(4) ?? latLng[1]}';
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                _launchLocation(text);
              },
              borderRadius: BorderRadius.circular(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 260,
                  decoration: BoxDecoration(
                    color: isMe 
                        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: Border.all(
                      color: isMe 
                          ? colorScheme.primary.withValues(alpha: 0.15) 
                          : colorScheme.outlineVariant.withValues(alpha: 0.5)
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (latLng.length == 2)
                        SizedBox(
                          height: 150,
                          width: double.infinity,
                          child: Image.network(
                            'https://static-maps.yandex.ru/1.x/?ll=${latLng[1].trim()},${latLng[0].trim()}&z=15&l=map&size=450,250&pt=${latLng[1].trim()},${latLng[0].trim()},pm2rdm',
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.map_rounded, size: 36, color: colorScheme.primary.withValues(alpha: 0.5)),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Map Preview Unavailable',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on_rounded, color: Colors.teal, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Shared Location',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    displayCoords,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isMe 
                                          ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _buildTimeAndStatusRow(isMe, colorScheme, timeText, isRead, isOverMedia: false),
          ],
        );

      case 'text':
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ChatMessageText(
              text: text,
              baseStyle: TextStyle(
                fontSize: _fontSize,
                color: isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
              ),
              linkColor: isMe ? colorScheme.onPrimary : colorScheme.primary,
            ),
            const SizedBox(height: 4),
            _buildTimeAndStatusRow(isMe, colorScheme, timeText, isRead),
          ],
        );
    }
  }

  Widget _buildTimeAndStatusRow(
    bool isMe,
    ColorScheme colorScheme,
    String timeText,
    bool isRead, {
    bool isOverMedia = false,
  }) {
    final Color textColor = isOverMedia
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
        : (isMe
            ? colorScheme.onPrimaryContainer.withValues(alpha: 0.6)
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.6));

    return Padding(
      padding: isOverMedia ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4) : EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timeText,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 4),
            Icon(
              isRead ? Icons.done_all_rounded : Icons.done_rounded,
              size: 14,
              color: isRead ? Colors.blue : textColor,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('Could not launch URL');
    }
  }

  Future<void> _launchLocation(String latLngString) async {
    final Uri uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latLngString');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('Could not launch maps');
    }
  }
}

class ZigZagLoading extends StatefulWidget {
  const ZigZagLoading({Key? key}) : super(key: key);

  @override
  _ZigZagLoadingState createState() => _ZigZagLoadingState();
}

class _ZigZagLoadingState extends State<ZigZagLoading> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: -12).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    // Start staggered animation loop
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Uploading',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _animations[index],
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _animations[index].value),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class ZigZagLoadingDotsOnly extends StatefulWidget {
  final Color color;
  const ZigZagLoadingDotsOnly({Key? key, required this.color}) : super(key: key);

  @override
  _ZigZagLoadingDotsOnlyState createState() => _ZigZagLoadingDotsOnlyState();
}

class _ZigZagLoadingDotsOnlyState extends State<ZigZagLoadingDotsOnly> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[index].value),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
