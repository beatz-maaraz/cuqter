import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuqter/providers/theme_provider.dart';

class AdaptiveDialogAction {
  final Widget child;
  final VoidCallback onPressed;
  final bool isDefaultAction;
  final bool isDestructiveAction;

  const AdaptiveDialogAction({
    required this.child,
    required this.onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
  });
}

class AdaptiveDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<AdaptiveDialogAction> actions;

  const AdaptiveDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });

  static Future<T?> show<T>({
    required BuildContext context,
    Widget? title,
    Widget? content,
    List<AdaptiveDialogAction> actions = const [],
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    if (themeProvider.isCupertino) {
      return showCupertinoDialog<T>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: title,
          content: content,
          actions: actions
              .map(
                (action) => CupertinoDialogAction(
                  onPressed: action.onPressed,
                  isDefaultAction: action.isDefaultAction,
                  isDestructiveAction: action.isDestructiveAction,
                  child: action.child,
                ),
              )
              .toList(),
        ),
      );
    } else {
      return showDialog<T>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: title,
          content: content,
          actions: actions
              .map(
                (action) => TextButton(
                  onPressed: action.onPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: action.isDestructiveAction
                        ? Colors.red
                        : themeProvider.primaryColor,
                  ),
                  child: action.child,
                ),
              )
              .toList(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (themeProvider.isCupertino) {
      return CupertinoAlertDialog(
        title: title,
        content: content,
        actions: actions
            .map(
              (action) => CupertinoDialogAction(
                onPressed: action.onPressed,
                isDefaultAction: action.isDefaultAction,
                isDestructiveAction: action.isDestructiveAction,
                child: action.child,
              ),
            )
            .toList(),
      );
    } else {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: title,
        content: content,
        actions: actions
            .map(
              (action) => TextButton(
                onPressed: action.onPressed,
                style: TextButton.styleFrom(
                  foregroundColor: action.isDestructiveAction
                      ? Colors.red
                      : themeProvider.primaryColor,
                ),
                child: action.child,
              ),
            )
            .toList(),
      );
    }
  }
}
