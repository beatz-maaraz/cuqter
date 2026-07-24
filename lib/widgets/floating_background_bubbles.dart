import 'package:flutter/material.dart';

class FloatingBackgroundBubbles extends StatelessWidget {
  final List<IconData>? customIcons;

  const FloatingBackgroundBubbles({
    super.key,
    this.customIcons,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    final icons = customIcons ?? const [
      Icons.forum_outlined,
      Icons.send_rounded,
      Icons.add_reaction_outlined,
      Icons.chat_bubble_outline_rounded,
      Icons.sms_outlined,
      Icons.alternate_email_rounded,
    ];

    return Stack(
      children: [
        // Top-Left Icon
        Positioned(
          top: 40,
          left: 20,
          child: AnimatedFloatingBubbleIcon(
            duration: const Duration(seconds: 5),
            offsetDelta: const Offset(14, -20),
            rotateDelta: 0.1,
            child: Opacity(
              opacity: 0.12,
              child: Icon(icons[0], size: 90, color: primaryColor),
            ),
          ),
        ),
        // Top-Right Icon
        Positioned(
          top: 160,
          right: 35,
          child: AnimatedFloatingBubbleIcon(
            duration: const Duration(seconds: 4),
            offsetDelta: const Offset(-12, 16),
            rotateDelta: -0.08,
            child: Opacity(
              opacity: 0.10,
              child: Icon(icons.length > 1 ? icons[1] : icons[0], size: 70, color: primaryColor),
            ),
          ),
        ),
        // Middle-Left Icon
        Positioned(
          top: 320,
          left: 15,
          child: AnimatedFloatingBubbleIcon(
            duration: const Duration(seconds: 6),
            offsetDelta: const Offset(10, -12),
            rotateDelta: 0.12,
            child: Opacity(
              opacity: 0.09,
              child: Icon(icons.length > 2 ? icons[2] : icons[0], size: 55, color: secondaryColor),
            ),
          ),
        ),
        // Middle-Right Icon
        Positioned(
          bottom: 300,
          right: 25,
          child: AnimatedFloatingBubbleIcon(
            duration: const Duration(seconds: 5),
            offsetDelta: const Offset(-16, -14),
            rotateDelta: -0.09,
            child: Opacity(
              opacity: 0.11,
              child: Icon(icons.length > 3 ? icons[3] : icons[0], size: 65, color: secondaryColor),
            ),
          ),
        ),
        // Bottom-Left Icon
        Positioned(
          bottom: 160,
          left: 30,
          child: AnimatedFloatingBubbleIcon(
            duration: const Duration(seconds: 7),
            offsetDelta: const Offset(15, 18),
            rotateDelta: 0.08,
            child: Opacity(
              opacity: 0.10,
              child: Icon(icons.length > 4 ? icons[4] : icons[0], size: 80, color: secondaryColor),
            ),
          ),
        ),
        // Bottom-Right Icon
        Positioned(
          bottom: 50,
          right: 20,
          child: AnimatedFloatingBubbleIcon(
            duration: const Duration(seconds: 4),
            offsetDelta: const Offset(-10, -22),
            rotateDelta: -0.1,
            child: Opacity(
              opacity: 0.12,
              child: Icon(icons.length > 5 ? icons[5] : icons[0], size: 95, color: primaryColor),
            ),
          ),
        ),
      ],
    );
  }
}

class AnimatedFloatingBubbleIcon extends StatefulWidget {
  final Widget child;
  final Offset offsetDelta;
  final double rotateDelta;
  final Duration duration;

  const AnimatedFloatingBubbleIcon({
    super.key,
    required this.child,
    this.offsetDelta = const Offset(12, -18),
    this.rotateDelta = 0.08,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<AnimatedFloatingBubbleIcon> createState() => _AnimatedFloatingBubbleIconState();
}

class _AnimatedFloatingBubbleIconState extends State<AnimatedFloatingBubbleIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double val = _animation.value;
        final Offset currentOffset = Offset(
          widget.offsetDelta.dx * val,
          widget.offsetDelta.dy * val,
        );
        final double currentAngle = widget.rotateDelta * val;

        return Transform.translate(
          offset: currentOffset,
          child: Transform.rotate(
            angle: currentAngle,
            child: widget.child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
