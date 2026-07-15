import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class CustomCameraScreen extends StatefulWidget {
  const CustomCameraScreen({super.key});

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isReady = false;
  final ValueNotifier<bool> _isRecordingNotifier = ValueNotifier(false);
  bool get _isRecording => _isRecordingNotifier.value;
  
  int _selectedCameraIndex = 0;
  String _mode = 'PHOTO';
  
  FlashMode _flashMode = FlashMode.auto;
  String? _errorMessage;
  Timer? _recordTimer;
  
  final ValueNotifier<int> _recordDurationNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(_cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initCameras() async {
    try {
      if (!kIsWeb) {
        // First, request camera, microphone, and storage permissions explicitly
        final Map<Permission, PermissionStatus> statuses = await [
          Permission.camera,
          Permission.microphone,
          Permission.storage,
        ].request();

        if (statuses[Permission.camera] != PermissionStatus.granted) {
          setState(() {
            _errorMessage = "Camera permission is required to use this feature.";
          });
          return;
        }
      }

      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _initCameraController(_cameras[_selectedCameraIndex]);
      } else {
        setState(() {
          _errorMessage = "No cameras found on this device.";
        });
      }
    } catch (e) {
      debugPrint('Error initializing cameras: $e');
      setState(() {
        if (e.toString().contains("MissingPluginException")) {
          _errorMessage = "Native dependency missing.\nPlease completely STOP and RESTART the app.";
        } else {
          _errorMessage = "Camera initialization failed:\n$e";
        }
      });
    }
  }

  Future<void> _initCameraController(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = cameraController;

    try {
      await cameraController.initialize();
      try {
        if (!kIsWeb) {
          await cameraController.setFlashMode(_flashMode);
        }
      } catch (e) {
        debugPrint('Flash not supported on this camera: $e');
      }
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _switchCamera() async {
    if (_cameras.length < 2 || _controller == null) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    setState(() => _isReady = false);
    await _initCameraController(_cameras[_selectedCameraIndex]);
  }

  void _toggleFlash() async {
    if (_controller == null || kIsWeb) return;
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.off;
        break;
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      default:
        nextMode = FlashMode.auto;
    }
    try {
      await _controller!.setFlashMode(nextMode);
      setState(() {
        _flashMode = nextMode;
      });
    } catch (e) {
      debugPrint('Flash not supported: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flash is not supported on this camera.')),
        );
      }
    }
  }

  Future<XFile> _saveToCuqterFolder(XFile file) async {
    if (kIsWeb) return file;
    try {
      if (Platform.isAndroid) {
        final Directory folder = Directory('/storage/emulated/0/Android/media/com.example.cuqter/Cuqter/Cuqter Camera');
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final String newPath = '${folder.path}/$fileName';
        await File(file.path).copy(newPath);
        return XFile(newPath);
      }
    } catch (e) {
      debugPrint('Error saving to custom folder: $e');
    }
    return file;
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isTakingPicture) {
      return;
    }
    try {
      final XFile photo = await _controller!.takePicture();
      final XFile savedPhoto = await _saveToCuqterFolder(photo);
      
      if (mounted) {
        Navigator.pop(context, {'file': savedPhoto, 'type': 'photo'});
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isRecordingVideo) {
      return;
    }
    try {
      await _controller!.startVideoRecording();
      _isRecordingNotifier.value = true;
      _recordDurationNotifier.value = 0;
      
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordDurationNotifier.value++;
      });
    } catch (e) {
      debugPrint('Error starting video: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      return;
    }
    try {
      final XFile video = await _controller!.stopVideoRecording();
      _recordTimer?.cancel();
      
      final XFile savedVideo = await _saveToCuqterFolder(video);

      _isRecordingNotifier.value = false;
      _recordDurationNotifier.value = 0;
      
      if (mounted) {
        Navigator.pop(context, {'file': savedVideo, 'type': 'video'});
      }
    } catch (e) {
      debugPrint('Error stopping video: $e');
    }
  }

  Future<void> _openGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? media = _mode == 'PHOTO'
        ? await picker.pickImage(source: ImageSource.gallery)
        : await picker.pickVideo(source: ImageSource.gallery);
        
    if (media != null && mounted) {
      Navigator.pop(context, {'file': media, 'type': _mode == 'PHOTO' ? 'photo' : 'video'});
    }
  }

  Widget _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.auto:
        return huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedFlash, color: Colors.white, size: 22);
      case FlashMode.always:
        return huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedFlashlight, color: Colors.white, size: 22);
      case FlashMode.off:
        return huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedFlashOff, color: Colors.white, size: 22);
      default:
        return huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedFlash, color: Colors.white, size: 22);
    }
  }

  String _formatDuration(int seconds) {
    final int min = seconds ~/ 60;
    final int sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                )
              ],
            ),
          ),
        ),
      );
    }

    final bool isCameraReady = _isReady && _controller != null && _controller!.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: isCameraReady 
          ? _buildCameraContent(context)
          : _buildLoadingScreen(),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      key: const ValueKey('loadingScreen'),
      color: Colors.black,
    );
  }

  Widget _buildCameraContent(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scale = size.aspectRatio * _controller!.value.aspectRatio;
    
    return Stack(
      key: const ValueKey('cameraScreen'),
      fit: StackFit.expand,
      children: [
        // Camera Preview
          Positioned.fill(
            child: Transform.scale(
              scale: scale < 1 ? 1 / scale : scale,
              child: Center(
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          
          // Custom UI Overlays
          _buildGridOverlay(),
          _buildTopBar(),
        _buildBottomControls(),
      ],
    );
  }

  Widget _buildGridOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: GridPainter(),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, bottom: 12, left: 16, right: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: _isRecordingNotifier,
                  builder: (context, isRec, _) {
                    if (isRec) {
                      return ValueListenableBuilder<int>(
                        valueListenable: _recordDurationNotifier,
                        builder: (context, duration, _) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(duration),
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          );
                        }
                      );
                    }
                    return const SizedBox(height: 24);
                  },
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: _getFlashIcon(),
                    onPressed: _toggleFlash,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: StatefulBuilder(
        builder: (context, setLocalState) {
          return ValueListenableBuilder<bool>(
            valueListenable: _isRecordingNotifier,
            builder: (context, isRec, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode Toggle (PHOTO / VIDEO) with animated slider
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: SizedBox(
                  width: 160,
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        alignment: _mode == 'PHOTO' ? Alignment.centerLeft : Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: 0.5,
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildModeText('PHOTO', setLocalState),
                          _buildModeText('VIDEO', setLocalState),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Control Bar
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 40, top: 20, left: 30, right: 30),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Gallery Button
                        GestureDetector(
                          onTap: _openGallery,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white, width: 1.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedImage01, color: Colors.white, size: 24),
                              ),
                              const SizedBox(height: 6),
                              const Text('Gallery', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        
                        // Shutter Button
                        GestureDetector(
                          onTap: () {
                            if (_mode == 'PHOTO') {
                              _capturePhoto();
                            } else {
                              if (_isRecording) {
                                _stopVideoRecording();
                                setLocalState(() {}); // update UI
                              } else {
                                _startVideoRecording();
                                setLocalState(() {}); // update UI
                              }
                            }
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                                ),
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: isRec ? 30 : 54,
                                    height: isRec ? 30 : 54,
                                    decoration: BoxDecoration(
                                      color: _mode == 'VIDEO' ? Colors.red : Colors.white,
                                      borderRadius: BorderRadius.circular(isRec ? 8 : 27),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Shutter', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
                            ],
                          ),
                        ),
                        
                        // Switch Camera Button
                        GestureDetector(
                          onTap: _switchCamera,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                child: huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedCameraRotated01, color: Colors.white, size: 28),
                              ),
                              const SizedBox(height: 6),
                              const Text('Flip', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
         }
        );
       },
      ),
    );
  }

  Widget _buildModeText(String title, StateSetter setLocalState) {
    bool isSelected = _mode == title;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_isRecording) return; // Don't allow switch while recording
        setLocalState(() {
          _mode = title;
        });
      },
      child: Container(
        width: 80,
        height: 36,
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            letterSpacing: 1.2,
          ),
          child: Text(title),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1.0;

    // Draw vertical lines
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);

    // Draw horizontal lines
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


