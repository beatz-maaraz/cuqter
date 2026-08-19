import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuqter/providers/theme_provider.dart';

enum AdaptiveButtonStyle {
  filled,
  outlined,
  text,
}

class AdaptiveButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final AdaptiveButtonStyle style;
  final Color? color;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Widget? icon;

  const AdaptiveButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style = AdaptiveButtonStyle.filled,
    this.color,
    this.textColor,
    this.padding,
    this.borderRadius,
    this.icon,
  });

  const AdaptiveButton.filled({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.textColor,
    this.padding,
    this.borderRadius,
    this.icon,
  }) : style = AdaptiveButtonStyle.filled;

  const AdaptiveButton.outlined({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.textColor,
    this.padding,
    this.borderRadius,
    this.icon,
  }) : style = AdaptiveButtonStyle.outlined;

  const AdaptiveButton.text({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.textColor,
    this.padding,
    this.borderRadius,
    this.icon,
  }) : style = AdaptiveButtonStyle.text;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = color ?? themeProvider.primaryColor;

    if (themeProvider.isCupertino) {
      final radius = BorderRadius.circular(borderRadius ?? 12.0);
      
      switch (style) {
        case AdaptiveButtonStyle.filled:
          return CupertinoButton.filled(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            borderRadius: radius,
            onPressed: onPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  icon!,
                  const SizedBox(width: 8),
                ],
                DefaultTextStyle(
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: textColor ?? CupertinoColors.white,
                  ),
                  child: child,
                ),
              ],
            ),
          );

        case AdaptiveButtonStyle.outlined:
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: primaryColor, width: 1.5),
              borderRadius: radius,
            ),
            child: CupertinoButton(
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              borderRadius: radius,
              onPressed: onPressed,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  DefaultTextStyle(
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: textColor ?? primaryColor,
                    ),
                    child: child,
                  ),
                ],
              ),
            ),
          );

        case AdaptiveButtonStyle.text:
          return CupertinoButton(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onPressed: onPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  icon!,
                  const SizedBox(width: 6),
                ],
                DefaultTextStyle(
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: textColor ?? primaryColor,
                  ),
                  child: child,
                ),
              ],
            ),
          );
      }
    } else {
      // Material Design
      final buttonShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 16.0),
      );

      switch (style) {
        case AdaptiveButtonStyle.filled:
          if (icon != null) {
            return FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: textColor ?? Colors.white,
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: buttonShape,
              ),
              onPressed: onPressed,
              icon: icon!,
              label: child,
            );
          }
          return FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: textColor ?? Colors.white,
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: buttonShape,
            ),
            onPressed: onPressed,
            child: child,
          );

        case AdaptiveButtonStyle.outlined:
          if (icon != null) {
            return OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor ?? primaryColor,
                side: BorderSide(color: primaryColor, width: 1.5),
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: buttonShape,
              ),
              onPressed: onPressed,
              icon: icon!,
              label: child,
            );
          }
          return OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: textColor ?? primaryColor,
              side: BorderSide(color: primaryColor, width: 1.5),
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: buttonShape,
            ),
            onPressed: onPressed,
            child: child,
          );

        case AdaptiveButtonStyle.text:
          if (icon != null) {
            return TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: textColor ?? primaryColor,
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: buttonShape,
              ),
              onPressed: onPressed,
              icon: icon!,
              label: child,
            );
          }
          return TextButton(
            style: TextButton.styleFrom(
              foregroundColor: textColor ?? primaryColor,
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: buttonShape,
            ),
            onPressed: onPressed,
            child: child,
          );
      }
    }
  }
}
