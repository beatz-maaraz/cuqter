import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cuqter/services/status_service.dart';
import 'package:cuqter/services/cloudinary_service.dart';
import 'package:cuqter/utils/picker.dart';

class CreateStatusScreen extends StatefulWidget {
  const CreateStatusScreen({super.key});

  @override
  State<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends State<CreateStatusScreen> {
  final TextEditingController _captionController = TextEditingController();
  Uint8List? _file;
  bool _isLoading = false;

  void _selectImage() async {
    Uint8List? img = await pickImage(ImageSource.gallery);
    if (img != null) {
      setState(() {
        _file = img;
      });
    }
  }

  void _postStatus() async {
    if (_captionController.text.isEmpty && _file == null) {
      showSnackBar('Please enter text or select an image', context);
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

      if (_file != null) {
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
                    decoration: const InputDecoration(
                      hintText: 'Type a status...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                  ),
                  const SizedBox(height: 20),
                  if (_file != null)
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
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectImage,
        child: const Icon(Icons.image),
      ),
    );
  }
}
