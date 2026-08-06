import 'package:flutter/material.dart';

enum WallpaperType { theme, color, asset, network }

class ChatWallpaper {
  final WallpaperType type;
  final Color? color;
  final String? path;
  final BoxFit fit;

  ChatWallpaper({
    required this.type,
    this.color,
    this.path,
    this.fit = BoxFit.cover,
  });

  static List<ChatWallpaper> defaultWallpapers = [
    ChatWallpaper(type: WallpaperType.theme), // Automatically adapts to light/dark mode
    ChatWallpaper(type: WallpaperType.asset, path: 'assets/Wallpaper/1.png'),
  ];
}
