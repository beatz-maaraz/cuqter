import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuqter/providers/theme_provider.dart';

class AdaptiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const AdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = activeColor ?? themeProvider.primaryColor;

    if (themeProvider.isCupertino) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: primaryColor,
      );
    } else {
      return Switch(
        value: value,
        onChanged: onChanged,
        activeColor: primaryColor,
      );
    }
  }
}
