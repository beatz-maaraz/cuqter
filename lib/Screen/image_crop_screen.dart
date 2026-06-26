import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ImageCropScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const ImageCropScreen({Key? key, required this.imageBytes}) : super(key: key);

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final TransformationController _transformationController = TransformationController();
  ui.Image? _decodedImage;
  bool _isProcessing = false;
  double _viewportSize = 300.0;
  double _cutoutSize = 250.0;
  double _minScale = 1.0;
  bool _initializedSizes = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedSizes) {
      final double screenWidth = MediaQuery.of(context).size.width;
      _viewportSize = screenWidth;
      _cutoutSize = screenWidth * 0.75;
      _initializedSizes = true;
      _resetTransformation();
    }
  }

  Future<void> _loadImage() async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(widget.imageBytes);
      final ui.FrameInfo fi = await codec.getNextFrame();
      setState(() {
        _decodedImage = fi.image;
      });
      _resetTransformation();
    } catch (e) {
      print('Error decoding image: $e');
    }
  }

  void _resetTransformation() {
    if (_decodedImage == null) return;
    
    final double imgW = _decodedImage!.width.toDouble();
    final double imgH = _decodedImage!.height.toDouble();
    
    // Fit image inside the viewport
    final double scaleX = _viewportSize / imgW;
    final double scaleY = _viewportSize / imgH;
    final double scale = scaleX > scaleY ? scaleX : scaleY; // Cover fit
    
    _minScale = scale;
    
    final double dx = (_viewportSize - imgW * scale) / 2;
    final double dy = (_viewportSize - imgH * scale) / 2;

    _transformationController.value = Matrix4.translationValues(dx, dy, 0.0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0));
  }

  Future<void> _cropAndSave() async {
    if (_decodedImage == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final double cutoutLeft = (_viewportSize - _cutoutSize) / 2;
      final double cutoutTop = (_viewportSize - _cutoutSize) / 2;

      // Target cropped image resolution
      const double targetSize = 500.0;
      final double scaleFactor = targetSize / _cutoutSize;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // 1. Scale from cutout space to target size
      canvas.scale(scaleFactor);
      
      // 2. Shift so the cutout's top-left is at (0,0)
      canvas.translate(-cutoutLeft, -cutoutTop);
      
      // 3. Apply the user's interactive transformation
      canvas.transform(_transformationController.value.storage);
      
      // 4. Draw the original high-resolution image
      canvas.drawImage(_decodedImage!, Offset.zero, Paint()..filterQuality = ui.FilterQuality.high);

      final ui.Picture picture = recorder.endRecording();
      final ui.Image croppedImage = await picture.toImage(targetSize.toInt(), targetSize.toInt());
      
      final ByteData? pngByteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      if (pngByteData != null) {
        final Uint8List croppedBytes = pngByteData.buffer.asUint8List();
        if (mounted) {
          Navigator.pop(context, croppedBytes);
        }
      } else {
        throw Exception("Failed to convert cropped image to byte data");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cropping image: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Background Gradient Colors
    final bgColors = isDark
        ? [Colors.black, const Color(0xFF0F172A)]
        : [colorScheme.surface, colorScheme.surfaceContainerHighest];

    // Cutout Overlay Colors
    final overlayColor = isDark
        ? Colors.black.withValues(alpha: 0.75)
        : colorScheme.onSurface.withValues(alpha: 0.75);
    final cutoutBorderColor = isDark ? Colors.white : colorScheme.primary;

    // Bottom Panel Colors
    final bottomPanelBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : colorScheme.surface.withValues(alpha: 0.75);
    final bottomPanelBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : colorScheme.onSurface.withValues(alpha: 0.1);
    final bottomPanelGradientColors = isDark
        ? [Colors.white.withValues(alpha: 0.07), Colors.white.withValues(alpha: 0.02)]
        : [colorScheme.surface.withValues(alpha: 0.8), colorScheme.surface.withValues(alpha: 0.4)];
    
    // Bottom Panel Text & Cancel Button
    final cancelBtnBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : colorScheme.onSurface.withValues(alpha: 0.2);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Crop Photo',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.onSurface.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: colorScheme.onSurface, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.onSurface.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: colorScheme.onSurface, size: 20),
              onPressed: _resetTransformation,
              tooltip: 'Reset Zoom',
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _decodedImage == null
            ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
            : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Interactive image container
                          ClipRect(
                            child: SizedBox(
                              width: _viewportSize,
                              height: _viewportSize,
                              child: InteractiveViewer(
                                transformationController: _transformationController,
                                boundaryMargin: EdgeInsets.zero,
                                minScale: _minScale,
                                maxScale: _minScale * 5.0,
                                child: Image.memory(
                                  widget.imageBytes,
                                  fit: BoxFit.none,
                                  width: _decodedImage!.width.toDouble(),
                                  height: _decodedImage!.height.toDouble(),
                                ),
                              ),
                            ),
                          ),
                          // Dark overlay with circular cutout window
                          IgnorePointer(
                            child: CustomPaint(
                              size: Size(_viewportSize, _viewportSize),
                              painter: CutoutOverlayPainter(
                                cutoutSize: _cutoutSize,
                                overlayColor: overlayColor,
                                borderColor: cutoutBorderColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: bottomPanelBg,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: bottomPanelBorder,
                              width: 1.5,
                            ),
                            gradient: LinearGradient(
                              colors: bottomPanelGradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Drag to position • Pinch to zoom',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        side: BorderSide(
                                          color: cancelBtnBorderColor,
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          colors: [
                                            colorScheme.primary,
                                            colorScheme.secondary,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colorScheme.primary.withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: colorScheme.onPrimary,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                        ),
                                        onPressed: _isProcessing ? null : _cropAndSave,
                                        child: _isProcessing
                                            ? SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: colorScheme.onPrimary,
                                                ),
                                              )
                                            : const Text(
                                                'Save Photo',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class CutoutOverlayPainter extends CustomPainter {
  final double cutoutSize;
  final Color overlayColor;
  final Color borderColor;

  CutoutOverlayPainter({
    required this.cutoutSize,
    required this.overlayColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = overlayColor;
    
    final cutoutLeft = (size.width - cutoutSize) / 2;
    final cutoutTop = (size.height - cutoutSize) / 2;

    // Path representing the outer rectangle
    final Path path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Path representing the inner cutout circle
    final Path cutoutPath = Path()
      ..addOval(Rect.fromLTWH(cutoutLeft, cutoutTop, cutoutSize, cutoutSize));

    // Combine them to get a hole in the overlay
    final Path overlayPath = Path.combine(PathOperation.difference, path, cutoutPath);

    canvas.drawPath(overlayPath, paint);

    // Draw subtle shadow behind the border for high contrast against any image content
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    
    canvas.drawOval(
      Rect.fromLTWH(cutoutLeft, cutoutTop, cutoutSize, cutoutSize),
      shadowPaint,
    );

    // Draw high-contrast circular border around the cutout
    final Paint borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    
    canvas.drawOval(
      Rect.fromLTWH(cutoutLeft, cutoutTop, cutoutSize, cutoutSize),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CutoutOverlayPainter oldDelegate) {
    return oldDelegate.cutoutSize != cutoutSize || oldDelegate.overlayColor != overlayColor || oldDelegate.borderColor != borderColor;
  }
}
