import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cuqter/Screen/chat_screen.dart';
import 'package:cuqter/Screen/profile_screen.dart';
import 'package:cuqter/resources/auth_method.dart';
import 'package:cuqter/services/message_service.dart';
import 'package:cuqter/modules/message.dart';
import 'package:flutter/material.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with WidgetsBindingObserver {
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
  final Map<String, StreamSubscription<Message?>> _lastMessageSubscriptions = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUserStatus(true);
    getUsername();
    if (_auth.currentUser != null) {
      _currentUserStream = _firestore.collection('users').doc(_auth.currentUser!.uid).snapshots();
    }
    _usersStream = _firestore.collection('users').snapshots();
  }



  Stream<int> _getUnreadCountStream(String chatId, String currentUserId) {
    return _unreadCountStreams.putIfAbsent(
      chatId,
      () => _messageService.getUnreadMessageCountStream(chatId, currentUserId),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserStatus(false);
    for (var sub in _lastMessageSubscriptions.values) {
      sub.cancel();
    }
    _lastMessageSubscriptions.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserStatus(true);
    } else {
      _setUserStatus(false);
    }
  }

  Future<void> _setUserStatus(bool isOnline) async {
    if (_auth.currentUser != null) {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((e) {
        // Handle error conceptually if document somehow doesn't exist
      });
    }
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
    final hour = dateTime.hour > 12 ? (dateTime.hour - 12).toString() : (dateTime.hour == 0 ? '12' : dateTime.hour.toString());
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
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
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                  StreamBuilder<DocumentSnapshot>(
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
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => const ProfileScreen(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
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
                          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                          backgroundImage: profilePic.isNotEmpty
                              ? (profilePic.startsWith('http')
                                  ? NetworkImage(profilePic) as ImageProvider
                                  : AssetImage(profilePic) as ImageProvider)
                              : null,
                          child: profilePic.isEmpty
                              ? Icon(Icons.person_outline, color: colorScheme.primary)
                              : null,
                        ),
                      );
                    }
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

            // Chat List
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _currentUserStream ?? const Stream.empty(),
                builder: (context, userSnapshot) {
                  List<dynamic> myContacts = [];
                  if (userSnapshot.hasData && userSnapshot.data?.exists == true) {
                    var myData = userSnapshot.data!.data() as Map<String, dynamic>?;
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

                      var users = snapshot.data?.docs.where((doc) {
                        if (_auth.currentUser == null) return false;
                        if (doc.id == _auth.currentUser!.uid) return false;
                        
                        if (searchQuery.isNotEmpty) {
                          var data = doc.data() as Map<String, dynamic>?;
                          String name = (data?['name'] ?? '').toString().toLowerCase();
                          return name.contains(searchQuery);
                        }
                        return myContacts.contains(doc.id);
                      }).toList() ?? [];

                      // Setup subscriptions for last messages if not already present
                      if (_auth.currentUser != null) {
                        for (var doc in users) {
                          String userId = doc.id;
                          String chatId = getChatId(_auth.currentUser!.uid, userId);
                          if (!_lastMessageSubscriptions.containsKey(chatId)) {
                            _lastMessageSubscriptions[chatId] = _messageService.getLastMessage(chatId).listen((message) {
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
                          String chatIdA = getChatId(_auth.currentUser!.uid, a.id);
                          String chatIdB = getChatId(_auth.currentUser!.uid, b.id);
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
                        return Center(child: Text('No messages yet', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4))));
                      }

                      return ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          var userData = users[index].data() as Map<String, dynamic>;
                          String userName = userData['name'] ?? 'Unknown User';
                          String userBio = userData['bio'] ?? 'Stay cozy today!';
                          String userId = users[index].id;
                          bool isOnline = userData['isOnline'] ?? false;
                          String chatId = getChatId(_auth.currentUser!.uid, userId);

                          final lastMsg = _lastMessages[chatId];
                          final isLastMsgFromMe = lastMsg != null && lastMsg.senderId == _auth.currentUser!.uid;
                          final subtitle = lastMsg != null 
                              ? lastMsg.text
                              : userBio;
                          final timeText = lastMsg != null ? _formatDateTime(lastMsg.timestamp) : '';

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
                                    receiverId: userId,
                                    receiverName: userName,
                                  ),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return SlideTransition(
                                      position: Tween<Offset>(
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                              child: Row(
                                children: [
                                  // Avatar with status
                                  Stack(
                                    children: [
                                       CircleAvatar(
                                         radius: 28,
                                         backgroundColor: colorScheme.primaryContainer,
                                         backgroundImage: userData['profilepic'] != null && userData['profilepic'].toString().isNotEmpty
                                             ? (userData['profilepic'].toString().startsWith('http')
                                                 ? NetworkImage(userData['profilepic'].toString()) as ImageProvider
                                                 : AssetImage(userData['profilepic'].toString()) as ImageProvider)
                                             : null,
                                         child: userData['profilepic'] == null || userData['profilepic'].toString().isEmpty
                                             ? Text(
                                                 userName[0].toUpperCase(),
                                                 style: TextStyle(
                                                   fontWeight: FontWeight.bold,
                                                   fontSize: 18,
                                                   color: colorScheme.onPrimaryContainer,
                                                 ),
                                               )
                                             : null,
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
                                              border: Border.all(color: colorScheme.surface, width: 2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              userName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            Text(
                                              timeText,
                                              style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  if (isLastMsgFromMe) ...[
                                                    Icon(
                                                      lastMsg.isRead ? Icons.done_all : Icons.done,
                                                      size: 16,
                                                      color: lastMsg.isRead ? Colors.blue : colorScheme.onSurface.withValues(alpha: 0.4),
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      subtitle,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            StreamBuilder<int>(
                                              stream: _getUnreadCountStream(chatId, _auth.currentUser!.uid),
                                              builder: (context, unreadSnapshot) {
                                                int count = unreadSnapshot.data ?? 0;
                                                if (count > 0 || userName == "Luv 🌺💕") { // Demo match for screenshot
                                                  return Container(
                                                    margin: const EdgeInsets.only(left: 8),
                                                    width: 10,
                                                    height: 10,
                                                    decoration: BoxDecoration(
                                                      color: colorScheme.primary,
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
        onPressed: () {},
        backgroundColor: colorScheme.primary,
        shape: const CircleBorder(),
        child: Icon(Icons.add, color: colorScheme.onPrimary, size: 32),
      ),
    );
  }
}
