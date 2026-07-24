import 'dart:async';
import 'dart:ui';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:flutter/material.dart';
import 'package:cuqter/modules/status.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cuqter/services/status_service.dart';
import 'package:cuqter/services/message_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cuqter/Screen/userprofile.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StatusViewScreen extends StatefulWidget {
  final List<Status>? statuses;
  final List<List<Status>>? groupedStatusesList;
  final int initialUserIndex;
  final int initialIndex;

  const StatusViewScreen({
    super.key,
    this.statuses,
    this.groupedStatusesList,
    this.initialUserIndex = 0,
    this.initialIndex = 0,
  }) : assert(statuses != null || groupedStatusesList != null);

  @override
  State<StatusViewScreen> createState() => _StatusViewScreenState();
}

class _StatusViewScreenState extends State<StatusViewScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late List<List<Status>> _allGroups;
  late int _currentUserIndex;
  late int _currentIndex;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final StatusService _statusService = StatusService();
  final MessageService _messageService = MessageService();
  final TextEditingController _messageController = TextEditingController();
  final Set<String> _viewedStatuses = {};
  DateTime? _tapDownTime;
  late AnimationController _animationController;
  VideoPlayerController? _videoController;

  List<Status> get _currentGroup => _allGroups[_currentUserIndex];

  @override
  void initState() {
    super.initState();
    _allGroups = widget.groupedStatusesList ?? [widget.statuses!];
    _currentUserIndex = widget.initialUserIndex;
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _nextStatus();
      }
    });
    _markCurrentAsSeen();
    _setupCurrentStatus();
  }

  void _setupCurrentStatus() {
    _animationController.reset();
    final oldController = _videoController;
    if (oldController != null) {
      _videoController = null;
      Future.delayed(const Duration(milliseconds: 500), () {
        oldController.dispose();
      });
    }

    if (_currentGroup.isEmpty) return;

    final status = _currentGroup[_currentIndex];

    if (status.mediaType == 'video') {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(status.mediaUrl),
      );
      _videoController = controller;

      controller
          .initialize()
          .then((_) {
            if (mounted && _videoController == controller) {
              setState(() {});
              controller.play();

              _animationController.duration = controller.value.duration;
              _animationController.forward(from: 0.0);

              controller.addListener(() {
                if (!mounted || _videoController != controller) return;
                if (controller.value.isInitialized) {
                  if (controller.value.isPlaying &&
                      !_animationController.isAnimating) {
                    _animationController.forward();
                  } else if (!controller.value.isPlaying &&
                      _animationController.isAnimating) {
                    _animationController.stop();
                  }

                  final videoPos = controller.value.position.inMilliseconds;
                  final duration = controller.value.duration.inMilliseconds;
                  if (duration > 0) {
                    final animPos = _animationController.value * duration;
                    if ((videoPos - animPos).abs() > 250) {
                      _animationController.value = videoPos / duration;
                    }
                  }
                }
              });
            }
          })
          .catchError((error) {
            print('Error initializing video: $error');
            if (mounted && _videoController == controller) {
              _animationController.duration = const Duration(seconds: 10);
              _animationController.forward();
            }
          });
    } else {
      _animationController.duration = const Duration(seconds: 10);
      _animationController.forward();
    }
  }

  void _pauseStatus() {
    if (_videoController != null && _videoController!.value.isPlaying) {
      _videoController!.pause();
    }
    if (_animationController.isAnimating) {
      _animationController.stop();
    }
  }

  void _resumeStatus() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      _videoController!.play();
    } else {
      _animationController.forward();
    }
  }

  void _markCurrentAsSeen() async {
    if (_currentGroup.isEmpty) return;
    final status = _currentGroup[_currentIndex];
    if (_currentUserId != null &&
        status.uid != _currentUserId &&
        !_viewedStatuses.contains(status.statusId)) {
      _viewedStatuses.add(status.statusId);

      bool alreadyViewed = status.viewers.any((v) => v.uid == _currentUserId);
      if (alreadyViewed) return;

      String currentUserName = 'User';
      String currentUserPic = '';
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .get();
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
    _animationController.dispose();
    _pageController.dispose();
    _messageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _sendReply(Status status) {
    if (_messageController.text.trim().isEmpty || _currentUserId == null)
      return;

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reply sent')));
    _resumeStatus();
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inHours >= 1) {
      final hour = dateTime.hour > 12
          ? dateTime.hour - 12
          : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $amPm';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _nextStatus() {
    if (_currentIndex < _currentGroup.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (_currentUserIndex < _allGroups.length - 1) {
        setState(() {
          _currentUserIndex++;
          _currentIndex = 0;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
        });
        _markCurrentAsSeen();
        _setupCurrentStatus();
      } else {
        Navigator.pop(context);
      }
    }
  }

  void _previousStatus() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (_currentUserIndex > 0) {
        setState(() {
          _currentUserIndex--;
          _currentIndex = _allGroups[_currentUserIndex].length - 1;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_currentIndex);
          }
        });
        _markCurrentAsSeen();
        _setupCurrentStatus();
      }
    }
  }

  bool _showHeartOverlay = false;

  void _triggerHeartOverlay() {
    setState(() {
      _showHeartOverlay = true;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showHeartOverlay = false;
        });
      }
    });
  }

  void _toggleLike(Status status) async {
    if (_currentUserId == null) return;
    final isLiked = status.likes.any((l) => l.uid == _currentUserId);

    if (!isLiked) {
      _triggerHeartOverlay();
    }

    String currentUserName = 'User';
    String currentUserPic = '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        currentUserName = data['name'] ?? data['username'] ?? 'User';
        currentUserPic = data['profilepic'] ?? '';
      }
    } catch (e) {
      print('Error fetching user info for like: $e');
    }

    final liker = StatusLiker(
      uid: _currentUserId!,
      username: currentUserName,
      profilePic: currentUserPic,
      likedAt: DateTime.now(),
    );

    setState(() {
      if (isLiked) {
        status.likes.removeWhere((l) => l.uid == _currentUserId);
      } else {
        status.likes.removeWhere((l) => l.uid == _currentUserId);
        status.likes.add(liker);
      }
    });

    await _statusService.toggleLikeStatus(
      statusId: status.statusId,
      statusOwnerUid: status.uid,
      liker: liker,
      isLiking: !isLiked,
    );
  }

  void _showStatusDetailsSheet(Status status, {int initialTabIndex = 0}) async {
    _pauseStatus();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DefaultTabController(
          length: 2,
          initialIndex: initialTabIndex,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.55,
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                TabBar(
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedView, size: 18, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 6),
                          Text('Views (${status.viewers.map((v) => v.uid).toSet().length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedFavourite, size: 18, color: Colors.redAccent),
                          const SizedBox(width: 6),
                          Text('Likes (${status.likes.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Viewers Tab
                      _buildViewersTab(status),
                      // Likes Tab
                      _buildLikesTab(status),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) _resumeStatus();
  }

  Widget _buildViewersTab(Status status) {
    final uniqueViewers = <String, StatusViewer>{};
    for (var v in status.viewers) {
      uniqueViewers.putIfAbsent(v.uid, () => v);
    }
    final viewersList = uniqueViewers.values.toList();

    if (viewersList.isEmpty) {
      return const Center(
        child: Text('No views yet', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: viewersList.length,
      itemBuilder: (context, index) {
        final viewer = viewersList[index];
        final viewerLiked = status.likes.any((l) => l.uid == viewer.uid);

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(viewer.uid).get(),
          builder: (context, snapshot) {
            String name = viewer.username != 'User' && viewer.username != 'Unknown User'
                ? viewer.username
                : 'Loading...';
            String pic = viewer.profilePic;
            String bio = '';
            String username = viewer.username;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null) {
                name = data['name'] ?? data['username'] ?? 'User';
                pic = data['profilepic'] ?? pic;
                bio = data['bio'] ?? '';
                username = data['username'] ?? username;
              }
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: pic.isNotEmpty
                    ? (pic.startsWith('http')
                        ? CachedNetworkImageProvider(pic)
                        : AssetImage(pic)) as ImageProvider
                    : const AssetImage('assets/icon/default_profile.png'),
              ),
              title: Row(
                children: [
                  Text(name),
                  if (viewerLiked) ...[
                    const SizedBox(width: 6),
                    huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedFavourite, size: 14, color: Colors.redAccent),
                  ],
                ],
              ),
              subtitle: Text(_formatTimeAgo(viewer.viewedAt)),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfilePage(
                      userId: viewer.uid,
                      name: name,
                      username: username,
                      bio: bio,
                      profilepic: pic,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLikesTab(Status status) {
    if (status.likes.isEmpty) {
      return const Center(
        child: Text('No likes yet', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: status.likes.length,
      itemBuilder: (context, index) {
        final liker = status.likes[index];

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(liker.uid).get(),
          builder: (context, snapshot) {
            String name = liker.username != 'User' && liker.username != 'Unknown User'
                ? liker.username
                : 'Loading...';
            String pic = liker.profilePic;
            String bio = '';
            String username = liker.username;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null) {
                name = data['name'] ?? data['username'] ?? 'User';
                pic = data['profilepic'] ?? pic;
                bio = data['bio'] ?? '';
                username = data['username'] ?? username;
              }
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: pic.isNotEmpty
                    ? (pic.startsWith('http')
                        ? CachedNetworkImageProvider(pic)
                        : AssetImage(pic)) as ImageProvider
                    : const AssetImage('assets/icon/default_profile.png'),
              ),
              title: Text(name),
              subtitle: Text(_formatTimeAgo(liker.likedAt)),
              trailing: huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedFavourite, color: Colors.redAccent, size: 20),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfilePage(
                      userId: liker.uid,
                      name: name,
                      username: username,
                      bio: bio,
                      profilepic: pic,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentGroup.isEmpty) return const Scaffold();

    final currentStatus = _currentGroup[_currentIndex];
    final isLikedByMe = _currentUserId != null && currentStatus.likes.any((l) => l.uid == _currentUserId);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _currentGroup.length,
              onPageChanged: (index) {
                if (_currentIndex == index) return;
                setState(() {
                  _currentIndex = index;
                });
                _markCurrentAsSeen();
                _setupCurrentStatus();
              },
              itemBuilder: (context, index) {
                final status = _currentGroup[index];
                final isCurrentUser =
                    _currentUserId != null && status.uid == _currentUserId;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {
                    _tapDownTime = DateTime.now();
                    _pauseStatus();
                  },
                  onTapCancel: () {
                    _tapDownTime = null;
                    _resumeStatus();
                  },
                  onTapUp: (details) {
                    bool shouldNavigate = false;
                    bool isNext = false;
                    if (_tapDownTime != null) {
                      final duration = DateTime.now().difference(_tapDownTime!);
                      _tapDownTime = null;
                      if (duration.inMilliseconds < 300) {
                        shouldNavigate = true;
                        final screenWidth = MediaQuery.of(context).size.width;
                        isNext = details.localPosition.dx >= screenWidth / 2;
                      }
                    }

                    if (shouldNavigate) {
                      if (isNext) {
                        if (_currentIndex == _currentGroup.length - 1) {
                          _resumeStatus();
                        }
                        _nextStatus();
                      } else {
                        if (_currentIndex == 0) {
                          _resumeStatus();
                        }
                        if (!(_currentIndex == 0 && _currentUserIndex == 0)) {
                          _previousStatus();
                        }
                      }
                    } else {
                      _resumeStatus();
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (status.mediaType == 'video')
                        SizedBox.expand(
                          child:
                              index == _currentIndex &&
                                  _videoController != null &&
                                  _videoController!.value.isInitialized
                              ? FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: _videoController!.value.size.width,
                                    height: _videoController!.value.size.height,
                                    child: VideoPlayer(_videoController!),
                                  ),
                                )
                              : const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                        )
                      else if (status.mediaType == 'image')
                        CachedNetworkImage(
                          imageUrl: status.mediaUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        )
                      else if (status.mediaType == 'text' ||
                          status.mediaUrl.isEmpty)
                        Container(
                          color:
                              Colors.primaries[index % Colors.primaries.length],
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                status.caption,
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),

                      if (status.caption.isNotEmpty &&
                          (status.mediaType == 'image' ||
                              status.mediaType == 'video'))
                        Positioned(
                          bottom: isCurrentUser ? 90 : 100,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            color: Colors.black54,
                            child: Text(
                              status.caption,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              top: 5,
              left: 10,
              right: 10,
              child: Row(
                children: List.generate(
                  _currentGroup.length,
                  (barIndex) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: _buildProgressBar(barIndex),
                    ),
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
                  GestureDetector(
                    onTap: () async {
                      _pauseStatus();
                      final doc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(_currentGroup[_currentIndex].uid)
                          .get();
                      String name = _currentGroup[_currentIndex].username;
                      String bio = '';
                      String profilePic =
                          _currentGroup[_currentIndex].profilePic;
                      if (doc.exists) {
                        final data = doc.data();
                        if (data != null) {
                          name =
                              data['name'] ??
                              _currentGroup[_currentIndex].username;
                          bio = data['bio'] ?? '';
                          profilePic =
                              data['profilepic'] ??
                              _currentGroup[_currentIndex].profilePic;
                        }
                      }
                      if (mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfilePage(
                              userId: _currentGroup[_currentIndex].uid,
                              name: name,
                              username: _currentGroup[_currentIndex].username,
                              bio: bio,
                              profilepic: profilePic,
                            ),
                          ),
                        );
                        if (mounted) _resumeStatus();
                      }
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage:
                              _currentGroup.last.profilePic.isNotEmpty
                              ? (_currentGroup.last.profilePic.startsWith(
                                          'http',
                                        )
                                         ? CachedNetworkImageProvider(
                                             _currentGroup.last.profilePic,
                                           )
                                         : AssetImage(
                                             _currentGroup.last.profilePic,
                                           ))
                                     as ImageProvider
                              : const AssetImage('assets/icon/default_profile.png'),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentGroup.last.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _formatTimeAgo(
                                _currentGroup[_currentIndex].createdAt,
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Bar for current user (Status Owner)
            if (_currentUserId != null &&
                _currentGroup[_currentIndex].uid == _currentUserId)
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
                        onPressed: () => _showStatusDetailsSheet(_currentGroup[_currentIndex], initialTabIndex: 0),
                        icon: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedView,
                          color: Colors.white,
                          size: 24,
                        ),
                        label: Text(
                          '${_currentGroup[_currentIndex].viewers.map((v) => v.uid).toSet().length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showStatusDetailsSheet(_currentGroup[_currentIndex], initialTabIndex: 1),
                        icon: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedFavourite,
                          color: _currentGroup[_currentIndex].likes.isNotEmpty
                              ? Colors.redAccent
                              : Colors.white,
                          size: 24,
                        ),
                        label: Text(
                          '${_currentGroup[_currentIndex].likes.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedShare01,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () {
                          final status = _currentGroup[_currentIndex];
                          String shareText = 'Check out my status on Cuqter!';
                          if (status.caption.isNotEmpty) {
                            shareText += '\n"${status.caption}"';
                          }
                          if (status.mediaUrl.isNotEmpty) {
                            shareText += '\n${status.mediaUrl}';
                          }
                          Share.share(shareText);
                        },
                      ),
                      IconButton(
                        icon: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedDelete02,
                          color: Colors.redAccent,
                          size: 24,
                        ),
                        onPressed: () async {
                          await _statusService.deleteStatus(
                            _currentGroup[_currentIndex],
                          );
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // Reply field & Like button for other users
            if (_currentUserId == null ||
                _currentGroup[_currentIndex].uid != _currentUserId)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {}, // Prevent tap from bubbling to next status
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: TextField(
                                controller: _messageController,
                                style: const TextStyle(color: Colors.white),
                                onSubmitted: (_) =>
                                    _sendReply(_currentGroup[_currentIndex]),
                                decoration: InputDecoration(
                                  hintText: 'Reply to status...',
                                  hintStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.black.withValues(
                                    alpha: 0.3,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: huge.HugeIcon(
                            icon: huge.HugeIcons.strokeRoundedSent,
                            color: Colors.blueAccent,
                            size: 24,
                          ),
                          onPressed: () =>
                              _sendReply(_currentGroup[_currentIndex]),
                        ),
                        IconButton(
                          icon: TweenAnimationBuilder<double>(
                            key: ValueKey(isLikedByMe),
                            tween: Tween(begin: 0.7, end: 1.0),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.elasticOut,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: huge.HugeIcon(
                                  icon: huge.HugeIcons.strokeRoundedFavourite,
                                  color: isLikedByMe ? Colors.redAccent : Colors.white,
                                  size: 26,
                                ),
                              );
                            },
                          ),
                          onPressed: () => _toggleLike(currentStatus),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_showHeartOverlay)
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1.2),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedFavourite,
                        color: Colors.redAccent,
                        size: 100,
                      ),
                    );
                  },
                ),
              ),
            // Navigation Arrows for Web/Windows
            if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) ...[
              if (!(_currentIndex == 0 && _currentUserIndex == 0))
                Positioned(
                  left: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedArrowLeft01,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _previousStatus,
                    ),
                  ),
                ),
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: const huge.HugeIcon(
                      icon: huge.HugeIcons.strokeRoundedArrowRight01,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _nextStatus,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(int barIndex) {
    if (barIndex < _currentIndex) {
      return Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(1.5),
        ),
      );
    } else if (barIndex > _currentIndex) {
      return Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(1.5),
        ),
      );
    } else {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1.5),
            ),
            alignment: Alignment.centerLeft,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  width:
                      constraints.maxWidth *
                      _animationController.value.clamp(0.0, 1.0),
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              },
            ),
          );
        },
      );
    }
  }
}
