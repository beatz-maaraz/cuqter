import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cuqter/services/status_service.dart';
import 'package:cuqter/services/cloudinary_service.dart';
import 'package:cuqter/utils/picker.dart';
import 'package:cuqter/media.dart';
import 'package:cuqter/media.dart';
import 'package:cuqter/Screen/media/camera_screen.dart';
import 'package:hugeicons/hugeicons.dart' as huge;

class CreateStatusScreen extends StatefulWidget {
  final String? sharedMediaPath;
  final bool? isSharedMediaVideo;

  const CreateStatusScreen({
    super.key,
    this.sharedMediaPath,
    this.isSharedMediaVideo,
  });

  @override
  State<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends State<CreateStatusScreen> {
  final TextEditingController _captionController = TextEditingController();
  Uint8List? _file;
  XFile? _videoFile;
  bool _isVideo = false;
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  bool _showColorPicker = false;

  // Track selection from custom media picker
  String? _selectedLocalPath;
  String? _selectedNetworkUrl;

  int _currentGradientIndex = 0;
  final List<List<Color>> _statusGradients = [
    [const Color(0xFF8A2387), const Color(0xFFE94057), const Color(0xFFF27121)],
    [const Color(0xFF00C6FF), const Color(0xFF0072FF)],
    [const Color(0xFF1D976C), const Color(0xFF93F9B9)],
    [const Color(0xFFEB5757), const Color(0xFF000000)],
    [const Color(0xFFC33764), const Color(0xFF1D2671)],
    [const Color(0xFF11998E), const Color(0xFF38EF7D)],
  ];

  @override
  void initState() {
    super.initState();
    if (widget.sharedMediaPath != null) {
      _loadSharedMedia(
        widget.sharedMediaPath!,
        widget.isSharedMediaVideo ?? false,
      );
    }
  }

  void _loadSharedMedia(String path, bool isVideoFile) async {
    if (isVideoFile) {
      if (kIsWeb) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(path));
      } else {
        _videoController = VideoPlayerController.file(File(path));
      }
      _videoController!
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _videoController!.play();
          _videoController!.setLooping(true);
        });
      if (mounted) {
        setState(() {
          _videoFile = XFile(path);
          _file = null;
          _isVideo = true;
          _selectedLocalPath = null;
          _selectedNetworkUrl = null;
        });
      }
    } else {
      Uint8List imgBytes = await File(path).readAsBytes();
      if (mounted) {
        setState(() {
          _file = imgBytes;
          _videoFile = null;
          _isVideo = false;
          _selectedLocalPath = null;
          _selectedNetworkUrl = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _selectMedia() async {
    final AppAsset? result = await showModalBottomSheet<AppAsset>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: const AssetManagerScreen(isPicker: true, title: 'Add status'),
      ),
    );

    if (result != null) {
      if (_videoController != null) {
        _videoController!.dispose();
        _videoController = null;
      }

      final isVideoFile = result.type == 'video';
      final path = result.imageUrl;

      setState(() {
        _isVideo = isVideoFile;
        _file = null;
        _videoFile = null;
        if (path.startsWith('http')) {
          _selectedNetworkUrl = path;
          _selectedLocalPath = null;
        } else {
          _selectedLocalPath = path;
          _selectedNetworkUrl = null;
        }
      });

      if (isVideoFile) {
        if (path.startsWith('http')) {
          _videoController = VideoPlayerController.networkUrl(Uri.parse(path));
        } else {
          if (kIsWeb) {
            _videoController = VideoPlayerController.networkUrl(
              Uri.parse(path),
            );
          } else {
            _videoController = VideoPlayerController.file(File(path));
          }
        }
        _videoController!
          ..initialize().then((_) {
            if (mounted) setState(() {});
            _videoController!.play();
            _videoController!.setLooping(true);
          });
      }
    }
  }

  void _postStatus() async {
    if (_captionController.text.isEmpty &&
        _file == null &&
        _videoFile == null &&
        _selectedLocalPath == null &&
        _selectedNetworkUrl == null) {
      showSnackBar('Please enter text, select an image, or a video', context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      String username = userDoc.data()?['name'] ?? 'Unknown';
      String profilePic = userDoc.data()?['profilepic'] ?? '';

      String mediaUrl = '';
      String mediaType = 'text';

      if (_selectedNetworkUrl != null) {
        mediaUrl = _selectedNetworkUrl!;
        mediaType = _isVideo ? 'video' : 'image';
      } else if (_selectedLocalPath != null) {
        final ext = _selectedLocalPath!.split('.').last;
        if (_isVideo) {
          final res = await CloudinaryService.uploadFile(
            filePath: _selectedLocalPath!,
            folderPath: 'cuqter_media/status',
            fileName: 'status_${DateTime.now().millisecondsSinceEpoch}.$ext',
            resourceType: 'video',
          );
          if (res != null) {
            mediaUrl = res['url']!;
            mediaType = 'video';
          } else {
            showSnackBar('Failed to upload video', context);
            setState(() => _isLoading = false);
            return;
          }
        } else {
          final file = File(_selectedLocalPath!);
          final bytes = await file.readAsBytes();
          final res = await CloudinaryService.uploadFile(
            fileBytes: bytes,
            folderPath: 'cuqter_media/status',
            fileName: 'status_${DateTime.now().millisecondsSinceEpoch}.jpg',
            resourceType: 'image',
          );
          if (res != null) {
            mediaUrl = res['url']!;
            mediaType = 'image';
          } else {
            showSnackBar('Failed to upload image', context);
            setState(() => _isLoading = false);
            return;
          }
        }
      } else if (_isVideo && _videoFile != null) {
        String ext = _videoFile!.name.split('.').last;
        if (ext.isEmpty || ext.length > 5) {
          ext = _videoFile!.path.split('.').last;
          if (ext.isEmpty || ext.length > 5) ext = 'mp4';
        }

        Map<String, String>? res;
        if (kIsWeb) {
          Uint8List videoBytes = await _videoFile!.readAsBytes();
          res = await CloudinaryService.uploadFile(
            fileBytes: videoBytes,
            folderPath: 'cuqter_media/status',
            fileName: 'status_${DateTime.now().millisecondsSinceEpoch}.$ext',
            resourceType: 'video',
          );
        } else {
          res = await CloudinaryService.uploadFile(
            filePath: _videoFile!.path,
            folderPath: 'cuqter_media/status',
            fileName: 'status_${DateTime.now().millisecondsSinceEpoch}.$ext',
            resourceType: 'video',
          );
        }

        if (res != null) {
          mediaUrl = res['url']!;
          mediaType = 'video';
        } else {
          showSnackBar('Failed to upload video', context);
          setState(() => _isLoading = false);
          return;
        }
      } else if (_file != null) {
        final res = await CloudinaryService.uploadFile(
          fileBytes: _file!,
          folderPath: 'cuqter_media/status',
          fileName: 'status_${DateTime.now().millisecondsSinceEpoch}.jpg',
          resourceType: 'image',
        );
        if (res != null) {
          mediaUrl = res['url']!;
          mediaType = 'image';
        } else {
          showSnackBar('Failed to upload image', context);
          setState(() => _isLoading = false);
          return;
        }
      }

      await StatusService().addStatus(
        uid: user.uid,
        username: username,
        profilePic: profilePic,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        caption: _captionController.text,
        colorIndex: (mediaType == 'text') ? _currentGradientIndex : 0,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      showSnackBar(e.toString(), context);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we are showing text-only status
    final bool isTextOnly = _selectedNetworkUrl == null &&
        _selectedLocalPath == null &&
        _file == null &&
        !_isVideo;

    return Scaffold(
      backgroundColor: Colors.black, // Dark background for immersive media
      body: Stack(
        children: [
          // 1. Background / Media Content
          if (isTextOnly)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _statusGradients[_currentGradientIndex],
                ),
              ),
            )
          else if (_selectedNetworkUrl != null && !_isVideo)
            Positioned.fill(
              child: Image.network(
                _selectedNetworkUrl!,
                fit: BoxFit.cover,
              ),
            )
          else if (_selectedLocalPath != null && !_isVideo)
            Positioned.fill(
              child: Image.file(
                File(_selectedLocalPath!),
                fit: BoxFit.cover,
              ),
            )
          else if (_file != null && !_isVideo)
            Positioned.fill(
              child: Image.memory(
                _file!,
                fit: BoxFit.cover,
              ),
            )
          else if (_isVideo &&
              _videoController != null &&
              _videoController!.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            ),

          // 2. Loading Indicator Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),

          // 3. Text Input (Always shown if it's text-only, or overlays media if they type something?)
          // Usually social apps have the text overlay the media. We'll show the text field in the center.
          if (!_isLoading)
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: TextField(
                    controller: _captionController,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 4,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: isTextOnly ? 'Type a status...' : 'Add a caption...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: isTextOnly ? 32 : 24,
                      ),
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ),
            ),

          // 4. Top Bar (Close button and Color Palette)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedCancel01, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  if (isTextOnly)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedPaintBoard, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _showColorPicker = !_showColorPicker;
                              });
                            },
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.fastOutSlowIn,
                          switchOutCurve: Curves.fastOutSlowIn,
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              alignment: Alignment.topCenter,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: _showColorPicker
                              ? Container(
                                  key: const ValueKey('color_picker'),
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(_statusGradients.length, (index) {
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _currentGradientIndex = index;
                                            _showColorPicker = false;
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(vertical: 6),
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: _statusGradients[index],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            border: _currentGradientIndex == index
                                                ? Border.all(color: Colors.white, width: 2)
                                                : null,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 4,
                                              )
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                )
                              : const SizedBox.shrink(key: ValueKey('empty')),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // 5. Bottom Glassmorphic Toolbar
          if (!_isLoading)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildIconButton(
                                icon: huge.HugeIcons.strokeRoundedText,
                                label: 'Text',
                                isActive: isTextOnly,
                                onTap: () {
                                  setState(() {
                                    _file = null;
                                    _videoFile = null;
                                    _selectedLocalPath = null;
                                    _selectedNetworkUrl = null;
                                    _isVideo = false;
                                  });
                                },
                              ),

                              const SizedBox(width: 8),
                              _buildIconButton(
                                icon: huge.HugeIcons.strokeRoundedImage01,
                            label: 'Gallery',
                            isActive: _selectedLocalPath != null || _selectedNetworkUrl != null || _file != null,
                            onTap: _selectMedia,
                          ),
                          const SizedBox(width: 8),
                          _buildIconButton(
                            icon: huge.HugeIcons.strokeRoundedCamera01,
                            label: 'Camera',
                            isActive: false, // Camera is just a trigger
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CustomCameraScreen(),
                                ),
                              );
                              if (result != null) {
                                final XFile file = result['file'];
                                final bool isVideo = result['type'] == 'video';

                                if (_videoController != null) {
                                  _videoController!.dispose();
                                  _videoController = null;
                                }

                                setState(() {
                                  _isVideo = isVideo;
                                  _file = null;
                                  if (isVideo) {
                                    _videoFile = file;
                                    _selectedLocalPath = null;
                                    _selectedNetworkUrl = null;
                                  } else {
                                    _videoFile = null;
                                    _selectedLocalPath = file.path;
                                    _selectedNetworkUrl = null;
                                  }
                                });

                                if (isVideo) {
                                  _videoController = kIsWeb
                                      ? VideoPlayerController.networkUrl(Uri.parse(file.path))
                                      : VideoPlayerController.file(File(file.path));
                                  _videoController!
                                    ..initialize().then((_) {
                                      if (mounted) setState(() {});
                                      _videoController!.play();
                                      _videoController!.setLooping(true);
                                    });
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 16),
                          // Send Button
                          GestureDetector(
                            onTap: _postStatus,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: huge.HugeIcon(
                                icon: huge.HugeIcons.strokeRoundedSent,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required dynamic icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            huge.HugeIcon(icon: icon, color: Colors.white, size: 20),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
