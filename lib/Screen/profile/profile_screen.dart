import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuqter/widgets/full_screen_profile_pic_page.dart';
import 'package:cuqter/Screen/profile/contact_screen.dart';
import 'package:cuqter/Screen/profile/edit_profile_screen.dart';
import 'package:cuqter/Screen/settings/settings_page.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _nameController.text = _auth.currentUser?.displayName ?? '';
    _loadCachedProfile();
    _loadUserData();
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
      debugPrint('Error loading cached profile: $e');
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      var snap = await _firestore.collection('users').doc(user.uid).get();
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
      debugPrint('Error loading user data: $e');
    }
  }




  void _copyUsernameToClipboard() {
    final username = _usernameController.text.trim();
    if (username.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: '@$username'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.copy, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Copied @$username to clipboard!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }





  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: user != null
                  ? _firestore.collection('users').doc(user.uid).snapshots()
                  : null,
              builder: (context, snapshot) {
                List<dynamic> contacts = [];
                if (snapshot.hasData && snapshot.data?.exists == true) {
                  var data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null) {
                    contacts = data['contacts'] as List<dynamic>? ?? [];
                  }
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Dynamic Ambient Header
                    SliverToBoxAdapter(
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // Header Mesh Gradient
                          Container(
                            height: 230,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.primaryContainer,
                                  colorScheme.surfaceContainerHighest.withValues(
                                    alpha: 0.5,
                                  ),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(40),
                              ),
                            ),
                            child: SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        left: 12,
                                        top: 10,
                                      ),
                                      child: Text(
                                        'Profile',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        tooltip: 'Settings',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              transitionDuration:
                                                  const Duration(
                                                    milliseconds: 350,
                                                  ),
                                              reverseTransitionDuration:
                                                  const Duration(
                                                    milliseconds: 300,
                                                  ),
                                              pageBuilder:
                                                  (
                                                    context,
                                                    animation,
                                                    secondaryAnimation,
                                                  ) => const SettingsPage(),
                                              transitionsBuilder: (
                                                context,
                                                animation,
                                                secondaryAnimation,
                                                child,
                                              ) {
                                                final curvedAnimation =
                                                    CurvedAnimation(
                                                      parent: animation,
                                                      curve:
                                                          Curves.easeOutCubic,
                                                      reverseCurve:
                                                          Curves.easeInCubic,
                                                    );
                                                return SlideTransition(
                                                  position: Tween<Offset>(
                                                    begin: const Offset(
                                                      0.05,
                                                      0.0,
                                                    ),
                                                    end: Offset.zero,
                                                  ).animate(curvedAnimation),
                                                  child: FadeTransition(
                                                    opacity: curvedAnimation,
                                                    child: child,
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                        icon: const huge.HugeIcon(
                                          icon: huge
                                              .HugeIcons
                                              .strokeRoundedSettings01,
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

                          // Profile Avatar Floating Stack
                          Positioned(
                            top: 140,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glowing Halo BoxShadow
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 28,
                                        spreadRadius: 6,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Container(
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
                                                builder: (context) =>
                                                    FullScreenProfilePicPage(
                                                      imageUrl:
                                                          _selectedProfilePic,
                                                      heroTag:
                                                          'profile_pic_hero_current_user',
                                                    ),
                                              ),
                                            );
                                          } else {
                                            _navigateToEditProfileScreen();
                                          }
                                        },
                                        child: Hero(
                                          tag: 'profile_pic_hero_current_user',
                                          child: CircleAvatar(
                                            radius: 54,
                                            backgroundColor:
                                                colorScheme
                                                    .surfaceContainerHighest,
                                            backgroundImage:
                                                _selectedProfilePic.isNotEmpty
                                                ? (_selectedProfilePic
                                                      .startsWith('http')
                                                      ? CachedNetworkImageProvider(
                                                          _selectedProfilePic,
                                                        )
                                                      : AssetImage(
                                                          _selectedProfilePic,
                                                        )
                                                            as ImageProvider)
                                                : const AssetImage(
                                                    'assets/icon/default_profile.png',
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Camera Upload Action Badge
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: _navigateToEditProfileScreen,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colorScheme.surface,
                                          width: 3.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.15,
                                            ),
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

                                // Active Online Status Badge
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colorScheme.surface,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Spacer for Avatar Overflow
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 70),
                    ),

                    // Profile User Identity Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            // Display Name + Verified Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _nameController.text.isNotEmpty
                                      ? _nameController.text
                                      : 'Cuqter User',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: huge.HugeIcon(
                                    icon: huge
                                        .HugeIcons
                                        .strokeRoundedCheckmarkBadge01,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Username Copyable Chip
                            GestureDetector(
                              onTap: _copyUsernameToClipboard,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '@${_usernameController.text}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    huge.HugeIcon(
                                      icon: huge.HugeIcons.strokeRoundedCopy01,
                                      color: colorScheme.primary,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Bio Quote Container
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.08,
                                  ),
                                ),
                              ),
                              child: Text(
                                _bioController.text.isNotEmpty
                                    ? _bioController.text
                                    : '✨ Loving every moment on Cuqter!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  height: 1.4,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Real Database Friends Stat (Friends Only)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ContactScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.08,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: huge.HugeIcon(
                                        icon:
                                            huge
                                                .HugeIcons
                                                .strokeRoundedUserGroup,
                                        color: colorScheme.primary,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${contacts.whereType<String>().where((id) => id.trim().isNotEmpty && id != user?.uid).toSet().length}',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Friends',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    huge.HugeIcon(
                                      icon:
                                          huge
                                              .HugeIcons
                                              .strokeRoundedArrowRight01,
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.3,
                                      ),
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Primary Action Row (Edit Profile)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _navigateToEditProfileScreen,
                                icon: const huge.HugeIcon(
                                  icon: huge.HugeIcons.strokeRoundedEdit02,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Edit Profile',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 40),
                    ),
                  ],
                );
              },
            ),
    );
  }





  Future<void> _navigateToEditProfileScreen() async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            EditProfileScreen(
              initialName: _nameController.text,
              initialUsername: _usernameController.text,
              initialBio: _bioController.text,
              initialProfilePic: _selectedProfilePic,
              initialCloudinaryPublicId: _currentCloudinaryPublicId,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0.0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: FadeTransition(
              opacity: curvedAnimation,
              child: child,
            ),
          );
        },
      ),
    );
    if (result == true) {
      _loadUserData();
    }
  }
}
