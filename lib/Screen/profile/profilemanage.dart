import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuqter/services/cloudinary_service.dart';
import 'package:cuqter/widgets/full_screen_profile_pic_page.dart';
import 'package:cuqter/Screen/media/camera_screen.dart';
import 'package:cuqter/media.dart';
import 'package:cuqter/Screen/settings/blocked_contacts_page.dart';

class ProfileManage extends StatefulWidget {
  const ProfileManage({super.key});

  @override
  State<ProfileManage> createState() => _ProfileManageState();
}

class _ProfileManageState extends State<ProfileManage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String _selectedProfilePic = '';
  String? _currentCloudinaryPublicId;
  String _currentUsername = '';

  // Privacy Settings State
  String _profilePhotoPrivacy = 'Everyone';
  String _lastSeenPrivacy = 'Everyone';
  String _aboutPrivacy = 'Everyone';
  String _statusPrivacy = 'My Contacts';

  @override
  void initState() {
    super.initState();
    _nameController.text = _auth.currentUser?.displayName ?? '';
    _loadCachedProfile();
    _loadUserData();
    _loadPrivacySettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedName = prefs.getString('cached_profile_name');
      final String? cachedUsername =
          prefs.getString('cached_profile_username');
      final String? cachedBio = prefs.getString('cached_profile_bio');
      final String? cachedPic = prefs.getString('cached_profile_pic');
      final String? cachedPublicId =
          prefs.getString('cached_cloudinary_public_id');

      if (mounted) {
        setState(() {
          if (cachedName != null && cachedName.isNotEmpty) {
            _nameController.text = cachedName;
          }
          if (cachedUsername != null && cachedUsername.isNotEmpty) {
            _usernameController.text = cachedUsername;
            _currentUsername = cachedUsername;
          }
          if (cachedBio != null) _bioController.text = cachedBio;
          if (cachedPic != null && cachedPic.isNotEmpty) {
            _selectedProfilePic = cachedPic;
          }
          if (cachedPublicId != null) {
            _currentCloudinaryPublicId = cachedPublicId;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading cached profile: $e');
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snap = await _firestore.collection('users').doc(user.uid).get();
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final String name = data['name'] ?? '';
        final String username = data['username'] ?? '';
        final String bio = data['bio'] ?? '';
        final String profilepic = data['profilepic'] ?? '';
        final String? cloudinaryPublicId = data['cloudinary_public_id'];

        if (mounted) {
          setState(() {
            _nameController.text = name;
            _usernameController.text = username;
            _currentUsername = username;
            _bioController.text = bio;
            _selectedProfilePic = profilepic;
            _currentCloudinaryPublicId = cloudinaryPublicId;
          });
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_profile_name', name);
        await prefs.setString('cached_profile_username', username);
        await prefs.setString('cached_profile_bio', bio);
        await prefs.setString('cached_profile_pic', profilepic);
        if (cloudinaryPublicId != null) {
          await prefs.setString(
              'cached_cloudinary_public_id', cloudinaryPublicId);
        } else {
          await prefs.remove('cached_cloudinary_public_id');
        }
      }
    } catch (e) {
      debugPrint('Error fetching user profile data: $e');
    }
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _profilePhotoPrivacy =
              prefs.getString('privacy_profile_pic') ?? 'Everyone';
          _lastSeenPrivacy =
              prefs.getString('privacy_last_seen') ?? 'Everyone';
          _aboutPrivacy = prefs.getString('privacy_about') ?? 'Everyone';
          _statusPrivacy = prefs.getString('privacy_status') ?? 'My Contacts';
        });
      }
    } catch (e) {
      debugPrint('Error loading privacy settings: $e');
    }
  }

  Future<void> _updatePrivacyPref(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({key: value}).catchError((_) {});
    }
  }



  Future<void> _updateProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final String newUsername = _usernameController.text.trim().toLowerCase();
      if (newUsername.isEmpty) {
        throw 'Username cannot be empty';
      }

      if (newUsername != _currentUsername.toLowerCase()) {
        final result = await _firestore
            .collection('users')
            .where('username', isEqualTo: newUsername)
            .get();
        if (result.docs.isNotEmpty) {
          throw 'Username is already taken';
        }
      }

      final snap = await _firestore.collection('users').doc(user.uid).get();
      String? oldPublicId;
      if (snap.exists && snap.data() != null) {
        oldPublicId = snap.data()!['cloudinary_public_id'];
      }

      await _firestore.collection('users').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'username': newUsername,
        'bio': _bioController.text.trim(),
        'profilepic': _selectedProfilePic,
        'cloudinary_public_id': _currentCloudinaryPublicId,
      });

      final batch = _firestore.batch();
      final statusesSnapshot = await _firestore
          .collection('statuses')
          .where('uid', isEqualTo: user.uid)
          .get();
      for (var doc in statusesSnapshot.docs) {
        batch.update(doc.reference, {
          'profilePic': _selectedProfilePic,
          'username': newUsername,
        });
      }
      await batch.commit();

      _currentUsername = newUsername;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'cached_profile_name', _nameController.text.trim());
      await prefs.setString('cached_profile_username', newUsername);
      await prefs.setString('cached_profile_bio', _bioController.text.trim());
      await prefs.setString('cached_profile_pic', _selectedProfilePic);
      if (_currentCloudinaryPublicId != null) {
        await prefs.setString(
            'cached_cloudinary_public_id', _currentCloudinaryPublicId!);
      } else {
        await prefs.remove('cached_cloudinary_public_id');
      }

      if (oldPublicId != null &&
          oldPublicId.isNotEmpty &&
          oldPublicId != _currentCloudinaryPublicId) {
        await CloudinaryService.deleteMedia(oldPublicId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeProfilePicture() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      setState(() => _isLoading = true);
      String? oldPublicId = _currentCloudinaryPublicId;

      setState(() {
        _selectedProfilePic = '';
        _currentCloudinaryPublicId = null;
      });

      await _firestore.collection('users').doc(user.uid).update({
        'profilepic': '',
        'cloudinary_public_id': null,
      });

      final batch = _firestore.batch();
      final statusesSnapshot = await _firestore
          .collection('statuses')
          .where('uid', isEqualTo: user.uid)
          .get();
      for (var doc in statusesSnapshot.docs) {
        batch.update(doc.reference, {'profilePic': ''});
      }
      await batch.commit();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_profile_pic', '');
      await prefs.remove('cached_cloudinary_public_id');

      if (oldPublicId != null && oldPublicId.isNotEmpty) {
        await CloudinaryService.deleteMedia(oldPublicId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing picture: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadCustomImage(ImageSource source,
      {bool isNativePicker = false}) async {
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

      setState(() => _isLoading = true);

      final uploadResult = await CloudinaryService.uploadImage(imageBytes);
      if (uploadResult != null) {
        final String newUrl = uploadResult['url']!;
        final String newPublicId = uploadResult['public_id']!;
        String? oldPublicId = _currentCloudinaryPublicId;

        setState(() {
          _selectedProfilePic = newUrl;
          _currentCloudinaryPublicId = newPublicId;
        });

        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({
          'profilepic': newUrl,
          'cloudinary_public_id': newPublicId,
        });

        final batch = _firestore.batch();
        final statusesSnapshot = await _firestore
            .collection('statuses')
            .where('uid', isEqualTo: _auth.currentUser!.uid)
            .get();
        for (var doc in statusesSnapshot.docs) {
          batch.update(doc.reference, {'profilePic': newUrl});
        }
        await batch.commit();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_profile_pic', newUrl);
        await prefs.setString('cached_cloudinary_public_id', newPublicId);

        if (oldPublicId != null && oldPublicId.isNotEmpty) {
          await CloudinaryService.deleteMedia(oldPublicId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Profile picture updated successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading picture: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Choose Option',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if (_selectedProfilePic.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _removeProfilePicture();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildChooseOptionItem(
                    icon: huge.HugeIcons.strokeRoundedCamera01,
                    label: 'Camera',
                    color: Colors.blue,
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
                      _pickAndUploadCustomImage(ImageSource.gallery,
                          isNativePicker: true);
                    },
                  ),
                  _buildChooseOptionItem(
                    icon: huge.HugeIcons.strokeRoundedFolder01,
                    label: 'App Files',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndUploadCustomImage(ImageSource.gallery,
                          isNativePicker: false);
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
    required List<List<dynamic>> icon,
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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border:
                  Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
            ),
            child: Center(
              child: huge.HugeIcon(icon: icon, color: color, size: 24),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showVisibilityPicker(String title, String prefKey, String currentValue,
      ValueChanged<String> onSelected) {
    final colorScheme = Theme.of(context).colorScheme;
    final options = ['Everyone', 'My Contacts', 'Nobody'];

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              ...options.map((opt) {
                final isSelected = opt == currentValue;
                return ListTile(
                  title: Text(opt,
                      style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: colorScheme.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(opt);
                    _updatePrivacyPref(prefKey, opt);
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: huge.HugeIcon(
            icon: huge.HugeIcons.strokeRoundedArrowLeft01,
            color: colorScheme.onSurface,
            size: 22,
            strokeWidth: 1.8,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile Manage',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar Section
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_selectedProfilePic.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullScreenProfilePicPage(
                                  imageUrl: _selectedProfilePic,
                                  heroTag: 'manage_profile_pic_hero',
                                ),
                              ),
                            );
                          }
                        },
                        child: Hero(
                          tag: 'manage_profile_pic_hero',
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: colorScheme.primaryContainer,
                            backgroundImage: _selectedProfilePic.isNotEmpty
                                ? (_selectedProfilePic.startsWith('http')
                                    ? ResizeImage(
                                        CachedNetworkImageProvider(
                                            _selectedProfilePic),
                                        width: 220,
                                        height: 220)
                                    : AssetImage(_selectedProfilePic)
                                        as ImageProvider)
                                : null,
                            child: _selectedProfilePic.isEmpty
                                ? Text(
                                    _nameController.text.isNotEmpty
                                        ? _nameController.text[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onPrimaryContainer),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showProfilePicPicker,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: colorScheme.surface, width: 3),
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 1: PUBLIC IDENTITY
                _buildSectionHeader('PUBLIC IDENTITY'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Display Name',
                            prefixIcon: huge.HugeIcon(
                                icon: huge.HugeIcons.strokeRoundedUser,
                                color: colorScheme.primary,
                                size: 20,
                                strokeWidth: 1.8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            prefixIcon: huge.HugeIcon(
                                icon: huge.HugeIcons.strokeRoundedAt,
                                color: colorScheme.primary,
                                size: 20,
                                strokeWidth: 1.8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _bioController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            alignLabelWithHint: true,
                            labelText: 'About / Bio',
                            prefixIcon: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 14, left: 12, right: 8),
                                  child: huge.HugeIcon(
                                    icon: huge.HugeIcons.strokeRoundedInformationCircle,
                                    color: colorScheme.primary,
                                    size: 20,
                                    strokeWidth: 1.8,
                                  ),
                                ),
                              ],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                            ),
                            onPressed: _updateProfile,
                            child: const Text('Save Profile Changes',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                // Section 2: PRIVACY & VISIBILITY
                _buildSectionHeader('PRIVACY & VISIBILITY'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildOptionTile(
                    title: 'Profile Photo',
                    subtitle: _profilePhotoPrivacy,
                    icon: huge.HugeIcons.strokeRoundedUser,
                    onTap: () {
                      _showVisibilityPicker('Profile Photo Visibility',
                          'privacy_profile_pic', _profilePhotoPrivacy, (val) {
                        setState(() => _profilePhotoPrivacy = val);
                      });
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildOptionTile(
                    title: 'Last Seen & Online',
                    subtitle: _lastSeenPrivacy,
                    icon: huge.HugeIcons.strokeRoundedClock01,
                    onTap: () {
                      _showVisibilityPicker('Last Seen & Online',
                          'privacy_last_seen', _lastSeenPrivacy, (val) {
                        setState(() => _lastSeenPrivacy = val);
                      });
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildOptionTile(
                    title: 'About / Bio',
                    subtitle: _aboutPrivacy,
                    icon: huge.HugeIcons.strokeRoundedInformationCircle,
                    onTap: () {
                      _showVisibilityPicker(
                          'About Visibility', 'privacy_about', _aboutPrivacy,
                          (val) {
                        setState(() => _aboutPrivacy = val);
                      });
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildOptionTile(
                    title: 'Status Updates',
                    subtitle: _statusPrivacy,
                    icon: huge.HugeIcons.strokeRoundedView,
                    onTap: () {
                      _showVisibilityPicker('Status Updates Visibility',
                          'privacy_status', _statusPrivacy, (val) {
                        setState(() => _statusPrivacy = val);
                      });
                    },
                  ),
                ]),

                const SizedBox(height: 24),

                // Section 3: BLOCKED FRIENDS
                _buildSectionHeader('BLOCKED FRIENDS'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(currentUserId)
                        .collection('blocked_users')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final blockedCount = snapshot.data?.docs.length ?? 0;
                      return _buildOptionTile(
                        title: 'Blocked Friends & Contacts',
                        subtitle:
                            '$blockedCount contact${blockedCount == 1 ? '' : 's'} blocked',
                        icon: huge.HugeIcons.strokeRoundedUserBlock01,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BlockedContactsPage(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required List<List<dynamic>> icon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: huge.HugeIcon(
          icon: icon,
          size: 18,
          strokeWidth: 1.8,
          color: colorScheme.primary,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
            fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
      ),
      trailing: huge.HugeIcon(
        icon: huge.HugeIcons.strokeRoundedArrowRight01,
        size: 16,
        strokeWidth: 1.8,
        color: colorScheme.onSurface.withValues(alpha: 0.3),
      ),
    );
  }
}