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
import 'package:cuqter/Screen/profile/userprofile.dart';
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
  final FocusNode _replyFocusNode = FocusNode();
  final Set<String> _viewedStatuses = {};
  DateTime? _tapDownTime;
  late AnimationController _animationController;
  VideoPlayerController? _videoController;

  final List<List<Color>> _statusGradients = [
    [const Color(0xFF8A2387), const Color(0xFFE94057), const Color(0xFFF27121)],
    [const Color(0xFF00C6FF), const Color(0xFF0072FF)],
    [const Color(0xFF1D976C), const Color(0xFF93F9B9)],
    [const Color(0xFFEB5757), const Color(0xFF000000)],
    [const Color(0xFFC33764), const Color(0xFF1D2671)],
    [const Color(0xFF11998E), const Color(0xFF38EF7D)],
  ];

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

    _replyFocusNode.addListener(() {
      if (_replyFocusNode.hasFocus) {
        _pauseStatus();
      } else {
        _resumeStatus();
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
    _replyFocusNode.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _sendReply(Status status, {String? messageOverride}) {
    final message = messageOverride ?? _messageController.text.trim();
    if (message.isEmpty || _currentUserId == null) {
      return;
    }

    String chatId = _currentUserId.compareTo(status.uid) > 0
        ? '${_currentUserId}_${status.uid}'
        : '${status.uid}_$_currentUserId';

    _messageService.sendMessage(
      chatId: chatId,
      senderId: _currentUserId,
      receiverId: status.uid,
      text: message,
    );

    if (messageOverride == null) {
      _messageController.clear();
      _replyFocusNode.unfocus();
    }

    // Show quick feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reply sent'),
        duration: Duration(seconds: 1),
      ),
    );
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
      uid: _currentUserId,
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

  void _showStatusDetailsSheet(Status status) async {
    _pauseStatus();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              ),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedView,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Views (${status.viewers.map((v) => v.uid).toSet().length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _buildViewersTab(status)),
                ],
              ),
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
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(viewer.uid)
              .get(),
          builder: (context, snapshot) {
            String name =
                viewer.username != 'User' && viewer.username != 'Unknown User'
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

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundImage: pic.isNotEmpty
                          ? (pic.startsWith('http')
                                    ? CachedNetworkImageProvider(pic)
                                    : AssetImage(pic))
                                as ImageProvider
                          : null,
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    _formatTimeAgo(viewer.viewedAt),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: viewerLiked
                      ? Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const huge.HugeIcon(
                            icon: huge.HugeIcons.strokeRoundedFavourite,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                        )
                      : null,
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
                ),
              ),
            ),
            );
          },
        );
      },
      padding: const EdgeInsets.only(bottom: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentGroup.isEmpty) return const Scaffold();

    final currentStatus = _currentGroup[_currentIndex];
    final isLikedByMe =
        _currentUserId != null &&
        currentStatus.likes.any((l) => l.uid == _currentUserId);

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
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors:
                                  _statusGradients[status.colorIndex %
                                      _statusGradients.length],
                            ),
                          ),
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
                          bottom: isCurrentUser ? 100 : 90,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              status.caption,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
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
            // Top Gradient Overlay for Readability
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
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
                              : null,
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
                bottom: 20,
                left: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showStatusDetailsSheet(
                              _currentGroup[_currentIndex],
                            ),
                            icon: const huge.HugeIcon(
                              icon: huge.HugeIcons.strokeRoundedView,
                              color: Colors.white,
                              size: 20,
                            ),
                            label: Text(
                              '${_currentGroup[_currentIndex].viewers.map((v) => v.uid).toSet().length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),

                          IconButton(
                            icon: const huge.HugeIcon(
                              icon: huge.HugeIcons.strokeRoundedShare01,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              final status = _currentGroup[_currentIndex];
                              String shareText =
                                  'Check out my status on Cuqter!';
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
                            icon: const huge.HugeIcon(
                              icon: huge.HugeIcons.strokeRoundedDelete02,
                              color: Colors.redAccent,
                              size: 20,
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
                ),
              ),

            // Reply field & Like button for other users
            if (_currentUserId == null ||
                _currentGroup[_currentIndex].uid != _currentUserId)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () {}, // Prevent tap from bubbling to next status
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: TextField(
                              focusNode: _replyFocusNode,
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
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.4),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                suffixIcon: _replyFocusNode.hasFocus
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ...['😂', '😍', '😢', '🔥'].map(
                                            (emoji) => GestureDetector(
                                              onTap: () => _sendReply(
                                                _currentGroup[_currentIndex],
                                                messageOverride: emoji,
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6.0,
                                                    ),
                                                child: Text(
                                                  emoji,
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const huge.HugeIcon(
                                              icon: huge
                                                  .HugeIcons
                                                  .strokeRoundedSent,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            onPressed: () => _sendReply(
                                              _currentGroup[_currentIndex],
                                            ),
                                          ),
                                        ],
                                      )
                                    : IconButton(
                                        icon: const huge.HugeIcon(
                                          icon:
                                              huge.HugeIcons.strokeRoundedSent,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        onPressed: () => _sendReply(
                                          _currentGroup[_currentIndex],
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              padding: const EdgeInsets.all(12),
                              icon: TweenAnimationBuilder<double>(
                                key: ValueKey(isLikedByMe),
                                tween: Tween(begin: 0.7, end: 1.0),
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.elasticOut,
                                builder: (context, scale, child) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: huge.HugeIcon(
                                      icon:
                                          huge.HugeIcons.strokeRoundedFavourite,
                                      color: isLikedByMe
                                          ? Colors.redAccent
                                          : Colors.white,
                                      size: 22,
                                    ),
                                  );
                                },
                              ),
                              onPressed: () => _toggleLike(currentStatus),
                            ),
                          ),
                        ),
                      ),
                    ], // close Row children
                  ), // close Row
                ), // close GestureDetector
              ), // close Positioned
            if (_showHeartOverlay)
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1.2),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: const huge.HugeIcon(
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
