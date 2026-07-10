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
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
        if (value.isNotEmpty) _handleIncomingSharing(value);
      }, onError: (err) {
        print("getIntentDataStream error: $err");
      });

      // Get the media sharing incoming intent when app is closed
      ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
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
                child: Text('Share to...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(Icons.history_edu, color: Theme.of(context).colorScheme.primary),
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
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(Icons.chat_bubble, color: Theme.of(context).colorScheme.secondary),
                ),
                title: const Text('A Chat'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _sharedFiles = files;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Received ${files.length} file(s). Select a chat below to share.'),
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
      final hour = dateTime.hour > 12
          ? (dateTime.hour - 12).toString()
          : (dateTime.hour == 0 ? '12' : dateTime.hour.toString());
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $amPm';
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        top: !widget.isDesktop,
        bottom: !widget.isDesktop,
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Row(
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
                      // Profile avatar
                      if (!widget.isDesktop)
                        StreamBuilder<DocumentSnapshot>(
                        stream: _currentUserStream,
                        builder: (context, snapshot) {
                          String profilePic = '';
                          if (snapshot.hasData && snapshot.data!.exists) {
                            var data =
                                snapshot.data!.data() as Map<String, dynamic>?;
                            if (data != null) {
                              profilePic = data['profilepic'] ?? '';
                            }
                          }
                          return GestureDetector(
                            onTap: () {
                              if (widget.isDesktop) {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    clipBehavior: Clip.antiAlias,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: const SizedBox(
                                      width: 400,
                                      height: 600,
                                      child: ProfileScreen(),
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
                                        ) => const ProfileScreen(),
                                    transitionsBuilder:
                                        (
                                          context,
                                          animation,
                                          secondaryAnimation,
                                          child,
                                        ) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: ScaleTransition(
                                              scale:
                                                  Tween<double>(
                                                    begin: 0.9,
                                                    end: 1.0,
                                                  ).animate(
                                                    CurvedAnimation(
                                                      parent: animation,
                                                      curve: Curves.easeOut,
                                                    ),
                                                  ),
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
                            },
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              backgroundImage: profilePic.isNotEmpty
                                  ? (profilePic.startsWith('http')
                                        ? CachedNetworkImageProvider(profilePic)
                                        : AssetImage(profilePic)
                                              as ImageProvider)
                                  : null,
                              child: profilePic.isEmpty
                                  ? Icon(
                                      Icons.person_outline,
                                      color: colorScheme.primary,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      // More vert popup menu
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'settings') {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const SettingsPage(),
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
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          size: 24,
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'settings',
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondary.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: huge.HugeIcon(
                                    icon:
                                        huge.HugeIcons.strokeRoundedSettings01,
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
                controller: _searchController,
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
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.trim().toLowerCase();
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            if (!widget.isDesktop) ...[
              // Status List
              _buildStatusList(context),

              Container(
                height: 6,
                margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                  if (userSnapshot.hasData &&
                      userSnapshot.data?.exists == true) {
                    var myData =
                        userSnapshot.data!.data() as Map<String, dynamic>?;
                    if (myData != null) {
                      myContacts = myData['contacts'] as List<dynamic>? ?? [];
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

                      // Sort users by latest interaction (LIFO / LIFI method)
                      if (_auth.currentUser != null && users.isNotEmpty) {
                        users.sort((a, b) {
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
                          cacheExtent: 1000.0, physics: const BouncingScrollPhysics(),
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                          var userData =
                              users[index].data() as Map<String, dynamic>;
                          String userName = userData['name'] ?? 'Unknown User';
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

                          return InkWell(
                            onTap: () {
                              if (widget.isDesktop && widget.onChatSelected != null) {
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
                                          final currentShared = List<SharedMediaFile>.from(_sharedFiles);
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
                                            sharedMedia: currentShared.isNotEmpty ? currentShared : null,
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
                                    transitionDuration: const Duration(
                                      milliseconds: 250,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: widget.selectedUserId == userId 
                                    ? colorScheme.primary.withValues(alpha: 0.1) 
                                    : Colors.transparent,
                                border: widget.selectedUserId == userId
                                    ? Border.all(color: colorScheme.primary, width: 2)
                                    : Border.all(color: Colors.transparent, width: 2),
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
                                                  clipBehavior: Clip.antiAlias,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(24),
                                                  ),
                                                  child: SizedBox(
                                                    width: 400,
                                                    height: 600,
                                                    child: FullScreenProfilePicPage(
                                                      imageUrl: pic,
                                                      heroTag: 'profile_pic_hero_$userId',
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
                                                : null,
                                            child:
                                                userData['profilepic'] ==
                                                        null ||
                                                    userData['profilepic']
                                                        .toString()
                                                        .isEmpty
                                                ? Text(
                                                    userName[0].toUpperCase(),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18,
                                                      color: colorScheme
                                                          .onPrimaryContainer,
                                                    ),
                                                  )
                                                : null,
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
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              timeText,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colorScheme.onSurface
                                                    .withValues(alpha: 0.5),
                                              ),
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
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
      floatingActionButton: widget.isDesktop ? null : FloatingActionButton(
        onPressed: () {
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
                      child: Text('Create', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.chat_bubble_outline, color: colorScheme.primary),
                      ),
                      title: const Text('New Chat'),
                      onTap: () {
                        Navigator.pop(context);
                        // Future implementation for new chat
                      },
                    ),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.camera_alt_outlined, color: colorScheme.primary),
                      ),
                      title: const Text('New Status'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateStatusScreen()));
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
        backgroundColor: colorScheme.primary,
        shape: const CircleBorder(),
        child: Icon(Icons.add, color: colorScheme.onPrimary, size: 32),
      ),
    );
  }

  Widget _buildStatusList(BuildContext context) {
    return StreamBuilder<List<Status>>(
      stream: _statusesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        }
        
        final statuses = snapshot.data!;
        Map<String, List<Status>> groupedStatuses = {};
        for (var s in statuses) {
          groupedStatuses.putIfAbsent(s.uid, () => []).add(s);
        }

        String? currentUserId = _auth.currentUser?.uid;
        List<Status> myStatuses = [];
        if (currentUserId != null && groupedStatuses.containsKey(currentUserId)) {
          myStatuses = groupedStatuses[currentUserId]!;
          groupedStatuses.remove(currentUserId);
        }

        List<List<Status>> allOtherUserStatuses = groupedStatuses.values.toList();

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
              return _buildUserStatusAvatar(context, userStatuses, allOtherUserStatuses, index - 1);
            },
          ),
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
              Navigator.push(context, MaterialPageRoute(builder: (context) => StatusViewScreen(statuses: myStatuses)));
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateStatusScreen()));
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
                          color: myStatuses.isNotEmpty ? colorScheme.primary : Colors.transparent, 
                          width: 2
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        backgroundImage: profilePic.isNotEmpty
                            ? (profilePic.startsWith('http')
                                ? CachedNetworkImageProvider(profilePic)
                                : AssetImage(profilePic)) as ImageProvider
                            : null,
                        child: profilePic.isEmpty 
                            ? Icon(Icons.person, color: colorScheme.onSurface, size: 24)
                            : null,
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
                            border: Border.all(color: colorScheme.surface, width: 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Icon(Icons.add, size: 20, color: colorScheme.onPrimary),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('My status', style: TextStyle(fontSize: 12, color: colorScheme.onSurface)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserStatusAvatar(BuildContext context, List<Status> statuses, List<List<Status>> allUserStatuses, int userIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    final latestStatus = statuses.last; // Use the most recent status for profile pic
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => StatusViewScreen(
          groupedStatusesList: allUserStatuses,
          initialUserIndex: userIndex,
        )));
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.primary, width: 2),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundImage: latestStatus.profilePic.isNotEmpty
                    ? (latestStatus.profilePic.startsWith('http')
                        ? CachedNetworkImageProvider(latestStatus.profilePic)
                        : AssetImage(latestStatus.profilePic)) as ImageProvider
                    : null,
                child: latestStatus.profilePic.isEmpty 
                    ? Icon(Icons.person, color: colorScheme.onSurface, size: 24)
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(latestStatus.username.length > 8 ? '${latestStatus.username.substring(0, 8)}...' : latestStatus.username, style: TextStyle(fontSize: 12, color: colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}
