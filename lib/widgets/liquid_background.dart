import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuqter/providers/theme_provider.dart';

class LiquidBackground extends StatefulWidget {
  final Widget child;

  const LiquidBackground({
    super.key,
    required this.child,
  });

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        if (!themeProvider.isLiquidBackgroundEnabled) {
          return widget.child;
        }

        final primaryColor = themeProvider.primaryColor;
        final secondaryColor = themeProvider.isDarkMode 
            ? primaryColor.withValues(alpha: 0.5) 
            : primaryColor.withValues(alpha: 0.3);

        return Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _LiquidBlobPainter(
                      progress: _controller.value,
                      primaryColor: primaryColor.withValues(alpha: themeProvider.liquidOpacity),
                      secondaryColor: secondaryColor.withValues(alpha: themeProvider.liquidOpacity * 0.7),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: max(0.1, themeProvider.liquidBlur), 
                  sigmaY: max(0.1, themeProvider.liquidBlur)
                ),
                child: Container(color: Colors.transparent),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

class _LiquidBlobPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  _LiquidBlobPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final paint1 = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    // Calculate moving positions based on progress (0.0 to 1.0)
    // using sine and cosine for smooth circular/elliptical motion
    final angle = progress * 2 * pi;

    // Blob 1 (Top right area)
    final dx1 = width * 0.7 + sin(angle) * (width * 0.3);
    final dy1 = height * 0.2 + cos(angle) * (height * 0.2);
    canvas.drawCircle(Offset(dx1, dy1), width * 0.4, paint1);

    // Blob 2 (Bottom left area)
    final dx2 = width * 0.3 + cos(angle * 1.5) * (width * 0.3);
    final dy2 = height * 0.8 + sin(angle * 1.5) * (height * 0.2);
    canvas.drawCircle(Offset(dx2, dy2), width * 0.45, paint2);

    // Blob 3 (Center area, moving in reverse)
    final dx3 = width * 0.5 + sin(-angle) * (width * 0.2);
    final dy3 = height * 0.5 + cos(-angle) * (height * 0.2);
    canvas.drawCircle(Offset(dx3, dy3), width * 0.35, paint1);
  }

  @override
  bool shouldRepaint(covariant _LiquidBlobPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.primaryColor != primaryColor ||
           oldDelegate.secondaryColor != secondaryColor;
  }
}
