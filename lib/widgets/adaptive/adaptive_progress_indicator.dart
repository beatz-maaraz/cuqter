import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuqter/providers/theme_provider.dart';

class AdaptiveProgressIndicator extends StatelessWidget {
  final Color? color;
  final double radius;
  final double? value;

  const AdaptiveProgressIndicator({
    super.key,
    this.color,
    this.radius = 12.0,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = color ?? themeProvider.primaryColor;

    if (themeProvider.isCupertino) {
      return CupertinoActivityIndicator(
        radius: radius,
        color: primaryColor,
      );
    } else {
      return CircularProgressIndicator(
        value: value,
        color: primaryColor,
        strokeWidth: 3,
      );
    }
  }
}
