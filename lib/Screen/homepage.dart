// ignore_for_file: dead_code

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class Homepage extends StatefulWidget {
  const Homepage({super.key});

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
  }

  Stream<int> _getUnreadCountStream(String chatId, String currentUserId) {
    return _unreadCountStreams.putIfAbsent(
      chatId,
      () => _messageService.getUnreadMessageCountStream(chatId, currentUserId),
    );
  }

  @override
  void dispose() {
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
    final hour = dateTime.hour > 12
        ? (dateTime.hour - 12).toString()
        : (dateTime.hour == 0 ? '12' : dateTime.hour.toString());
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
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
                                ),
                              );
                            },
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              backgroundImage: profilePic.isNotEmpty
                                  ? (profilePic.startsWith('http')
                                        ? NetworkImage(profilePic)
                                              as ImageProvider
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

                      return ListView.builder(
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
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => ChatScreen(
                                        receiverId: userId,
                                        receiverName: userName,
                                      ),
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
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 12.0,
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
                                                      ? NetworkImage(
                                                              userData['profilepic']
                                                                  .toString(),
                                                            )
                                                            as ImageProvider
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
                                            Text(
                                              userName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
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
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
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

        return Container(
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: groupedStatuses.keys.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildMyStatusAvatar(context, myStatuses);
              }
              String uid = groupedStatuses.keys.elementAt(index - 1);
              List<Status> userStatuses = groupedStatuses[uid]!;
              return _buildUserStatusAvatar(context, userStatuses);
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
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            profilePic = data['profilepic'] ?? '';
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
                        backgroundImage: profilePic.isNotEmpty && profilePic.startsWith('http') 
                            ? NetworkImage(profilePic) 
                            : null,
                        child: profilePic.isEmpty 
                            ? Icon(Icons.person, color: colorScheme.onSurface)
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
                          child: Icon(Icons.add, size: 16, color: colorScheme.onPrimary),
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

  Widget _buildUserStatusAvatar(BuildContext context, List<Status> statuses) {
    final colorScheme = Theme.of(context).colorScheme;
    final firstStatus = statuses.first;
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => StatusViewScreen(statuses: statuses)));
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
                backgroundImage: firstStatus.profilePic.startsWith('http') ? NetworkImage(firstStatus.profilePic) : null,
                child: firstStatus.profilePic.isEmpty ? Text(firstStatus.username.isNotEmpty ? firstStatus.username[0].toUpperCase() : '?') : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(firstStatus.username.length > 8 ? '${firstStatus.username.substring(0, 8)}...' : firstStatus.username, style: TextStyle(fontSize: 12, color: colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}
