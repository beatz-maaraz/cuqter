import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuqter/providers/theme_provider.dart';

class AdaptiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double? borderRadius;

  const AdaptiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = themeProvider.isDarkMode;
    final radius = BorderRadius.circular(borderRadius ?? (themeProvider.isCupertino ? 20.0 : 24.0));

    if (themeProvider.isCupertino) {
      final cardColor = color ?? (isDark ? const Color(0xFF1C1C1E) : Colors.white);

      Widget container = Container(
        margin: margin ?? const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: radius,
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: isDark ? 0.12 : 0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );

      if (onTap != null) {
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: container,
        );
      }
      return container;
    } else {
      // Material Design 3 Card
      final cardColor = color ?? (isDark ? const Color(0xFF1E1E2E) : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5));

      return Container(
        margin: margin ?? const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        child: Material(
          color: cardColor,
          borderRadius: radius,
          elevation: isDark ? 0 : 1,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      );
    }
  }
}
