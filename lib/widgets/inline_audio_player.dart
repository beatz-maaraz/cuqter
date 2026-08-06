import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class InlineAudioPlayer extends StatefulWidget {
  final String source;
  final bool isLocal;
  final ColorScheme colorScheme;
  final bool isMe;
  final String fileName;
  final String fileSize;
  final String titlePrefix;

  const InlineAudioPlayer({
    Key? key,
    required this.source,
    required this.isLocal,
    required this.colorScheme,
    required this.isMe,
    required this.fileName,
    required this.fileSize,
    required this.titlePrefix,
  }) : super(key: key);

  @override
  State<InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<InlineAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
    
    _audioPlayer.onPlayerComplete.listen((event) async {
      if (mounted) {
        await _audioPlayer.seek(Duration.zero);
        setState(() {
          _position = Duration.zero;
          _isPlaying = false;
        });
      }
    });

    _setSource();
  }
  
  Future<void> _setSource() async {
    try {
      if (kIsWeb) {
        await _audioPlayer.setSourceUrl(widget.source);
      } else if (widget.isLocal) {
        await _audioPlayer.setSourceDeviceFile(widget.source);
      } else {
        await _audioPlayer.setSourceUrl(widget.source);
      }
    } catch (e) {
      debugPrint('Error setting audio source: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isMe
        ? widget.colorScheme.onPrimaryContainer
        : widget.colorScheme.onSurfaceVariant;
    final iconColor = widget.isMe ? widget.colorScheme.onPrimaryContainer : widget.colorScheme.primary;

    final double progress = _duration.inMilliseconds > 0 
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: 280, // Fixed width for consistent bubble size
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.white.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Side: Waveform and Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Filename
                Text(
                  widget.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                // Waveform Slider
                SimulatedWaveformSlider(
                  progress: progress,
                  activeColor: iconColor,
                  inactiveColor: iconColor.withValues(alpha: 0.3),
                  seedString: widget.source,
                  onChanged: (p) async {
                    final newMillis = (p * _duration.inMilliseconds).toInt();
                    await _audioPlayer.seek(Duration(milliseconds: newMillis));
                  },
                ),
                const SizedBox(height: 8),
                // Time and File Size
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      widget.fileSize.isNotEmpty
                          ? '${widget.titlePrefix} • ${widget.fileSize}'
                          : '${widget.titlePrefix} Message',
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right Side: Play/Pause Button
          InkWell(
            onTap: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                if (_position > Duration.zero && _position < _duration) {
                  await _audioPlayer.resume();
                } else {
                  if (kIsWeb) {
                    await _audioPlayer.play(UrlSource(widget.source));
                  } else if (widget.isLocal) {
                    await _audioPlayer.play(DeviceFileSource(widget.source));
                  } else {
                    await _audioPlayer.play(UrlSource(widget.source));
                  }
                }
              }
            },
            borderRadius: BorderRadius.circular(25),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isMe ? widget.colorScheme.primary : Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SimulatedWaveformSlider extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<double> onChanged;
  final String seedString;

  const SimulatedWaveformSlider({
    Key? key,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.onChanged,
    required this.seedString,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _handleTapOrDrag(details.localPosition.dx, constraints.maxWidth),
          onPanUpdate: (details) => _handleTapOrDrag(details.localPosition.dx, constraints.maxWidth),
          child: CustomPaint(
            size: Size(constraints.maxWidth, 30), // Waveform height
            painter: WaveformPainter(
              progress: progress,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              seedString: seedString,
            ),
          ),
        );
      },
    );
  }

  void _handleTapOrDrag(double dx, double width) {
    double p = dx / width;
    if (p < 0.0) p = 0.0;
    if (p > 1.0) p = 1.0;
    onChanged(p);
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final String seedString;

  WaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.seedString,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int barCount = 35; // number of bars
    final double barWidth = 3.0;
    final double spacing = (size.width - (barCount * barWidth)) / (barCount - 1);
    
    // Simple deterministic random generator based on seed string
    final seed = seedString.hashCode;
    final random = Random(seed);

    final Paint activePaint = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final Paint inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (int i = 0; i < barCount; i++) {
      // Random height between 20% and 100% of max height
      final double normalizedHeight = 0.2 + random.nextDouble() * 0.8;
      final double barHeight = size.height * normalizedHeight;
      
      final double x = i * (barWidth + spacing);
      final double yStart = (size.height - barHeight) / 2;
      final double yEnd = yStart + barHeight;

      final double barProgress = i / barCount;
      final Paint paint = barProgress <= progress ? activePaint : inactivePaint;

      canvas.drawLine(Offset(x, yStart), Offset(x, yEnd), paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.activeColor != activeColor ||
           oldDelegate.inactiveColor != inactiveColor ||
           oldDelegate.seedString != seedString;
  }
}
