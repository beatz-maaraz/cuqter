import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuqter/services/cloudinary_service.dart';
import 'package:cuqter/Screen/media/camera_screen.dart';
import 'package:cuqter/media.dart';
import 'package:cuqter/widgets/full_screen_profile_pic_page.dart';
import 'package:cuqter/utils/custom_snackbar.dart';

class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialUsername;
  final String initialBio;
  final String initialProfilePic;
  final String? initialCloudinaryPublicId;

  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.initialUsername,
    required this.initialBio,
    required this.initialProfilePic,
    this.initialCloudinaryPublicId,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameErrorText;
  Timer? _debounceTimer;

  late String _selectedProfilePic;
  String? _currentCloudinaryPublicId;
  late String _currentUsername;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _bioController = TextEditingController(text: widget.initialBio);

    _selectedProfilePic = widget.initialProfilePic;
    _currentCloudinaryPublicId = widget.initialCloudinaryPublicId;
    _currentUsername = widget.initialUsername;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String val) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }

    if (val.contains(' ')) {
      setState(() {
        _isUsernameAvailable = null;
        _usernameErrorText = 'Spaces are not allowed';
      });
      return;
    }

    final trimmed = val.trim().toLowerCase();
    if (trimmed.isEmpty) {
      setState(() {
        _isUsernameAvailable = null;
        _usernameErrorText = 'Username cannot be empty';
      });
      return;
    }

    final regExp = RegExp(r'^[a-zA-Z0-9._]+$');
    if (!regExp.hasMatch(trimmed)) {
      setState(() {
        _isUsernameAvailable = null;
        _usernameErrorText = 'Only letters, numbers, underscores, and dots';
      });
      return;
    }

    if (trimmed == _currentUsername.toLowerCase()) {
      setState(() {
        _isUsernameAvailable = true;
        _usernameErrorText = null;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _isUsernameAvailable = null;
      _usernameErrorText = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final query = await _firestore
            .collection('users')
            .where('username', isEqualTo: trimmed)
            .get();

        if (!mounted) return;

        if (_usernameController.text.trim().toLowerCase() != trimmed) {
          return;
        }

        setState(() {
          _isCheckingUsername = false;
          if (query.docs.isNotEmpty) {
            _isUsernameAvailable = false;
            _usernameErrorText = 'Username is already taken';
          } else {
            _isUsernameAvailable = true;
            _usernameErrorText = null;
          }
        });
      } catch (e) {
        if (!mounted) return;
        if (_usernameController.text.trim().toLowerCase() != trimmed) {
          return;
        }
        setState(() {
          _isCheckingUsername = false;
          _usernameErrorText = 'Error checking username';
        });
      }
    });
  }

  Future<void> _saveProfile() async {
    final String newUsername = _usernameController.text.trim().toLowerCase();
    final String newName = _nameController.text.trim();
    final String newBio = _bioController.text.trim();

    final bool isNameChanged = newName != widget.initialName;
    final bool isUsernameChanged =
        newUsername != widget.initialUsername.toLowerCase();
    final bool isBioChanged = newBio != widget.initialBio;
    final bool isPhotoChanged =
        _selectedProfilePic != widget.initialProfilePic;

    if (!isNameChanged &&
        !isUsernameChanged &&
        !isBioChanged &&
        !isPhotoChanged) {
      _showSnackBar('No changes to save.');
      Navigator.pop(context, false);
      return;
    }

    if (isNameChanged && newName.isEmpty) {
      _showSnackBar('Name cannot be empty', isError: true);
      return;
    }

    if (isUsernameChanged &&
        (newUsername.isEmpty ||
            _usernameErrorText != null ||
            _isUsernameAvailable == false)) {
      _showSnackBar(
        _usernameErrorText ?? 'Please enter a valid username',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Re-verify username uniqueness if changed
      if (isUsernameChanged) {
        final QuerySnapshot result = await _firestore
            .collection('users')
            .where('username', isEqualTo: newUsername)
            .get();
        if (result.docs.isNotEmpty) {
          throw 'Username is already taken';
        }
      }

      // Build update payload for Firestore user document (only changed fields)
      Map<String, dynamic> userUpdates = {};
      if (isNameChanged) userUpdates['name'] = newName;
      if (isUsernameChanged) userUpdates['username'] = newUsername;
      if (isBioChanged) userUpdates['bio'] = newBio;
      if (isPhotoChanged) {
        userUpdates['profilepic'] = _selectedProfilePic;
        userUpdates['cloudinary_public_id'] = _currentCloudinaryPublicId;
      }

      if (userUpdates.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update(userUpdates);
      }

      // Sync active statuses if photo or username changed
      Map<String, dynamic> statusUpdates = {};
      if (isPhotoChanged) statusUpdates['profilePic'] = _selectedProfilePic;
      if (isUsernameChanged) statusUpdates['username'] = newUsername;

      if (statusUpdates.isNotEmpty) {
        final batch = _firestore.batch();
        final statusesSnapshot = await _firestore
            .collection('statuses')
            .where('uid', isEqualTo: user.uid)
            .get();
        for (var doc in statusesSnapshot.docs) {
          batch.update(doc.reference, statusUpdates);
        }
        await batch.commit();
      }

      // Update SharedPreferences local cache for changed items
      final prefs = await SharedPreferences.getInstance();
      if (isNameChanged) await prefs.setString('cached_profile_name', newName);
      if (isUsernameChanged) {
        await prefs.setString('cached_profile_username', newUsername);
      }
      if (isBioChanged) await prefs.setString('cached_profile_bio', newBio);
      if (isPhotoChanged) {
        await prefs.setString('cached_profile_pic', _selectedProfilePic);
        if (_currentCloudinaryPublicId != null) {
          await prefs.setString(
            'cached_cloudinary_public_id',
            _currentCloudinaryPublicId!,
          );
        } else {
          await prefs.remove('cached_cloudinary_public_id');
        }

        // Delete old Cloudinary asset if replaced or removed
        if (widget.initialCloudinaryPublicId != null &&
            widget.initialCloudinaryPublicId!.isNotEmpty &&
            widget.initialCloudinaryPublicId != _currentCloudinaryPublicId) {
          await CloudinaryService.deleteMedia(
            widget.initialCloudinaryPublicId!,
          );
        }
      }

      if (mounted) {
        _showSnackBar('Profile updated successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to update profile: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    showCustomSnackBar(context, message, isError: isError);
  }

  void _removeProfilePicture() {
    setState(() {
      _selectedProfilePic = '';
      _currentCloudinaryPublicId = null;
    });
    _showSnackBar('Photo removed from preview. Tap Save to apply.');
  }

  Future<void> _pickAndUploadCustomImage(
    ImageSource source, {
    bool isNativePicker = false,
  }) async {
    try {
      Uint8List? imageBytes;
      if (source == ImageSource.camera) {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(builder: (context) => const CustomCameraScreen()),
        );
        if (result != null && result['file'] != null) {
          final XFile file = result['file'] as XFile;
          imageBytes = await file.readAsBytes();
        }
      } else if (isNativePicker) {
        final XFile? file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        if (file != null) {
          imageBytes = await file.readAsBytes();
        }
      } else {
        final result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const AssetManagerScreen(
            isPicker: true,
            onlyImages: true,
            initialTab: 'Images',
          ),
        );
        if (result != null && result is AppAsset) {
          imageBytes = await File(result.imageUrl).readAsBytes();
        }
      }

      if (imageBytes == null) return;

      setState(() {
        _isLoading = true;
      });

      final uploadResult = await CloudinaryService.uploadImage(imageBytes);
      if (uploadResult != null) {
        final String newUrl = uploadResult['url']!;
        final String newPublicId = uploadResult['public_id']!;

        setState(() {
          _selectedProfilePic = newUrl;
          _currentCloudinaryPublicId = newPublicId;
        });

        if (mounted) {
          _showSnackBar('Photo uploaded! Tap Save to apply.');
        }
      } else {
        if (mounted) {
          _showSnackBar('Failed to upload image to Cloudinary.', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error selecting photo: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showProfilePicPicker() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Change Profile Photo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (_selectedProfilePic.isNotEmpty)
                    IconButton(
                      tooltip: 'Remove photo',
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _removeProfilePicture();
                      },
                      icon: const huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedDelete02,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildChooseOptionItem(
                    icon: huge.HugeIcons.strokeRoundedCamera01,
                    label: 'Camera',
                    color: colorScheme.primary,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndUploadCustomImage(ImageSource.camera);
                    },
                  ),
                  _buildChooseOptionItem(
                    icon: huge.HugeIcons.strokeRoundedImage01,
                    label: 'Gallery',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndUploadCustomImage(ImageSource.gallery);
                    },
                  ),
                  _buildChooseOptionItem(
                    icon: huge.HugeIcons.strokeRoundedFolder01,
                    label: 'Files / Other',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndUploadCustomImage(
                        ImageSource.gallery,
                        isNativePicker: true,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChooseOptionItem({
    required dynamic icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: huge.HugeIcon(icon: icon, color: color, size: 26),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool isSaveDisabled =
        _isLoading ||
        _isCheckingUsername ||
        _usernameErrorText != null ||
        _nameController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty ||
        (_isUsernameAvailable == false &&
            _usernameController.text.trim().toLowerCase() != _currentUsername.toLowerCase());

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: huge.HugeIcon(
              icon: huge.HugeIcons.strokeRoundedArrowLeft01,
              color: colorScheme.onSurface,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton.icon(
                  onPressed: isSaveDisabled ? null : _saveProfile,
                  icon: _isLoading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 16),
                  label: const Text(
                    'Save',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Profile Avatar Hero Banner Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.12),
                          colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Floating Avatar Stack
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Halo Glow Ring
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.tertiaryContainer,
                                      colorScheme.secondary,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_selectedProfilePic.isNotEmpty) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FullScreenProfilePicPage(
                                              imageUrl: _selectedProfilePic,
                                              heroTag: 'edit_profile_avatar_hero',
                                            ),
                                          ),
                                        );
                                      } else {
                                        _showProfilePicPicker();
                                      }
                                    },
                                    child: Hero(
                                      tag: 'edit_profile_avatar_hero',
                                      child: CircleAvatar(
                                        radius: 54,
                                        backgroundColor: colorScheme.surfaceContainerHighest,
                                        backgroundImage: _selectedProfilePic.isNotEmpty
                                            ? (_selectedProfilePic.startsWith('http')
                                                ? CachedNetworkImageProvider(_selectedProfilePic)
                                                : AssetImage(_selectedProfilePic) as ImageProvider)
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Camera Badged Trigger
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: _showProfilePicPicker,
                                  child: Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colorScheme.surface,
                                        width: 3.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.18),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Action Pill Chip Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _showProfilePicPicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.photo_camera_rounded, color: Colors.white, size: 15),
                                    SizedBox(width: 6),
                                    Text(
                                      'Change Photo',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_selectedProfilePic.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: _removeProfilePicture,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.redAccent.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'Remove',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Section Label & Inputs Container
                  _buildSectionHeader('FULL NAME', huge.HugeIcons.strokeRoundedUser),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.onSurface.withValues(alpha: 0.08),
                      ),
                    ),
                    child: TextField(
                      controller: _nameController,
                      onChanged: (val) => setState(() {}),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        border: InputBorder.none,
                        prefixIcon: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedUser,
                          color: colorScheme.primary.withValues(alpha: 0.7),
                          size: 18,
                        ),
                        suffixIcon: _nameController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _nameController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Username Card Input
                  _buildSectionHeader('USERNAME', huge.HugeIcons.strokeRoundedAt),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _usernameErrorText != null
                            ? Colors.redAccent.withValues(alpha: 0.6)
                            : (_isUsernameAvailable == true
                                ? Colors.teal.withValues(alpha: 0.6)
                                : colorScheme.onSurface.withValues(alpha: 0.08)),
                        width: (_usernameErrorText != null || _isUsernameAvailable == true) ? 1.5 : 1.0,
                      ),
                    ),
                    child: TextField(
                      controller: _usernameController,
                      onChanged: _onUsernameChanged,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        prefixIcon: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedAt,
                          color: colorScheme.primary.withValues(alpha: 0.7),
                          size: 18,
                        ),
                        hintText: 'username',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        border: InputBorder.none,
                        suffixIcon: _isCheckingUsername
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(14.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : (_isUsernameAvailable == true
                                ? const Icon(Icons.check_circle_rounded, color: Colors.teal, size: 20)
                                : (_isUsernameAvailable == false || _usernameErrorText != null
                                    ? const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20)
                                    : null)),
                      ),
                    ),
                  ),
                  if (_usernameErrorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _usernameErrorText!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else if (_isUsernameAvailable == true &&
                      _usernameController.text.trim().toLowerCase() != _currentUsername.toLowerCase())
                    const Padding(
                      padding: EdgeInsets.only(top: 6, left: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '✓ Username is available',
                          style: TextStyle(
                            color: Colors.teal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Bio Card Input
                  _buildSectionHeader('BIO', huge.HugeIcons.strokeRoundedEdit02),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.onSurface.withValues(alpha: 0.08),
                      ),
                    ),
                    child: TextField(
                      controller: _bioController,
                      maxLines: 4,
                      maxLength: 150,
                      style: const TextStyle(fontSize: 14.5, height: 1.4),
                      decoration: const InputDecoration(
                        hintText: 'Tell the world about yourself...',
                        contentPadding: EdgeInsets.all(20),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Primary Save Profile Button CTA
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSaveDisabled
                          ? []
                          : [
                              BoxShadow(
                                color: colorScheme.primary.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: isSaveDisabled ? null : _saveProfile,
                      icon: const Icon(Icons.save_rounded, size: 20),
                      label: const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, dynamic icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        huge.HugeIcon(
          icon: icon,
          color: colorScheme.primary,
          size: 15,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: colorScheme.primary,
            letterSpacing: 0.9,
          ),
        ),
      ],
    );
  }
}
