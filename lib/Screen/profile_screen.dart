import 'dart:async';
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
import 'package:cuqter/Screen/camera_screen.dart';
import 'package:cuqter/media.dart';
import 'package:cuqter/Screen/contact_screen.dart';
import 'package:cuqter/Account/login.dart';
import 'package:cuqter/Screen/settings_page.dart';

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
      final String? cachedPublicId = prefs.getString(
        'cached_cloudinary_public_id',
      );

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
      var snap = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
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
          await prefs.setString(
            'cached_cloudinary_public_id',
            cloudinaryPublicId,
          );
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

      var snap = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
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
        await prefs.setString(
          'cached_cloudinary_public_id',
          _currentCloudinaryPublicId!,
        );
      } else {
        await prefs.remove('cached_cloudinary_public_id');
      }

      if (oldPublicId != null &&
          oldPublicId.isNotEmpty &&
          oldPublicId != _currentCloudinaryPublicId) {
        await CloudinaryService.deleteMedia(oldPublicId);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _removeProfilePicture() async {
    try {
      setState(() {
        isLoading = true;
      });
      String? oldPublicId = _currentCloudinaryPublicId;

      setState(() {
        _selectedProfilePic = '';
        _currentCloudinaryPublicId = null;
      });

      await _firestore.collection('users').doc(_auth.currentUser!.uid).update(
        {'profilepic': '', 'cloudinary_public_id': null},
      );

      final batch = _firestore.batch();
      final statusesSnapshot = await _firestore
          .collection('statuses')
          .where('uid', isEqualTo: _auth.currentUser!.uid)
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture removed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing picture: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: Center(
              child: huge.HugeIcon(
                icon: icon,
                color: color,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadCustomImage(ImageSource source, {bool isNativePicker = false}) async {
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
        // Mobile own native gallery / Google Photos / Files app
        final XFile? file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        if (file != null) {
          imageBytes = await file.readAsBytes();
        }
      } else {
        // Internal App Gallery (AssetManagerScreen)
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

        await _firestore.collection('users').doc(_auth.currentUser!.uid).update(
          {'profilepic': newUrl, 'cloudinary_public_id': newPublicId},
        );

        // Sync new profile pic to active statuses
        final batch = _firestore.batch();
        final statusesSnapshot = await _firestore
            .collection('statuses')
            .where('uid', isEqualTo: _auth.currentUser!.uid)
            .get();
        for (var doc in statusesSnapshot.docs) {
          batch.update(doc.reference, {'profilePic': newUrl});
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
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload image to Cloudinary.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
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
                  const Text(
                    'Choose',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_selectedProfilePic.isNotEmpty)
                    IconButton(
                      tooltip: 'Remove profile picture',
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _removeProfilePicture();
                      },
                      icon: const huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedDelete02,
                        color: Colors.red,
                        size: 22,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
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
                    label: 'Other',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndUploadCustomImage(ImageSource.gallery, isNativePicker: true);
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
  Future<void> _deleteUserAccount() async {
    setState(() {
      isLoading = true;
    });
    
    // Capture Navigator and ScaffoldMessenger state *before* performing any asynchronous operations
    // that could result in the widget being unmounted/disposed.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      String userId = _auth.currentUser!.uid;

      // 1. Fetch user data (contacts, profile picture public ID)
      DocumentSnapshot userSnap = await _firestore.collection('users').doc(userId).get();
      Map<String, dynamic>? userData = userSnap.data() as Map<String, dynamic>?;

      // 2. Delete user's profile picture from Cloudinary
      try {
        String? oldPublicId = userData?['cloudinary_public_id'] ?? _currentCloudinaryPublicId;
        if (oldPublicId != null && oldPublicId.isNotEmpty) {
          await CloudinaryService.deleteMedia(oldPublicId);
        }
      } catch (e) {
        debugPrint('Error deleting user profile picture: $e');
      }

      // 3. Delete user's statuses and status media from Cloudinary
      try {
        final statusesSnapshot = await _firestore
            .collection('statuses')
            .where('uid', isEqualTo: userId)
            .get();
        for (var doc in statusesSnapshot.docs) {
          try {
            final data = doc.data();
            final mediaUrl = data['mediaUrl'] as String?;
            final mediaType = data['mediaType'] as String?;
            if (mediaUrl != null && mediaUrl.isNotEmpty && mediaType != 'text') {
              final publicId = CloudinaryService.extractPublicId(mediaUrl);
              if (publicId != null) {
                await CloudinaryService.deleteMedia(publicId, resourceType: mediaType ?? 'image');
              }
            }
          } catch (e) {
            debugPrint('Error deleting status media: $e');
          }
          
          try {
            // Delete related notifications
            final statusId = doc.id;
            final notifSnapshot = await _firestore
                .collection('notifications')
                .where('statusId', isEqualTo: statusId)
                .get();
            for (var notifDoc in notifSnapshot.docs) {
              await notifDoc.reference.delete();
            }
          } catch (e) {
            debugPrint('Error deleting status notifications: $e');
          }

          try {
            await doc.reference.delete();
          } catch (e) {
            debugPrint('Error deleting status doc: $e');
          }
        }
      } catch (e) {
        debugPrint('Error querying/deleting statuses: $e');
      }

      // 3.5. Delete user likes and views on other statuses
      try {
        final allStatuses = await _firestore.collection('statuses').get();
        for (var statusDoc in allStatuses.docs) {
          final data = statusDoc.data();
          final List<dynamic>? viewersRaw = data['viewers'] as List<dynamic>?;
          final List<dynamic>? likesRaw = data['likes'] as List<dynamic>?;
          
          bool needsUpdate = false;
          List<Map<String, dynamic>> newViewers = [];
          List<Map<String, dynamic>> newLikes = [];
          
          if (viewersRaw != null) {
            for (var v in viewersRaw) {
              if (v is Map && v['uid'] != userId) {
                newViewers.add(Map<String, dynamic>.from(v));
              } else if (v is String && v != userId) {
                newViewers.add({'uid': v, 'username': 'User', 'profilePic': '', 'viewedAt': Timestamp.now()});
              } else if (v is Map && v['uid'] == userId) {
                needsUpdate = true;
              } else if (v is String && v == userId) {
                needsUpdate = true;
              }
            }
          }
          
          if (likesRaw != null) {
            for (var l in likesRaw) {
              if (l is Map && l['uid'] != userId) {
                newLikes.add(Map<String, dynamic>.from(l));
              } else if (l is String && l != userId) {
                newLikes.add({'uid': l, 'username': 'User', 'profilePic': '', 'likedAt': Timestamp.now()});
              } else if (l is Map && l['uid'] == userId) {
                needsUpdate = true;
              } else if (l is String && l == userId) {
                needsUpdate = true;
              }
            }
          }
          
          if (needsUpdate) {
            await statusDoc.reference.update({
              if (viewersRaw != null) 'viewers': newViewers,
              if (likesRaw != null) 'likes': newLikes,
            });
          }
        }
      } catch (e) {
        debugPrint('Error cleaning up likes/views from other statuses: $e');
      }

      // 4. Remove user from other users' contacts
      try {
        List<dynamic> contacts = userData?['contacts'] as List<dynamic>? ?? [];
        for (var contactId in contacts) {
          if (contactId is String) {
            await _firestore.collection('users').doc(contactId).update({
              'contacts': FieldValue.arrayRemove([userId])
            });
          }
        }
      } catch (e) {
        debugPrint('Error removing from contacts lists: $e');
      }

      // 5. Delete friend requests sent/received by this user
      try {
        final sentRequests = await _firestore
            .collection('friend_requests')
            .where('senderId', isEqualTo: userId)
            .get();
        for (var doc in sentRequests.docs) {
          await doc.reference.delete();
        }

        final receivedRequests = await _firestore
            .collection('friend_requests')
            .where('receiverId', isEqualTo: userId)
            .get();
        for (var doc in receivedRequests.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Error deleting friend requests: $e');
      }

      // 6. Delete notifications sent/received by this user
      try {
        final sentNotifs = await _firestore
            .collection('notifications')
            .where('senderId', isEqualTo: userId)
            .get();
        for (var doc in sentNotifs.docs) {
          await doc.reference.delete();
        }

        final receivedNotifs = await _firestore
            .collection('notifications')
            .where('receiverId', isEqualTo: userId)
            .get();
        for (var doc in receivedNotifs.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Error deleting notifications: $e');
      }

      // 7. Delete chat rooms and messages containing this user, and delete message media from Cloudinary
      try {
        final chatsSnapshot = await _firestore.collection('chats').get();
        for (var chatDoc in chatsSnapshot.docs) {
          final chatId = chatDoc.id;
          if (chatId.contains(userId)) {
            // Get all messages under chats/chatId/messages
            final messagesSnapshot = await chatDoc.reference.collection('messages').get();
            for (var messageDoc in messagesSnapshot.docs) {
              try {
                final msgData = messageDoc.data();
                final senderId = msgData['senderId'] as String?;
                final type = msgData['type'] as String?;
                final text = msgData['text'] as String?;
                
                // Delete media from Cloudinary if it was sent by this user and is media
                if (senderId == userId && type != null && type != 'text' && text != null && text.isNotEmpty) {
                  final url = text.split('|').first;
                  final publicId = CloudinaryService.extractPublicId(url);
                  if (publicId != null) {
                    await CloudinaryService.deleteMedia(publicId, resourceType: type);
                  }
                }
              } catch (e) {
                debugPrint('Error deleting message media from Cloudinary: $e');
              }
              try {
                await messageDoc.reference.delete();
              } catch (e) {
                debugPrint('Error deleting message doc: $e');
              }
            }
            try {
              await chatDoc.reference.delete();
            } catch (e) {
              debugPrint('Error deleting chat doc: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Error deleting chats and messages: $e');
      }

      // 8. Delete user call history subcollection
      try {
        final callHistorySnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('call_history')
            .get();
        for (var doc in callHistorySnapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Error deleting call history: $e');
      }

      // 9. Clear local SharedPreferences cache
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (e) {
        debugPrint('Error clearing SharedPreferences cache: $e');
      }

      // 10. Delete main user document in Firestore
      await _firestore.collection('users').doc(userId).delete();

      // 11. Delete Firebase Auth user
      await _auth.currentUser!.delete();

      // Show success message using captured messenger context
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Account deleted successfully! Redirecting to login...',
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Wait for 2 seconds before navigation
      await Future.delayed(const Duration(seconds: 2));

      // Explicitly redirect to Loginpage and clear the routing stack
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Loginpage()),
        (route) => false,
      );

      // Sign out explicitly
      await _auth.signOut();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete account: $e')));
      }
    }
  }

  void _showDeleteConfirmationDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) =>
          DeleteConfirmationSheet(onDelete: _deleteUserAccount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const SettingsPage(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                ),
              );
            },
            icon: huge.HugeIcon(
              icon: huge.HugeIcons.strokeRoundedSettings01,
              color: colorScheme.onSurface,
              size: 24,
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(
                  left: 24, right: 24, top: 16, bottom: 90),
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
                                  builder: (context) =>
                                      FullScreenProfilePicPage(
                                        imageUrl: _selectedProfilePic,
                                        heroTag:
                                            'profile_pic_hero_current_user',
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
                                          ? CachedNetworkImageProvider(
                                              _selectedProfilePic,
                                            )
                                          : AssetImage(_selectedProfilePic)
                                                as ImageProvider)
                                    : const AssetImage('assets/icon/default_profile.png'),
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
                                border: Border.all(
                                  color: colorScheme.surface,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 19,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 24),

                  // Name and Bio Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _nameController.text,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${_usernameController.text}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(),
                        ),
                        Text(
                          _bioController.text.isNotEmpty
                              ? _bioController.text
                              : 'Cuqter Member',
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Friends and Followers Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: colorScheme.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const ContactScreen(),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
                                      return SlideTransition(
                                        position:
                                            Tween<Offset>(
                                              begin: const Offset(1.0, 0.0),
                                              end: Offset.zero,
                                            ).animate(
                                              CurvedAnimation(
                                                parent: animation,
                                                curve: Curves.easeOutCubic,
                                              ),
                                            ),
                                        child: FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        ),
                                      );
                                    },
                                transitionDuration: const Duration(
                                  milliseconds: 250,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Friends',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: colorScheme.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          onPressed: () {
                            // Action for followers if any
                          },
                          child: const Text(
                            'Followers',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Close Friend Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                      ),
                      onPressed: () {
                        // Action for close friend
                      },
                      icon: huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedLockPassword,
                        size: 22,
                        color: colorScheme.onSurface,
                      ),
                      label: Text(
                        'close friend',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Edit and Delete
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _showEditDialog,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Profile'),
                      ),
                      TextButton(
                        onPressed: _showDeleteConfirmationDialog,
                        child: Text(
                          'Delete Account',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
          final bool isSaveDisabled =
              isChecking ||
              usernameErrorText != null ||
              _usernameController.text.trim().isEmpty ||
              (isAvailable == false &&
                  _usernameController.text.trim().toLowerCase() !=
                      _currentUsername.toLowerCase());

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
                      helperText:
                          isAvailable == true && usernameErrorText == null
                          ? 'Username is available'
                          : null,
                      helperStyle: const TextStyle(color: Colors.green),
                      suffixIcon: isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : (isAvailable == true
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : (isAvailable == false ||
                                          usernameErrorText != null
                                      ? const Icon(
                                          Icons.error,
                                          color: Colors.red,
                                        )
                                      : null)),
                    ),
                    onChanged: (val) {
                      if (debounceTimer?.isActive ?? false)
                        debounceTimer?.cancel();

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
                          usernameErrorText =
                              'Only letters, numbers, underscores, and dots';
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

                      debounceTimer = Timer(
                        const Duration(milliseconds: 500),
                        () async {
                          try {
                            final query = await FirebaseFirestore.instance
                                .collection('users')
                                .where('username', isEqualTo: trimmed)
                                .get();

                            if (!context.mounted) return;

                            if (_usernameController.text.trim().toLowerCase() !=
                                trimmed) {
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
                            if (_usernameController.text.trim().toLowerCase() !=
                                trimmed) {
                              return;
                            }
                            setDialogState(() {
                              isChecking = false;
                              usernameErrorText = 'Error checking username';
                            });
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bioController,
                    decoration: const InputDecoration(labelText: 'Bio'),
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
                        if (debounceTimer?.isActive ?? false)
                          debounceTimer?.cancel();
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
        },
      ),
    );
  }
}

class DeleteConfirmationSheet extends StatefulWidget {
  final VoidCallback onDelete;

  const DeleteConfirmationSheet({Key? key, required this.onDelete})
    : super(key: key);

  @override
  State<DeleteConfirmationSheet> createState() =>
      _DeleteConfirmationSheetState();
}

class _DeleteConfirmationSheetState extends State<DeleteConfirmationSheet>
    with TickerProviderStateMixin {
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
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));

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
          child: Opacity(opacity: _fadeAnimation.value, child: child),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDelete();
                },
                child: const Text(
                  'Delete Account',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  foregroundColor: colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
