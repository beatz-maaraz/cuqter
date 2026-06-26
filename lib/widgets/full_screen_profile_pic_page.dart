import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';

class FullScreenProfilePicPage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const FullScreenProfilePicPage({
    Key? key,
    required this.imageUrl,
    required this.heroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: imageUrl.startsWith('http')
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : (imageUrl.startsWith('/') || imageUrl.contains(':\\') || imageUrl.contains(':/'))
                        ? Image.file(
                            File(imageUrl),
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : Image.asset(
                            imageUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.1),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
