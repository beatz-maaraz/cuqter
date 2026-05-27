import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart' as huge;

class AnimatedSendButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;
  final double iconSize;
  final double radius;

  const AnimatedSendButton({
    super.key,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
    this.iconSize = 22.0,
    this.radius = 24.0,
  });

  @override
  State<AnimatedSendButton> createState() => _AnimatedSendButtonState();
}

class _AnimatedSendButtonState extends State<AnimatedSendButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.7).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.7, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 80.0,
      ),
    ]).animate(_controller);

    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -0.2).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.2, end: 0.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 80.0,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap();
    // Play the animation
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: CircleAvatar(
        backgroundColor: widget.backgroundColor,
        radius: widget.radius,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value,
                child: child,
              ),
            );
          },
          child: Padding(
            // Add slight padding to center the icon better if needed,
            // visually hugeicons sometimes need slight alignment
            padding: const EdgeInsets.only(left: 2.0),
            child: huge.HugeIcon(
              icon: huge.HugeIcons.strokeRoundedSent,
              color: widget.iconColor,
              size: widget.iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
