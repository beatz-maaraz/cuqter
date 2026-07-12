import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cuqter/services/status_service.dart';
import 'package:cuqter/services/cloudinary_service.dart';
import 'package:cuqter/utils/picker.dart';
import 'package:cuqter/media.dart';

class CreateStatusScreen extends StatefulWidget {
  final String? sharedMediaPath;
  final bool? isSharedMediaVideo;

  const CreateStatusScreen({super.key, this.sharedMediaPath, this.isSharedMediaVideo});

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

  // Track selection from custom media picker
  String? _selectedLocalPath;
  String? _selectedNetworkUrl;

  @override
  void initState() {
    super.initState();
    if (widget.sharedMediaPath != null) {
      _loadSharedMedia(widget.sharedMediaPath!, widget.isSharedMediaVideo ?? false);
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
            _videoController = VideoPlayerController.networkUrl(Uri.parse(path));
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

      var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Status'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _postStatus,
            child: const Text('POST', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _captionController,
                    style: const TextStyle(fontSize: 24),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: 'Type a status...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                  ),
                  const SizedBox(height: 20),
                  if (_selectedNetworkUrl != null && !_isVideo)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(_selectedNetworkUrl!),
                            fit: BoxFit.cover,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  else if (_selectedLocalPath != null && !_isVideo)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: FileImage(File(_selectedLocalPath!)),
                            fit: BoxFit.cover,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  else if (_file != null && !_isVideo)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: MemoryImage(_file!),
                            fit: BoxFit.cover,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  else if (_isVideo && _videoController != null && _videoController!.value.isInitialized)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectMedia,
        child: huge.HugeIcon(
          icon: huge.HugeIcons.strokeRoundedImage01, 
          color: Theme.of(context).colorScheme.onSecondaryContainer, 
          size: 24,
        ),
      ),
    );
  }
}
