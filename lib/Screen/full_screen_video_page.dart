import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FullScreenVideoPage extends StatefulWidget {
  final String videoUrl;
  final String? localFilePath;

  const FullScreenVideoPage({
    Key? key,
    required this.videoUrl,
    this.localFilePath,
  }) : super(key: key);

  @override
  State<FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<FullScreenVideoPage> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _isPlaying = false;
  String? _errorMessage;

  String _getVideoPlayUrl(String url) {
    if (url.startsWith('http://')) {
      url = 'https://' + url.substring(7);
    }
    if (url.contains('res.cloudinary.com')) {
      final int lastDot = url.lastIndexOf('.');
      if (lastDot != -1) {
        return url.substring(0, lastDot) + '.mp4';
      }
    }
    return url;
  }

  @override
  void initState() {
    super.initState();
    final String? localPath = widget.localFilePath;
    if (localPath != null && File(localPath).existsSync()) {
      _controller = VideoPlayerController.file(File(localPath));
    } else {
      final String playUrl = _getVideoPlayUrl(widget.videoUrl);
      final String decodedUrl = Uri.decodeFull(playUrl.trim());
      final String encodedUrl = Uri.encodeFull(decodedUrl);
      _controller = VideoPlayerController.networkUrl(Uri.parse(encodedUrl));
    }
    _controller.initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
            _controller.play();
            _isPlaying = true;
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load video: $error';
          });
        }
      });

    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _isPlaying = _controller.value.isPlaying;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Player
          Center(
            child: _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : (_initialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            VideoPlayer(_controller),
                            // Custom controls overlay
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (_controller.value.isPlaying) {
                                    _controller.pause();
                                  } else {
                                    _controller.play();
                                  }
                                });
                              },
                              child: Container(
                                color: Colors.transparent,
                                child: Center(
                                  child: AnimatedOpacity(
                                    opacity: _isPlaying ? 0.0 : 1.0,
                                    duration: const Duration(milliseconds: 300),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Video progress bar
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: VideoProgressIndicator(
                                _controller,
                                allowScrubbing: true,
                                colors: VideoProgressColors(
                                  playedColor: colorScheme.primary,
                                  bufferedColor: Colors.white24,
                                  backgroundColor: Colors.white10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const CircularProgressIndicator()),
          ),
          
          // Glassmorphic Back Button
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
