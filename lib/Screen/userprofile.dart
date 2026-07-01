import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import '../widgets/full_screen_profile_pic_page.dart';

class UserProfilePage extends StatefulWidget {
  final String name;
  final String username;
  final String bio;
  final String profilepic;

  const UserProfilePage({
    super.key,
    required this.name,
    required this.username,
    required this.bio,
    required this.profilepic,
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: 20),
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
                  radius: 50,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  backgroundImage: widget.profilepic.isNotEmpty
                      ? (widget.profilepic.startsWith('http')
                          ? NetworkImage(widget.profilepic)
                          : AssetImage(widget.profilepic)) as ImageProvider
                      : null,
                  child: widget.profilepic.isEmpty
                      ? Icon(Icons.person, size: 50, color: colorScheme.onSurfaceVariant)
                      : null,
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(widget.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            Text(
              widget.username.isNotEmpty ? '@${widget.username}' : '',
              style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            SizedBox(height: 20),
            if (widget.bio.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                width: MediaQuery.of(context).size.width * 0.8,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    widget.bio,
                    style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            SizedBox(height: 20),
            Container(
              width: MediaQuery.of(context).size.width * 0.8,
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
                      Navigator.pop(context);
                    },
                    icon: huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedChat01, color: colorScheme.onSurface, size: 24),
                  ),
                  IconButton(
                    onPressed: () => _showCallComingSoon(context, isVideo: true),
                    icon: huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedVideo01, color: colorScheme.onSurface, size: 24),
                  ),
                  IconButton(
                    onPressed: () => _showCallComingSoon(context, isVideo: false),
                    icon: huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedCall, color: colorScheme.onSurface, size: 24),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            Container(
              height: MediaQuery.of(context).size.height * 0.3,
              width: MediaQuery.of(context).size.width * 0.8,
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
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedHelpCircle, color: colorScheme.onSurfaceVariant, size: 24),
                      onPressed: () {},
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        "Information",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const TwoHeartsAnimation(),
                        const SizedBox(height: 16),
                        Text(
                          "This feature only for Luv Colab",
                          style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            "Connect on a deeper level. Exclusive interactive features are coming soon.",
                            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                            textAlign: TextAlign.center,
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
    );
  }
}

class TwoHeartsAnimation extends StatefulWidget {
  const TwoHeartsAnimation({super.key});

  @override
  State<TwoHeartsAnimation> createState() => _TwoHeartsAnimationState();
}

class _TwoHeartsAnimationState extends State<TwoHeartsAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _moveLeft;
  late Animation<double> _moveRight;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    
    _moveLeft = Tween<double>(begin: -40.0, end: -6.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)),
    );
    _moveRight = Tween<double>(begin: 40.0, end: 6.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40), 
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 10), 
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 10),  
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 10), 
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 10),  
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 20), 
    ]).animate(_controller);
    
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 10), 
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70), 
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 20), 
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
                    child: Icon(Icons.favorite, color: Colors.pinkAccent, size: 40),
                  ),
                  Transform.translate(
                    offset: Offset(_moveRight.value, 0),
                    child: Icon(Icons.favorite, color: Colors.redAccent, size: 40),
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
