import 'package:flutter/material.dart';

enum WallpaperType { color, asset, network }

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
    ChatWallpaper(type: WallpaperType.color, color: Colors.white),
    ChatWallpaper(type: WallpaperType.asset, path: 'assets/Wallpaper/1.png'),
    ChatWallpaper(type: WallpaperType.color, color: const Color(0xFFFEF3C7)), // Amber 50
    ChatWallpaper(type: WallpaperType.color, color: const Color(0xFFEFF6FF)), // Blue 50
    ChatWallpaper(type: WallpaperType.color, color: const Color(0xFFF0FDF4)), // Green 50
    ChatWallpaper(type: WallpaperType.color, color: const Color(0xFFFAF5FF)), // Purple 50
  ];
}
