import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/full_screen_profile_pic_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  final String name;
  final String username;
  final String bio;
  final String profilepic;
  final bool isFriend;
  final bool isRequested;

  const UserProfilePage({
    super.key,
    required this.userId,
    required this.name,
    required this.username,
    required this.bio,
    required this.profilepic,
    this.isFriend = false,
    this.isRequested = false,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
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
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
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

  bool _localIsRequested = false;
  Stream<DocumentSnapshot>? _currentUserStream;
  Stream<DocumentSnapshot>? _friendRequestStream;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _localIsRequested = widget.isRequested;

    if (_currentUserId != null) {
      _currentUserStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .snapshots();
      _friendRequestStream = FirebaseFirestore.instance
          .collection('friend_requests')
          .doc('${_currentUserId}_${widget.userId}')
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username.isNotEmpty ? widget.username : widget.name),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${widget.username}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (widget.profilepic.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenProfilePicPage(
                                imageUrl: widget.profilepic,
                                heroTag: 'profile_pic_hero_${widget.username}',
                              ),
                            ),
                          );
                        }
                      },
                      child: Hero(
                        tag: 'profile_pic_hero_${widget.username}',
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          backgroundImage: widget.profilepic.isNotEmpty
                              ? (widget.profilepic.startsWith('http')
                                        ? CachedNetworkImageProvider(
                                            widget.profilepic,
                                          )
                                        : AssetImage(widget.profilepic))
                                    as ImageProvider
                              : null,
                          child: widget.profilepic.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 40,
                                  color: colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (widget.bio.isNotEmpty) ...[
                  Text(
                    widget.bio,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                ],
                Center(
                  child: OutlinedButton(
                    onPressed: () {
                      // Action to follow
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      side: BorderSide(color: colorScheme.primary, width: 1.5),
                    ),
                    child: Text(
                      'Follow',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // Chat and Call actions
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: () {
                          // navigate to chat
                        },
                        icon: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedChat01,
                          color: colorScheme.onSurface,
                          size: 24,
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            _showCallComingSoon(context, isVideo: true),
                        icon: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedVideo01,
                          color: colorScheme.onSurface,
                          size: 24,
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            _showCallComingSoon(context, isVideo: false),
                        icon: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedCall,
                          color: colorScheme.onSurface,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Luv Colab Banner
                Center(
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.2,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primaryContainer.withValues(alpha: 0.7),
                          colorScheme.tertiaryContainer.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const TwoHeartsAnimation(),
                              const SizedBox(height: 16),
                              Text(
                                "Luv Colab",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: StreamBuilder<DocumentSnapshot>(
                stream: _currentUserStream,
                builder: (context, userSnapshot) {
                  bool isFriend = widget.isFriend;
                  if (userSnapshot.hasData &&
                      userSnapshot.data?.exists == true) {
                    var data =
                        userSnapshot.data!.data() as Map<String, dynamic>?;
                    if (data != null) {
                      List<dynamic> contacts = data['contacts'] ?? [];
                      isFriend = contacts.contains(widget.userId);
                    }
                  }

                  return StreamBuilder<DocumentSnapshot>(
                    stream: _friendRequestStream,
                    builder: (context, requestSnapshot) {
                      bool isRequested = _localIsRequested;
                      if (requestSnapshot.hasData &&
                          requestSnapshot.data?.exists == true) {
                        var reqData =
                            requestSnapshot.data!.data()
                                as Map<String, dynamic>?;
                        if (reqData != null && reqData['status'] == 'pending') {
                          isRequested = true;
                        } else {
                          isRequested = false;
                        }
                      }

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              if (isFriend) return;
                              if (_currentUserId == null) return;

                              String requestId = '${_currentUserId}_${widget.userId}';

                              if (isRequested) {
                                // Cancel request
                                setState(() {
                                  _localIsRequested = false;
                                });
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('friend_requests')
                                      .doc(requestId)
                                      .delete();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Friend request cancelled')),
                                    );
                                  }
                                } catch (e) {
                                  setState(() {
                                    _localIsRequested = true;
                                  });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to cancel request')),
                                    );
                                  }
                                }
                              } else {
                                // Send request
                                setState(() {
                                  _localIsRequested = true;
                                });

                                try {
                                  DocumentSnapshot myDoc = await FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .doc(_currentUserId)
                                      .get();
                                  String myName = (myDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown User';
                                  String myPic = (myDoc.data() as Map<String, dynamic>?)?['profilepic'] ?? '';

                                  await FirebaseFirestore.instance
                                      .collection('friend_requests')
                                      .doc(requestId)
                                      .set({
                                        'senderId': _currentUserId,
                                        'receiverId': widget.userId,
                                        'status': 'pending',
                                        'senderName': myName,
                                        'senderProfilePic': myPic,
                                        'timestamp': FieldValue.serverTimestamp(),
                                      });

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Friend request sent!')),
                                    );
                                  }
                                } catch (e) {
                                  setState(() {
                                    _localIsRequested = false;
                                  });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to send request')),
                                    );
                                  }
                                }
                              }
                            },
                            icon: Icon(
                              isFriend
                                  ? Icons.check
                                  : (isRequested
                                        ? Icons.access_time
                                        : Icons.person_add),
                              size: 20,
                            ),
                            label: Text(
                              isFriend
                                  ? 'Friend'
                                  : (isRequested ? 'Requested' : 'Add Friend'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFriend || isRequested
                                  ? colorScheme.secondaryContainer
                                  : colorScheme.primary,
                              foregroundColor: isFriend || isRequested
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 6,
                              shadowColor: colorScheme.primary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          if (isFriend) ...[
                            const SizedBox(width: 12),
                            AnimatedThreeDotsMenu(
                              colorScheme: colorScheme,
                              onRemove: () async {
                                if (_currentUserId != null) {
                                  try {
                                    await FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
                                      'contacts': FieldValue.arrayRemove([widget.userId])
                                    });
                                    await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
                                      'contacts': FieldValue.arrayRemove([_currentUserId])
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Removed from friend list')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Failed to remove friend')),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TwoHeartsAnimation extends StatefulWidget {
  const TwoHeartsAnimation({super.key});

  @override
  State<TwoHeartsAnimation> createState() => _TwoHeartsAnimationState();
}

class _TwoHeartsAnimationState extends State<TwoHeartsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _moveLeft;
  late Animation<double> _moveRight;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _moveLeft = Tween<double>(begin: -40.0, end: -6.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );
    _moveRight = Tween<double>(begin: 40.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 20),
    ]).animate(_controller);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_controller);

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: SizedBox(
              width: 100,
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(_moveLeft.value, 0),
                    child: Icon(
                      Icons.favorite,
                      color: Colors.pinkAccent,
                      size: 40,
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(_moveRight.value, 0),
                    child: Icon(
                      Icons.favorite,
                      color: Colors.redAccent,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AnimatedThreeDotsMenu extends StatefulWidget {
  final ColorScheme colorScheme;
  final VoidCallback? onRemove;
  final VoidCallback? onBlock;
  final VoidCallback? onFavorite;

  const AnimatedThreeDotsMenu({
    super.key,
    required this.colorScheme,
    this.onRemove,
    this.onBlock,
    this.onFavorite,
  });

  @override
  State<AnimatedThreeDotsMenu> createState() => _AnimatedThreeDotsMenuState();
}

class _AnimatedThreeDotsMenuState extends State<AnimatedThreeDotsMenu>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (_isOpen) {
      _overlayEntry?.remove();
    }
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _showMenu();
    }
  }

  void _showMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();
    setState(() {
      _isOpen = true;
    });
  }

  void _closeMenu() {
    _animationController.reverse().then((_) {
      if (_isOpen && mounted) {
        _overlayEntry?.remove();
        _overlayEntry = null;
        setState(() {
          _isOpen = false;
        });
      }
    });
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closeMenu,
            child: Container(
              color: Colors.transparent,
            ),
          ),
          Positioned(
            width: 160,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(-112, -165),
              child: Material(
                color: Colors.transparent,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  alignment: Alignment.bottomRight,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: widget.colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMenuItem(Icons.person_remove_rounded, 'Remove', () {
                            _closeMenu();
                            if (widget.onRemove != null) widget.onRemove!();
                          }),
                          Divider(height: 1, color: widget.colorScheme.onSurface.withValues(alpha: 0.1)),
                          _buildMenuItem(Icons.block_rounded, 'Block', () {
                            _closeMenu();
                            if (widget.onBlock != null) widget.onBlock!();
                          }),
                          Divider(height: 1, color: widget.colorScheme.onSurface.withValues(alpha: 0.1)),
                          _buildMenuItem(Icons.favorite_border_rounded, 'Favorite', () {
                            _closeMenu();
                            if (widget.onFavorite != null) widget.onFavorite!();
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: widget.colorScheme.onSurface),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: widget.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        decoration: BoxDecoration(
          color: widget.colorScheme.secondaryContainer,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.colorScheme.primary.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(Icons.more_horiz, color: widget.colorScheme.onSecondaryContainer),
          onPressed: _toggleMenu,
        ),
      ),
    );
  }
}
