import 'package:flutter/material.dart';

/// Shows a custom styled SnackBar across the app with consistent Modern Vibrant aesthetics.
void showCustomSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      backgroundColor:
          isError ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.down,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
      duration: duration,
    ),
  );
}
