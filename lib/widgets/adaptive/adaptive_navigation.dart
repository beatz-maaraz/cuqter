import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuqter/providers/theme_provider.dart';

class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final double elevation;

  const AdaptiveAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.elevation = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (themeProvider.isCupertino) {
      return CupertinoNavigationBar(
        middle: title,
        leading: leading,
        trailing: actions != null && actions!.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!,
              )
            : null,
        automaticallyImplyLeading: automaticallyImplyLeading,
        backgroundColor: backgroundColor ??
            (themeProvider.isDarkMode
                ? const Color(0xFF1C1C1E).withValues(alpha: 0.85)
                : const Color(0xFFF9F9F9).withValues(alpha: 0.85)),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.10),
            width: 0.5,
          ),
        ),
      );
    } else {
      return AppBar(
        title: title,
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        backgroundColor: backgroundColor ?? Colors.transparent,
        elevation: elevation,
        centerTitle: true,
      );
    }
  }
}

class AdaptiveBottomTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;
  final Color? backgroundColor;

  const AdaptiveBottomTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.primaryColor;
    final isDark = themeProvider.isDarkMode;

    if (themeProvider.isCupertino) {
      return ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: CupertinoTabBar(
            currentIndex: currentIndex,
            onTap: onTap,
            activeColor: primaryColor,
            inactiveColor: isDark
                ? CupertinoColors.systemGrey
                : CupertinoColors.systemGrey2,
            backgroundColor: backgroundColor ??
                (isDark
                    ? const Color(0xFF1C1C1E).withValues(alpha: 0.75)
                    : const Color(0xFFF9F9F9).withValues(alpha: 0.85)),
            items: items,
          ),
        ),
      );
    } else {
      return NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        indicatorColor: primaryColor.withValues(alpha: 0.2),
        destinations: items.map((item) {
          return NavigationDestination(
            icon: item.icon,
            selectedIcon: item.activeIcon,
            label: item.label ?? '',
          );
        }).toList(),
      );
    }
  }
}
