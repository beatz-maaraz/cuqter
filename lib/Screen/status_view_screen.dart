import 'package:flutter/material.dart';
import 'package:cuqter/modules/status.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cuqter/services/status_service.dart';
import 'package:cuqter/services/message_service.dart';
import 'package:share_plus/share_plus.dart';

class StatusViewScreen extends StatefulWidget {
  final List<Status> statuses;
  final int initialIndex;

  const StatusViewScreen({super.key, required this.statuses, this.initialIndex = 0});

  @override
  State<StatusViewScreen> createState() => _StatusViewScreenState();
}

class _StatusViewScreenState extends State<StatusViewScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final StatusService _statusService = StatusService();
  final MessageService _messageService = MessageService();
  final TextEditingController _messageController = TextEditingController();
  final Set<String> _viewedStatuses = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _markCurrentAsSeen();
  }

  void _markCurrentAsSeen() async {
    if (widget.statuses.isEmpty) return;
    final status = widget.statuses[_currentIndex];
    if (_currentUserId != null && status.uid != _currentUserId && !_viewedStatuses.contains(status.statusId)) {
      _viewedStatuses.add(status.statusId);
      
      String currentUserName = 'User';
      String currentUserPic = '';
      try {
         final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
         if (doc.exists) {
           final data = doc.data() as Map<String, dynamic>;
           currentUserName = data['name'] ?? 'User';
           currentUserPic = data['profilepic'] ?? '';
         }
      } catch (e) {
         print('Error fetching user info for status viewer: $e');
      }

      final viewer = StatusViewer(
        uid: _currentUserId,
        username: currentUserName,
        profilePic: currentUserPic,
        viewedAt: DateTime.now(),
      );

      _statusService.markStatusAsSeen(status.statusId, viewer);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendReply(Status status) {
    if (_messageController.text.trim().isEmpty || _currentUserId == null) return;
    
    String chatId = _currentUserId.compareTo(status.uid) > 0 
        ? '${_currentUserId}_${status.uid}' 
        : '${status.uid}_${_currentUserId}';
        
    _messageService.sendMessage(
      chatId: chatId,
      senderId: _currentUserId,
      receiverId: status.uid,
      text: _messageController.text.trim(),
    );
    
    _messageController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent')));
    Navigator.pop(context);
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _nextStatus() {
    if (_currentIndex < widget.statuses.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStatus() {
    if (_currentIndex > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.statuses.isEmpty) return const Scaffold();
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.statuses.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
            _markCurrentAsSeen();
          },
          itemBuilder: (context, index) {
            final status = widget.statuses[index];
            final isCurrentUser = _currentUserId != null && status.uid == _currentUserId;
            return GestureDetector(
              onTapUp: (details) {
                final screenWidth = MediaQuery.of(context).size.width;
                if (details.globalPosition.dx < screenWidth / 3) {
                  _previousStatus();
                } else {
                  _nextStatus();
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (status.mediaType == 'image')
                    Image.network(status.mediaUrl, fit: BoxFit.contain)
                  else if (status.mediaType == 'text' || status.mediaUrl.isEmpty)
                    Container(
                      color: Colors.primaries[index % Colors.primaries.length],
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            status.caption,
                            style: const TextStyle(fontSize: 24, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  
                  if (status.caption.isNotEmpty && status.mediaType == 'image')
                    Positioned(
                      bottom: isCurrentUser ? 80 : 40,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        color: Colors.black54,
                        child: Text(
                          status.caption,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  // Bottom Bar for current user
                  if (isCurrentUser)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: Colors.black54,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (context) {
                                    return SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: Text('Viewed by', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                          ),
                                          if (status.viewers.isEmpty)
                                            const Padding(
                                              padding: EdgeInsets.all(16.0),
                                              child: Text('No views yet'),
                                            ),
                                          ...status.viewers.map((viewer) {
                                            return FutureBuilder<DocumentSnapshot>(
                                              future: FirebaseFirestore.instance.collection('users').doc(viewer.uid).get(),
                                              builder: (context, snapshot) {
                                                String name = viewer.username != 'User' && viewer.username != 'Unknown User' 
                                                    ? viewer.username 
                                                    : 'Loading...';
                                                String pic = viewer.profilePic;

                                                if (snapshot.hasData && snapshot.data!.exists) {
                                                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                                                  if (data != null) {
                                                    name = data['name'] ?? data['username'] ?? 'User';
                                                    pic = data['profilepic'] ?? pic;
                                                  }
                                                }

                                                return ListTile(
                                                  leading: CircleAvatar(
                                                    backgroundImage: pic.isNotEmpty && pic.startsWith('http') 
                                                        ? NetworkImage(pic) 
                                                        : null,
                                                    child: pic.isEmpty ? const Icon(Icons.person) : null,
                                                  ),
                                                  title: Text(name),
                                                  subtitle: Text(_formatTimeAgo(viewer.viewedAt)),
                                                );
                                              }
                                            );
                                          }),
                                        ],
                                      ),
                                    );
                                  }
                                );
                              },
                              icon: const Icon(Icons.remove_red_eye, color: Colors.white),
                              label: Text('${status.viewers.length}', style: const TextStyle(color: Colors.white)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.white),
                              onPressed: () {
                                final shareText = status.mediaType == 'image' 
                                    ? 'Check out my status image: ${status.mediaUrl}' 
                                    : 'Check out my status: ${status.caption}';
                                Share.share(shareText);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () async {
                                await _statusService.deleteStatus(status.statusId);
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Reply field for other users
                  if (!isCurrentUser)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {}, // Prevent tap from bubbling to next status
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          color: Colors.black54,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Reply to status...',
                                    hintStyle: const TextStyle(color: Colors.white70),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white24,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.send, color: Colors.blueAccent),
                                onPressed: () => _sendReply(status),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Header with Profile Pic and Name
                  Positioned(
                    top: 20,
                    left: 10,
                    right: 10,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        CircleAvatar(
                          backgroundImage: status.profilePic.startsWith('http')
                              ? NetworkImage(status.profilePic)
                              : null,
                          child: status.profilePic.isEmpty
                              ? Text(status.username.isNotEmpty ? status.username[0].toUpperCase() : '?')
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status.username,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              _formatTimeAgo(status.createdAt),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

