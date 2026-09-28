import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color mainBackground = Color(0xFF121416);
  static const Color secondaryBackground = Color(0xFF1B1F1D);

  // Brand
  static const Color primaryBrand = Color(0xFF3A7D63);
  static const Color primaryLight = Color(0xFF79A994);

  // Messaging
  static const Color outgoingMessage = Color(0xFF285A47);
  static const Color incomingMessage = Color(0xFFE8E3D8);

  // Text
  static const Color userText = Color(0xFFF4F2EC);
  static const Color secondaryText = Color(0xFFA9B5AE);

  // Accent & States
  static const Color accent = Color(0xFFD4A85C);
  static const Color onlineSuccess = Color(0xFF55B879);
  static const Color warning = Color(0xFFE3A83B);
  static const Color errorFailed = Color(0xFFD95C5C);
  static const Color infoLinks = Color(0xFF5B9BD5);

  // Borders/Dividers
  static const Color divider = Color(0xFF2A332E);

  // Legacy mappings to prevent build errors
  static const Color primary = primaryBrand;
  static const Color secondary = primaryLight;
  static const Color background = mainBackground;
  static const Color card = secondaryBackground;
  static const Color text = userText;
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = secondaryText;
  static const Color blueDefault = primaryBrand;
}
