import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cuqter/Screen/chat_screen.dart';
import 'package:cuqter/Screen/profile_screen.dart';
import 'package:cuqter/Screen/settings_page.dart';
import 'package:cuqter/resources/auth_method.dart';
import 'package:cuqter/services/message_service.dart';
import 'package:cuqter/modules/message.dart';
import 'package:cuqter/modules/status.dart';
import 'package:cuqter/services/status_service.dart';
import 'package:cuqter/Screen/create_status_screen.dart';
import 'package:cuqter/Screen/status_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:cuqter/widgets/full_screen_profile_pic_page.dart';
import 'package:cuqter/Screen/notification_screen.dart';
import 'package:cuqter/Screen/search_screen.dart';
import 'package:cuqter/Screen/contact_screen.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class Homepage extends StatefulWidget {
  final bool isDesktop;
  final String? selectedUserId;
  final Function(String userId, String userName)? onChatSelected;

  const Homepage({
    super.key,
    this.isDesktop = false,
    this.selectedUserId,
    this.onChatSelected,
  });

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  String username = "";
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MessageService _messageService = MessageService();
  String searchQuery = "";
  Stream<DocumentSnapshot>? _currentUserStream;
  Stream<QuerySnapshot>? _usersStream;
  final Map<String, Stream<int>> _unreadCountStreams = {};
  final Map<String, Message?> _lastMessages = {};
  final Map<String, StreamSubscription<Message?>> _lastMessageSubscriptions =
      {};
  Stream<List<Status>>? _statusesStream;
  bool _isSelectionMode = false;
  final Set<String> _selectedUserIds = {};
  bool _isLoading = false;
  final StatusService _statusService = StatusService();
  StreamSubscription? _intentSub;
  List<SharedMediaFile> _sharedFiles = [];

  @override
  void initState() {
    super.initState();
    getUsername();
    if (_auth.currentUser != null) {
      _currentUserStream = _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .snapshots();
    }
    _usersStream = _firestore.collection('users').snapshots();
    _statusesStream = _statusService.getActiveStatuses();

    // Listen to media sharing incoming intents when app is in memory
    if (!kIsWeb) {
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> value) {
          if (value.isNotEmpty) _handleIncomingSharing(value);
        },
        onError: (err) {
          print("getIntentDataStream error: $err");
        },
      );

      // Get the media sharing incoming intent when app is closed
      ReceiveSharingIntent.instance.getInitialMedia().then((
        List<SharedMediaFile> value,
      ) {
        if (value.isNotEmpty) _handleIncomingSharing(value);
      });
    }
  }

  void _handleIncomingSharing(List<SharedMediaFile> value) {
    ReceiveSharingIntent.instance.reset(); // Reset to avoid duplicate handling
    _showShareBottomSheet(value);
  }

  void _showShareBottomSheet(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Share to...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.history_edu,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text('My Status'),
                onTap: () {
                  Navigator.pop(context);
                  final media = files.first;
                  final path = media.path;
                  final isVideo = media.type == SharedMediaType.video;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateStatusScreen(
                        sharedMediaPath: path,
                        isSharedMediaVideo: isVideo,
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.chat_bubble,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                title: const Text('A Chat'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _sharedFiles = files;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Received ${files.length} file(s). Select a chat below to share.',
                      ),
                      duration: const Duration(seconds: 4),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Stream<int> _getUnreadCountStream(String chatId, String currentUserId) {
    return _unreadCountStreams.putIfAbsent(
      chatId,
      () => _messageService.getUnreadMessageCountStream(chatId, currentUserId),
    );
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    for (var sub in _lastMessageSubscriptions.values) {
      sub.cancel();
    }
    _lastMessageSubscriptions.clear();
    super.dispose();
  }

  void getUsername() async {
    try {
      var snap = await AuthMethod().getUserDetails();
      if (snap.exists && snap.data() != null) {
        setState(() {
          username = (snap.data() as Map<String, dynamic>)['name'] ?? '';
        });
      }
    } catch (e) {
      print(e.toString());
    }
  }

  String getChatId(String uid1, String uid2) {
    if (uid1.compareTo(uid2) > 0) {
      return '${uid1}_$uid2';
    } else {
      return '${uid2}_$uid1';
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return TimeOfDay.fromDateTime(dateTime).format(context);
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    }
  }

  String _getLastMessageDisplay(Message message) {
    final String type = message.type;
    final String text = message.text.split('|').first;

    if (type == 'image') return '📷 Photo';
    if (type == 'video') return '🎥 Video';
    if (type == 'audio') return '🎵 Audio';
    if (type == 'document') return '📄 Document';
    if (type == 'location') return '📍 Location';
    if (type == 'video_call') return '📹 Video Call';
    if (type == 'voice_call') return '📞 Voice Call';

    // Fallback URL checking for legacy messages
    if (text.startsWith('http') &&
        (text.contains('cloudinary.com') ||
            text.contains('firebasestorage.googleapis.com'))) {
      final String lowerText = text.toLowerCase();
      if (lowerText.contains('cuqter_media/photo') ||
          lowerText.contains('/image/upload')) {
        return '📷 Photo';
      }
      if (lowerText.contains('cuqter_media/video')) {
        return '🎥 Video';
      }
      if (lowerText.contains('cuqter_media/audio')) {
        return '🎵 Audio';
      }
      if (lowerText.contains('cuqter_media/document') ||
          lowerText.contains('/raw/upload')) {
        return '📄 Document';
      }

      // Fallback by extension parsing from URL path
      try {
        final String uriPath = Uri.parse(text).path.toLowerCase();
        if (uriPath.endsWith('.mp3') ||
            uriPath.endsWith('.m4a') ||
            uriPath.endsWith('.wav') ||
            uriPath.endsWith('.ogg')) {
          return '🎵 Audio';
        }
        if (uriPath.endsWith('.mp4') ||
            uriPath.endsWith('.mov') ||
            uriPath.endsWith('.avi') ||
            uriPath.endsWith('.mkv') ||
            uriPath.endsWith('.3gp')) {
          return '🎥 Video';
        }
        if (uriPath.endsWith('.jpg') ||
            uriPath.endsWith('.jpeg') ||
            uriPath.endsWith('.png') ||
            uriPath.endsWith('.webp') ||
            uriPath.endsWith('.gif')) {
          return '📷 Photo';
        }
        if (uriPath.endsWith('.pdf') ||
            uriPath.endsWith('.doc') ||
            uriPath.endsWith('.docx') ||
            uriPath.endsWith('.xls') ||
            uriPath.endsWith('.xlsx') ||
            uriPath.endsWith('.txt')) {
          return '📄 Document';
        }
      } catch (_) {}

      // Default type by Cloudinary resource folders
      if (lowerText.contains('/video/upload')) {
        return '🎥 Video'; // General video upload path fallback (includes audio)
      }
      return '📄 Shared File';
    }

    return text;
  }

  Future<void> _pinChat(String otherUserId) async {
    final String currentUserId = _auth.currentUser!.uid;
    final userDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .get();

    List<dynamic> pinnedChats = [];
    if (userDoc.exists) {
      final data = userDoc.data();
      if (data != null && data.containsKey('pinnedChats')) {
        pinnedChats = List.from(data['pinnedChats'] as List<dynamic>);
      }
    }

    // Toggle Pin: if already pinned, unpin it
    if (pinnedChats.contains(otherUserId)) {
      pinnedChats.remove(otherUserId);
    } else {
      // Pin it: insert at the beginning (LIFO / top)
      pinnedChats.insert(0, otherUserId);
      // Keep only up to 3 pins
      if (pinnedChats.length > 3) {
        pinnedChats = pinnedChats.sublist(0, 3);
      }
    }

    await _firestore.collection('users').doc(currentUserId).update({
      'pinnedChats': pinnedChats,
    });
  }

  Future<void> _deleteChat(String otherUserId) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String chatId = getChatId(currentUserId, otherUserId);

    // 1. Remove from contacts list on Firestore
    await _firestore.collection('users').doc(currentUserId).update({
      'contacts': FieldValue.arrayRemove([otherUserId]),
    });

    // 2. Delete messages subcollection
    final messagesSnapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (var doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Also delete the main chat document
    batch.delete(_firestore.collection('chats').doc(chatId));
    await batch.commit();
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete conversations?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete the selected ${_selectedUserIds.length} chat(s) and all their messages? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
              });
              try {
                for (var userId in _selectedUserIds) {
                  await _deleteChat(userId);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Selected chats deleted successfully'),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete chats: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              } finally {
                setState(() {
                  _isLoading = false;
                  _isSelectionMode = false;
                  _selectedUserIds.clear();
                });
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        top: !widget.isDesktop,
        bottom: false,
        child: Column(
          children: [
            if (_isLoading) const LinearProgressIndicator(),
            // Custom Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: _isSelectionMode
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: huge.HugeIcon(
                                icon: huge.HugeIcons.strokeRoundedCancel01,
                                color: colorScheme.onSurface,
                                size: 24,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isSelectionMode = false;
                                  _selectedUserIds.clear();
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedUserIds.length} Selected',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: huge.HugeIcon(
                                icon: huge.HugeIcons.strokeRoundedPin02,
                                color: colorScheme.onSurface,
                                size: 24,
                              ),
                              onPressed: () async {
                                for (var userId in _selectedUserIds) {
                                  await _pinChat(userId);
                                }
                                setState(() {
                                  _isSelectionMode = false;
                                  _selectedUserIds.clear();
                                });
                              },
                            ),
                            IconButton(
                              icon: huge.HugeIcon(
                                icon: huge.HugeIcons.strokeRoundedDelete01,
                                color: colorScheme.error,
                                size: 24,
                              ),
                              onPressed: () {
                                _showDeleteConfirmDialog();
                              },
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cuqter',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                            letterSpacing: -1,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Notification icon
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        const NotificationScreen(),
                                    transitionsBuilder:
                                        (context, animation, secondaryAnimation, child) {
                                          return SlideTransition(
                                            position:
                                                Tween<Offset>(
                                                  begin: const Offset(1.0, 0.0),
                                                  end: Offset.zero,
                                                ).animate(
                                                  CurvedAnimation(
                                                    parent: animation,
                                                    curve: Curves.easeOutCubic,
                                                  ),
                                                ),
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          );
                                        },
                                    transitionDuration: const Duration(milliseconds: 250),
                                  ),
                                );
                              },
                              icon: AnimatedNotificationBell(
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // More vert popup menu
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'settings') {
                                  if (widget.isDesktop) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        clipBehavior: Clip.antiAlias,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: SizedBox(
                                          width: 500,
                                          height: 650,
                                          child: Navigator(
                                            onGenerateRoute: (settings) =>
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const SettingsPage(
                                                        isDialog: true,
                                                      ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                            ) => const SettingsPage(),
                                        transitionsBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                              child,
                                            ) {
                                              return FadeTransition(
                                                opacity: animation,
                                                child: child,
                                              );
                                            },
                                      ),
                                    );
                                  }
                                }
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              color: colorScheme.surfaceContainerHighest,
                              elevation: 8,
                              shadowColor: Colors.black.withValues(alpha: 0.2),
                              offset: const Offset(0, 44),
                              icon: huge.HugeIcon(
                                icon: huge.HugeIcons.strokeRoundedMoreVertical,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                                size: 24,
                              ),
                              itemBuilder: (context) => [
                                PopupMenuItem<String>(
                                  value: 'settings',
                                  height: 56,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondary
                                              .withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: huge.HugeIcon(
                                          icon: huge
                                              .HugeIcons
                                              .strokeRoundedSettings01,
                                          color: colorScheme.secondary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Text(
                                        'Settings',
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: TextField(
                readOnly: true,
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const SearchScreen(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position:
                                    Tween<Offset>(
                                      begin: const Offset(0.0, 0.05),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    ),
                                child: child,
                              ),
                            );
                          },
                      transitionDuration: const Duration(milliseconds: 250),
                    ),
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (!widget.isDesktop) ...[
              // Status List
              _buildStatusList(context),

              Container(
                height: 6,
                margin: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],

            // Chat List
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _currentUserStream ?? const Stream.empty(),
                builder: (context, userSnapshot) {
                  List<dynamic> myContacts = [];
                  List<dynamic> pinnedChats = [];
                  if (userSnapshot.hasData &&
                      userSnapshot.data?.exists == true) {
                    var myData =
                        userSnapshot.data!.data() as Map<String, dynamic>?;
                    if (myData != null) {
                      myContacts = myData['contacts'] as List<dynamic>? ?? [];
                      pinnedChats =
                          myData['pinnedChats'] as List<dynamic>? ?? [];
                    }
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: _usersStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      var users =
                          snapshot.data?.docs.where((doc) {
                            if (_auth.currentUser == null) return false;
                            if (doc.id == _auth.currentUser!.uid) return false;

                            if (searchQuery.isNotEmpty) {
                              var data = doc.data() as Map<String, dynamic>?;
                              String username = (data?['username'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              return username.contains(searchQuery);
                            }
                            return myContacts.contains(doc.id);
                          }).toList() ??
                          [];

                      // Setup subscriptions for last messages if not already present
                      if (_auth.currentUser != null) {
                        for (var doc in users) {
                          String userId = doc.id;
                          String chatId = getChatId(
                            _auth.currentUser!.uid,
                            userId,
                          );
                          if (!_lastMessageSubscriptions.containsKey(chatId)) {
                            _lastMessageSubscriptions[chatId] = _messageService
                                .getLastMessage(chatId)
                                .listen((message) {
                                  if (mounted) {
                                    setState(() {
                                      _lastMessages[chatId] = message;
                                    });
                                  }
                                });
                          }
                        }
                      }

                      // Sort users: pinned chats at top (LIFO order), then others by message date
                      if (_auth.currentUser != null && users.isNotEmpty) {
                        users.sort((a, b) {
                          bool isPinnedA = pinnedChats.contains(a.id);
                          bool isPinnedB = pinnedChats.contains(b.id);

                          if (isPinnedA && isPinnedB) {
                            return pinnedChats
                                .indexOf(a.id)
                                .compareTo(pinnedChats.indexOf(b.id));
                          }
                          if (isPinnedA) return -1;
                          if (isPinnedB) return 1;

                          String chatIdA = getChatId(
                            _auth.currentUser!.uid,
                            a.id,
                          );
                          String chatIdB = getChatId(
                            _auth.currentUser!.uid,
                            b.id,
                          );
                          Message? msgA = _lastMessages[chatIdA];
                          Message? msgB = _lastMessages[chatIdB];

                          if (msgA == null && msgB == null) {
                            return a.id.compareTo(b.id);
                          }
                          if (msgA == null) return 1;
                          if (msgB == null) return -1;

                          return msgB.timestamp.compareTo(msgA.timestamp);
                        });
                      }

                      if (users.isEmpty) {
                        return Center(
                          child: Text(
                            'No messages yet',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        );
                      }

                      return Scrollbar(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 90),
                          cacheExtent: 1000.0,
                          physics: const BouncingScrollPhysics(),
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            var userData =
                                users[index].data() as Map<String, dynamic>;
                            String userName =
                                userData['name'] ?? 'Unknown User';
                            String userBio =
                                userData['bio'] ?? 'Stay cozy today!';
                            String userId = users[index].id;
                            bool isOnline = userData['isOnline'] ?? false;
                            String chatId = getChatId(
                              _auth.currentUser!.uid,
                              userId,
                            );

                            final lastMsg = _lastMessages[chatId];
                            final isLastMsgFromMe =
                                lastMsg != null &&
                                lastMsg.senderId == _auth.currentUser!.uid;
                            final subtitle = lastMsg != null
                                ? _getLastMessageDisplay(lastMsg)
                                : (userData['username'] != null &&
                                          userData['username']
                                              .toString()
                                              .isNotEmpty
                                      ? '@${userData['username']}'
                                      : userBio);
                            final timeText = lastMsg != null
                                ? _formatDateTime(lastMsg.timestamp)
                                : '';

                            final isSelected = _selectedUserIds.contains(
                              userId,
                            );
                            return InkWell(
                              onTap: () {
                                if (_isSelectionMode) {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedUserIds.remove(userId);
                                      if (_selectedUserIds.isEmpty) {
                                        _isSelectionMode = false;
                                      }
                                    } else {
                                      _selectedUserIds.add(userId);
                                    }
                                  });
                                } else {
                                  if (widget.isDesktop &&
                                      widget.onChatSelected != null) {
                                    widget.onChatSelected!(userId, userName);
                                  } else {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                            ) {
                                              final currentShared =
                                                  List<SharedMediaFile>.from(
                                                    _sharedFiles,
                                                  );
                                              if (currentShared.isNotEmpty) {
                                                Future.microtask(() {
                                                  if (mounted) {
                                                    setState(() {
                                                      _sharedFiles.clear();
                                                    });
                                                  }
                                                });
                                              }
                                              return ChatScreen(
                                                receiverId: userId,
                                                receiverName: userName,
                                                sharedMedia:
                                                    currentShared.isNotEmpty
                                                    ? currentShared
                                                    : null,
                                              );
                                            },
                                        transitionsBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                              child,
                                            ) {
                                              return SlideTransition(
                                                position:
                                                    Tween<Offset>(
                                                      begin: const Offset(
                                                        1.0,
                                                        0.0,
                                                      ),
                                                      end: Offset.zero,
                                                    ).animate(
                                                      CurvedAnimation(
                                                        parent: animation,
                                                        curve:
                                                            Curves.easeOutCubic,
                                                      ),
                                                    ),
                                                child: FadeTransition(
                                                  opacity: animation,
                                                  child: child,
                                                ),
                                              );
                                            },
                                        transitionDuration: const Duration(
                                          milliseconds: 250,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              onLongPress: () {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedUserIds.add(userId);
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 2.0,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (widget.selectedUserId == userId ||
                                          isSelected)
                                      ? colorScheme.primary.withValues(
                                          alpha: 0.1,
                                        )
                                      : Colors.transparent,
                                  border:
                                      (widget.selectedUserId == userId ||
                                          isSelected)
                                      ? Border.all(
                                          color: colorScheme.primary,
                                          width: 2,
                                        )
                                      : Border.all(
                                          color: Colors.transparent,
                                          width: 2,
                                        ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 10.0,
                                ),
                                child: Row(
                                  children: [
                                    // Avatar with status
                                    Stack(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            final pic =
                                                userData['profilepic']
                                                    ?.toString() ??
                                                '';
                                            if (pic.isNotEmpty) {
                                              if (widget.isDesktop) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => Dialog(
                                                    clipBehavior:
                                                        Clip.antiAlias,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            24,
                                                          ),
                                                    ),
                                                    child: SizedBox(
                                                      width: 400,
                                                      height: 600,
                                                      child: FullScreenProfilePicPage(
                                                        imageUrl: pic,
                                                        heroTag:
                                                            'profile_pic_hero_$userId',
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        FullScreenProfilePicPage(
                                                          imageUrl: pic,
                                                          heroTag:
                                                              'profile_pic_hero_$userId',
                                                        ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: Hero(
                                            tag: 'profile_pic_hero_$userId',
                                            child: CircleAvatar(
                                              radius: 28,
                                              backgroundColor:
                                                  colorScheme.primaryContainer,
                                              backgroundImage:
                                                  userData['profilepic'] !=
                                                          null &&
                                                      userData['profilepic']
                                                          .toString()
                                                          .isNotEmpty
                                                  ? (userData['profilepic']
                                                            .toString()
                                                            .startsWith('http')
                                                        ? CachedNetworkImageProvider(
                                                            userData['profilepic']
                                                                .toString(),
                                                          )
                                                        : AssetImage(
                                                                userData['profilepic']
                                                                    .toString(),
                                                              )
                                                              as ImageProvider)
                                                  : const AssetImage(
                                                      'assets/icon/default_profile.png',
                                                    ),
                                            ),
                                          ),
                                        ),
                                        if (isOnline)
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: colorScheme.surface,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  userName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (pinnedChats.contains(
                                                    userId,
                                                  )) ...[
                                                    huge.HugeIcon(
                                                      icon: huge
                                                          .HugeIcons
                                                          .strokeRoundedPin02,
                                                      color:
                                                          colorScheme.primary,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  Text(
                                                    timeText,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    if (isLastMsgFromMe) ...[
                                                      Icon(
                                                        lastMsg.isRead
                                                            ? Icons.done_all
                                                            : Icons.done,
                                                        size: 16,
                                                        color: lastMsg.isRead
                                                            ? Colors.blue
                                                            : colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.4,
                                                                  ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                    ],
                                                    Expanded(
                                                      child: Text(
                                                        subtitle,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          color: colorScheme
                                                              .onSurface
                                                              .withValues(
                                                                alpha: 0.6,
                                                              ),
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              StreamBuilder<int>(
                                                stream: _getUnreadCountStream(
                                                  chatId,
                                                  _auth.currentUser!.uid,
                                                ),
                                                builder: (context, unreadSnapshot) {
                                                  int count =
                                                      unreadSnapshot.data ?? 0;
                                                  if (count > 0 ||
                                                      userName == "Luv 🌺💕") {
                                                    // Demo match for screenshot
                                                    return Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                            left: 8,
                                                          ),
                                                      width: 10,
                                                      height: 10,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            colorScheme.primary,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    );
                                                  }
                                                  return const SizedBox.shrink();
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ); // return InkWell
                          }, // itemBuilder
                        ), // ListView.builder
                      ); // Scrollbar
                    }, // StreamBuilder builder
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.isDesktop
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 75),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'add_status_fab',
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const CreateStatusScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 250),
                        ),
                      );
                    },
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    child: huge.HugeIcon(
                      icon: huge.HugeIcons.strokeRoundedCamera01,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    heroTag: 'contacts_fab',
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const ContactScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: const Offset(1.0, 0.0),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        ),
                                      ),
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 250),
                        ),
                      );
                    },
                    backgroundColor: colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: huge.HugeIcon(
                      icon: huge.HugeIcons.strokeRoundedContactBook,
                      color: colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusList(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _currentUserStream ?? const Stream.empty(),
      builder: (context, userSnapshot) {
        List<dynamic> myContacts = [];
        if (userSnapshot.hasData && userSnapshot.data?.exists == true) {
          var myData = userSnapshot.data!.data() as Map<String, dynamic>?;
          if (myData != null) {
            myContacts = myData['contacts'] as List<dynamic>? ?? [];
          }
        }

        return StreamBuilder<List<Status>>(
          stream: _statusesStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final statuses = snapshot.data!;
            Map<String, List<Status>> groupedStatuses = {};
            for (var s in statuses) {
              if (s.uid == _auth.currentUser?.uid ||
                  myContacts.contains(s.uid)) {
                groupedStatuses.putIfAbsent(s.uid, () => []).add(s);
              }
            }

            String? currentUserId = _auth.currentUser?.uid;
            List<Status> myStatuses = [];
            if (currentUserId != null &&
                groupedStatuses.containsKey(currentUserId)) {
              myStatuses = groupedStatuses[currentUserId]!;
              groupedStatuses.remove(currentUserId);
            }

            List<List<Status>> allOtherUserStatuses = groupedStatuses.values
                .toList();

            if (currentUserId != null) {
              allOtherUserStatuses.sort((a, b) {
                bool aAllViewed = a.every(
                  (s) => s.viewers.any((v) => v.uid == currentUserId),
                );
                bool bAllViewed = b.every(
                  (s) => s.viewers.any((v) => v.uid == currentUserId),
                );
                if (aAllViewed == bAllViewed) {
                  return b.last.createdAt.compareTo(a.last.createdAt);
                }
                return aAllViewed ? 1 : -1;
              });
            }

            return Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: allOtherUserStatuses.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildMyStatusAvatar(context, myStatuses);
                  }
                  List<Status> userStatuses = allOtherUserStatuses[index - 1];
                  return _buildUserStatusAvatar(
                    context,
                    userStatuses,
                    allOtherUserStatuses,
                    index - 1,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyStatusAvatar(BuildContext context, List<Status> myStatuses) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot>(
      stream: _currentUserStream,
      builder: (context, snapshot) {
        String profilePic = '';
        String name = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            profilePic = data['profilepic'] ?? '';
            name = data['name'] ?? data['username'] ?? '';
          }
        }

        return GestureDetector(
          onTap: () {
            if (myStatuses.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StatusViewScreen(statuses: myStatuses),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateStatusScreen(),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: myStatuses.isNotEmpty
                              ? colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        backgroundImage: profilePic.isNotEmpty
                            ? (profilePic.startsWith('http')
                                      ? CachedNetworkImageProvider(profilePic)
                                      : AssetImage(profilePic))
                                  as ImageProvider
                            : const AssetImage('assets/icon/default_profile.png'),
                      ),
                    ),
                    if (myStatuses.isEmpty)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Icon(
                              Icons.add,
                              size: 20,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'My status',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserStatusAvatar(
    BuildContext context,
    List<Status> statuses,
    List<List<Status>> allUserStatuses,
    int userIndex,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final latestStatus =
        statuses.last; // Use the most recent status for profile pic

    final currentUserId = _auth.currentUser?.uid;
    bool allViewed =
        currentUserId != null &&
        statuses.every((s) => s.viewers.any((v) => v.uid == currentUserId));
    Color ringColor = allViewed
        ? colorScheme.onSurface.withValues(alpha: 0.2)
        : colorScheme.primary;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StatusViewScreen(
              groupedStatusesList: allUserStatuses,
              initialUserIndex: userIndex,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundImage: latestStatus.profilePic.isNotEmpty
                    ? (latestStatus.profilePic.startsWith('http')
                              ? CachedNetworkImageProvider(
                                  latestStatus.profilePic,
                                )
                              : AssetImage(latestStatus.profilePic))
                          as ImageProvider
                    : const AssetImage('assets/icon/default_profile.png'),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              latestStatus.username.length > 8
                  ? '${latestStatus.username.substring(0, 8)}...'
                  : latestStatus.username,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedNotificationBell extends StatefulWidget {
  final Color color;
  final double size;

  const AnimatedNotificationBell({
    super.key,
    required this.color,
    required this.size,
  });

  @override
  State<AnimatedNotificationBell> createState() => _AnimatedNotificationBellState();
}

class _AnimatedNotificationBellState extends State<AnimatedNotificationBell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _hasNotifications = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.25).chain(CurveTween(curve: Curves.easeOut)), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: -0.25).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.25, end: 0.15).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.15, end: -0.15).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 10),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 120), // Rest phase
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return _buildIcon();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, notifSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('friend_requests')
              .where('receiverId', isEqualTo: currentUser.uid)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, freqSnapshot) {
            bool hasAny = false;
            if (notifSnapshot.hasData && notifSnapshot.data!.docs.isNotEmpty) {
              hasAny = true;
            }
            if (freqSnapshot.hasData && freqSnapshot.data!.docs.isNotEmpty) {
              hasAny = true;
            }

            if (hasAny) {
              if (!_hasNotifications) {
                _hasNotifications = true;
                _controller.repeat(); // Loop cleanly without reversing
              }
            } else {
              _hasNotifications = false;
              _controller.stop();
              _controller.reset();
            }

            return _buildIcon(hasDot: _hasNotifications);
          },
        );
      },
    );
  }

  Widget _buildIcon({bool hasDot = false}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animation.value,
          alignment: Alignment.topCenter, // Pivot from the top of the bell
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              huge.HugeIcon(
                icon: huge.HugeIcons.strokeRoundedNotification03,
                color: widget.color,
                size: widget.size,
              ),
              if (hasDot)
                Positioned(
                  top: 2,
                  right: 4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
