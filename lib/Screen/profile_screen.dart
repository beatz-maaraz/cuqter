import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuqter/utils/picker.dart';
import 'package:cuqter/services/cloudinary_service.dart';
import 'package:cuqter/widgets/full_screen_profile_pic_page.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = false;
  String _selectedProfilePic = '';
  String? _currentCloudinaryPublicId;
  String _currentUsername = '';

  final List<String> _profilePictures = [
    'assets/profile/BOY (1).jpg',
    'assets/profile/BOY (2).jpg',
    'assets/profile/BOY (3).jpg',
    'assets/profile/BOY (4).jpg',
    'assets/profile/Girl (1).jpg',
    'assets/profile/Girl (2).jpg',
    'assets/profile/NEW (1).jpg',
    'assets/profile/NEW (2).jpg',
    'assets/profile/NEW (3).jpg',
    'assets/profile/NEW (4).jpg',
    'assets/profile/NEW (5).jpg',
    'assets/profile/NEW (6).jpg',
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = _auth.currentUser?.displayName ?? '';
    _loadCachedProfile();
    _loadUserData();
  }

  Future<void> _loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedName = prefs.getString('cached_profile_name');
      final String? cachedUsername = prefs.getString('cached_profile_username');
      final String? cachedBio = prefs.getString('cached_profile_bio');
      final String? cachedPic = prefs.getString('cached_profile_pic');
      final String? cachedPublicId = prefs.getString('cached_cloudinary_public_id');

      if (mounted) {
        setState(() {
          if (cachedName != null && cachedName.isNotEmpty) {
            _nameController.text = cachedName;
          }
          if (cachedUsername != null && cachedUsername.isNotEmpty) {
            _usernameController.text = cachedUsername;
            _currentUsername = cachedUsername;
          }
          if (cachedBio != null) {
            _bioController.text = cachedBio;
          }
          if (cachedPic != null && cachedPic.isNotEmpty) {
            _selectedProfilePic = cachedPic;
          }
          if (cachedPublicId != null) {
            _currentCloudinaryPublicId = cachedPublicId;
          }
        });
      }
    } catch (e) {
      print('Error loading cached profile: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      var snap = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
      if (snap.exists && snap.data() != null) {
        var data = snap.data() as Map<String, dynamic>;
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

        // Cache details locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_profile_name', name);
        await prefs.setString('cached_profile_username', username);
        await prefs.setString('cached_profile_bio', bio);
        await prefs.setString('cached_profile_pic', profilepic);
        if (cloudinaryPublicId != null) {
          await prefs.setString('cached_cloudinary_public_id', cloudinaryPublicId);
        } else {
          await prefs.remove('cached_cloudinary_public_id');
        }
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      isLoading = true;
    });
    try {
      final String newUsername = _usernameController.text.trim().toLowerCase();
      if (newUsername.isEmpty) {
        throw 'Username cannot be empty';
      }

      // Check username uniqueness if they changed it
      if (newUsername != _currentUsername.toLowerCase()) {
        final QuerySnapshot result = await _firestore
            .collection('users')
            .where('username', isEqualTo: newUsername)
            .get();
        if (result.docs.isNotEmpty) {
          throw 'Username is already taken';
        }
      }

      var snap = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
      String? oldPublicId;
      if (snap.exists && snap.data() != null) {
        var data = snap.data() as Map<String, dynamic>;
        oldPublicId = data['cloudinary_public_id'];
      }

      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'name': _nameController.text,
        'username': newUsername,
        'bio': _bioController.text,
        'profilepic': _selectedProfilePic,
        'cloudinary_public_id': _currentCloudinaryPublicId,
      });

      // Sync updated profile pic and username to active statuses
      final batch = _firestore.batch();
      final statusesSnapshot = await _firestore
          .collection('statuses')
          .where('uid', isEqualTo: _auth.currentUser!.uid)
          .get();
      for (var doc in statusesSnapshot.docs) {
        batch.update(doc.reference, {
          'profilePic': _selectedProfilePic,
          'username': newUsername,
        });
      }
      await batch.commit();

      _currentUsername = newUsername;

      // Update cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_profile_name', _nameController.text);
      await prefs.setString('cached_profile_username', newUsername);
      await prefs.setString('cached_profile_bio', _bioController.text);
      await prefs.setString('cached_profile_pic', _selectedProfilePic);
      if (_currentCloudinaryPublicId != null) {
        await prefs.setString('cached_cloudinary_public_id', _currentCloudinaryPublicId!);
      } else {
        await prefs.remove('cached_cloudinary_public_id');
      }

      if (oldPublicId != null && oldPublicId.isNotEmpty && oldPublicId != _currentCloudinaryPublicId) {
        await CloudinaryService.deleteMedia(oldPublicId);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _pickAndUploadCustomImage(ImageSource source) async {
    try {
      final Uint8List? imageBytes = await pickImage(source);
      if (imageBytes == null) return;

      setState(() {
        isLoading = true;
      });

      final uploadResult = await CloudinaryService.uploadImage(imageBytes);
      if (uploadResult != null) {
        final String newUrl = uploadResult['url']!;
        final String newPublicId = uploadResult['public_id']!;
        String? oldPublicId = _currentCloudinaryPublicId;

        setState(() {
          _selectedProfilePic = newUrl;
          _currentCloudinaryPublicId = newPublicId;
        });

        await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
          'profilepic': newUrl,
          'cloudinary_public_id': newPublicId,
        });

        // Sync new profile pic to active statuses
        final batch = _firestore.batch();
        final statusesSnapshot = await _firestore
            .collection('statuses')
            .where('uid', isEqualTo: _auth.currentUser!.uid)
            .get();
        for (var doc in statusesSnapshot.docs) {
          batch.update(doc.reference, {
            'profilePic': newUrl,
          });
        }
        await batch.commit();

        // Update cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_profile_pic', newUrl);
        await prefs.setString('cached_cloudinary_public_id', newPublicId);

        if (oldPublicId != null && oldPublicId.isNotEmpty) {
          await CloudinaryService.deleteMedia(oldPublicId);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload image to Cloudinary.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showProfilePicPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Choose Profile Picture',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select an avatar for your profile.',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _pickAndUploadCustomImage(ImageSource.camera);
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _pickAndUploadCustomImage(ImageSource.gallery);
                            },
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _profilePictures.length,
                      itemBuilder: (context, index) {
                        final path = _profilePictures[index];
                        final isSelected = _selectedProfilePic == path;
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              _selectedProfilePic = path;
                              _currentCloudinaryPublicId = null;
                            });
                            setState(() {
                              _selectedProfilePic = path;
                              _currentCloudinaryPublicId = null;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? colorScheme.primary : Colors.transparent,
                                width: 4,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundImage: AssetImage(path),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _updateProfile();
                        },
                        child: const Text('Save Selection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _deleteUserAccount() async {
    setState(() {
      isLoading = true;
    });
    try {
      String userId = _auth.currentUser!.uid;
      
      // Delete user data from Firestore
      await _firestore.collection('users').doc(userId).delete();
      
      // Delete user authentication account
      await _auth.currentUser!.delete();
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully! Redirecting to login...'),
            duration: Duration(seconds: 2),
          ),
        );
        
        // Wait for 2 seconds before navigation
        await Future.delayed(const Duration(seconds: 2));
        
        // Pop back to root route
        Navigator.of(context).popUntil((route) => route.isFirst);
        // Sign out explicitly
        await _auth.signOut();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => DeleteConfirmationSheet(
        onDelete: _deleteUserAccount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                   const SizedBox(height: 10),
                   Center(
                     child: Stack(
                       alignment: Alignment.center,
                       children: [
                         GestureDetector(
                           onTap: () {
                             if (_selectedProfilePic.isNotEmpty) {
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(
                                   builder: (context) => FullScreenProfilePicPage(
                                     imageUrl: _selectedProfilePic,
                                     heroTag: 'profile_pic_hero_current_user',
                                   ),
                                 ),
                               );
                             } else {
                               _showProfilePicPicker();
                             }
                           },
                           child: Container(
                             padding: const EdgeInsets.all(4),
                             decoration: BoxDecoration(
                               color: colorScheme.primary.withValues(alpha: 0.1),
                               shape: BoxShape.circle,
                             ),
                             child: Hero(
                               tag: 'profile_pic_hero_current_user',
                               child: CircleAvatar(
                                 radius: 60,
                                 backgroundColor: colorScheme.primaryContainer,
                                 backgroundImage: _selectedProfilePic.isNotEmpty
                                     ? (_selectedProfilePic.startsWith('http')
                                         ? CachedNetworkImageProvider(_selectedProfilePic)
                                         : AssetImage(_selectedProfilePic) as ImageProvider)
                                     : null,
                                 child: _selectedProfilePic.isEmpty ? Text(
                                   _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?',
                                   style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer),
                                 ) : null,
                               ),
                             ),
                           ),
                         ),
                         Positioned(
                           bottom: 4,
                           right: 4,
                           child: GestureDetector(
                             onTap: _showProfilePicPicker,
                             child: Container(
                               padding: const EdgeInsets.all(6),
                               decoration: BoxDecoration(
                                 color: colorScheme.primary,
                                 shape: BoxShape.circle,
                                 border: Border.all(color: colorScheme.surface, width: 3),
                               ),
                               child: const Icon(Icons.camera_alt, size: 19, color: Colors.white),
                             ),
                           ),
                         ),
                       ],
                     ),
                   ),
                   const SizedBox(height: 24),
                   Text(
                     _nameController.text,
                     style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                   ),
                   if (_usernameController.text.isNotEmpty) ...[
                     const SizedBox(height: 4),
                     Text(
                       '@${_usernameController.text}',
                       style: TextStyle(
                         fontSize: 15,
                         fontWeight: FontWeight.w600,
                         color: colorScheme.primary,
                       ),
                     ),
                   ],
                   const SizedBox(height: 32),
                   Container(
                     padding: const EdgeInsets.all(24),
                     decoration: BoxDecoration(
                       color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                       borderRadius: BorderRadius.circular(24),
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         _buildInfoItem(context, 'EMAIL ADDRESS', user?.email ?? 'No email'),
                         const Divider(height: 32),
                         _buildInfoItem(context, 'BIO', _bioController.text.isNotEmpty ? _bioController.text : 'Cuqter Member'),
                         const Divider(height: 32),
                         _buildColabFeatureItem(context),
                       ],
                     ),
                   ),
                   const SizedBox(height: 32),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton.icon(
                       style: ElevatedButton.styleFrom(
                         backgroundColor: colorScheme.primary,
                         foregroundColor: colorScheme.onPrimary,
                         padding: const EdgeInsets.symmetric(vertical: 16),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                         elevation: 4,
                         shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                       ),
                       onPressed: _showEditDialog,
                       icon: const Icon(Icons.edit, size: 20),
                       label: const Text(
                         'Edit Profile',
                         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                       ),
                     ),
                   ),
                   const SizedBox(height: 16),
                   TextButton(
                     onPressed: _showDeleteConfirmationDialog,
                     child: Text(
                       'Delete Account',
                       style: TextStyle(color: colorScheme.error),
                     ),
                   ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildColabFeatureItem(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NEW FEATURE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withValues(alpha: 0.15),
                colorScheme.primary.withValues(alpha: 0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Luv Colab',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Collab with other creators & matches',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Soon',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditDialog() {
    String dialogSelectedPic = _selectedProfilePic;
    bool isChecking = false;
    bool? isAvailable;
    String? usernameErrorText;
    Timer? debounceTimer;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final colorScheme = Theme.of(context).colorScheme;

          final bool isSaveDisabled = isChecking ||
              usernameErrorText != null ||
              _usernameController.text.trim().isEmpty ||
              (isAvailable == false && _usernameController.text.trim().toLowerCase() != _currentUsername.toLowerCase());

          return AlertDialog(
            title: const Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixText: '@',
                      errorText: usernameErrorText,
                      helperText: isAvailable == true && usernameErrorText == null
                          ? 'Username is available'
                          : null,
                      helperStyle: const TextStyle(color: Colors.green),
                      suffixIcon: isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : (isAvailable == true
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : (isAvailable == false || usernameErrorText != null
                                  ? const Icon(Icons.error, color: Colors.red)
                                  : null)),
                    ),
                    onChanged: (val) {
                      if (debounceTimer?.isActive ?? false) debounceTimer?.cancel();

                      if (val.contains(' ')) {
                        setDialogState(() {
                          isAvailable = null;
                          usernameErrorText = 'Spaces are not allowed';
                        });
                        return;
                      }

                      final trimmed = val.trim().toLowerCase();
                      if (trimmed.isEmpty) {
                        setDialogState(() {
                          isAvailable = null;
                          usernameErrorText = 'Username cannot be empty';
                        });
                        return;
                      }

                      final regExp = RegExp(r'^[a-zA-Z0-9._]+$');
                      if (!regExp.hasMatch(trimmed)) {
                        setDialogState(() {
                          isAvailable = null;
                          usernameErrorText = 'Only letters, numbers, underscores, and dots';
                        });
                        return;
                      }

                      if (trimmed == _currentUsername.toLowerCase()) {
                        setDialogState(() {
                          isAvailable = true;
                          usernameErrorText = null;
                        });
                        return;
                      }

                      setDialogState(() {
                        isChecking = true;
                        isAvailable = null;
                        usernameErrorText = null;
                      });

                      debounceTimer = Timer(const Duration(milliseconds: 500), () async {
                        try {
                          final query = await FirebaseFirestore.instance
                              .collection('users')
                              .where('username', isEqualTo: trimmed)
                              .get();

                          if (!context.mounted) return;

                          if (_usernameController.text.trim().toLowerCase() != trimmed) {
                            return;
                          }

                          setDialogState(() {
                            isChecking = false;
                            if (query.docs.isNotEmpty) {
                              isAvailable = false;
                              usernameErrorText = 'Username is already taken';
                            } else {
                              isAvailable = true;
                              usernameErrorText = null;
                            }
                          });
                        } catch (e) {
                          if (!context.mounted) return;
                          if (_usernameController.text.trim().toLowerCase() != trimmed) {
                            return;
                          }
                          setDialogState(() {
                            isChecking = false;
                            usernameErrorText = 'Error checking username';
                          });
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bioController,
                    decoration: const InputDecoration(labelText: 'Bio'),
                  ),
                  const SizedBox(height: 20),
                  const Text('Select Avatar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _profilePictures.length,
                      itemBuilder: (context, index) {
                        final path = _profilePictures[index];
                        final isSelected = dialogSelectedPic == path;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              dialogSelectedPic = path;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? colorScheme.primary : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 25,
                              backgroundImage: AssetImage(path),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (debounceTimer?.isActive ?? false) debounceTimer?.cancel();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaveDisabled
                    ? null
                    : () {
                        if (debounceTimer?.isActive ?? false) debounceTimer?.cancel();
                        setState(() {
                          _selectedProfilePic = dialogSelectedPic;
                          if (_selectedProfilePic.startsWith('assets/')) {
                            _currentCloudinaryPublicId = null;
                          }
                        });
                        Navigator.pop(context);
                        _updateProfile();
                      },
                child: const Text('Save'),
              ),
            ],
          );
        }
      ),
    );
  }
}

class DeleteConfirmationSheet extends StatefulWidget {
  final VoidCallback onDelete;

  const DeleteConfirmationSheet({Key? key, required this.onDelete}) : super(key: key);

  @override
  State<DeleteConfirmationSheet> createState() => _DeleteConfirmationSheetState();
}

class _DeleteConfirmationSheetState extends State<DeleteConfirmationSheet> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Entry Animation (bouncy slide up + fade in)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<double>(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );

    // Pulse Animation for warning icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: huge.HugeIcon(
                      icon: huge.HugeIcons.strokeRoundedAlert02,
                      color: colorScheme.error,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Delete Account',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted from our servers.',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDelete();
                },
                child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  foregroundColor: colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

