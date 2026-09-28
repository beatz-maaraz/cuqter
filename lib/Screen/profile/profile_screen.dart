import 'dart:async';
import 'dart:ui';
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

                return Stack(
                  children: [
                    // Dynamic Glassmorphism Background
                    if (_selectedProfilePic.isNotEmpty)
                      Positioned.fill(
                        child: _selectedProfilePic.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: _selectedProfilePic,
                                fit: BoxFit.cover,
                              )
                            : Image.asset(
                                _selectedProfilePic,
                                fit: BoxFit.cover,
                              ),
                      ),
                    if (_selectedProfilePic.isEmpty)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorScheme.primary,
                                colorScheme.tertiary,
                                colorScheme.secondary,
                              ],
                            ),
                          ),
                        ),
                      ),
                    
                    // Glass Blur Overlay
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 35.0, sigmaY: 35.0),
                        child: Container(
                          color: colorScheme.surface.withOpacity(0.65),
                        ),
                      ),
                    ),

                    // Main Content
                    CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // App Bar
                        SliverToBoxAdapter(
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Profile',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.0,
                                    ),
                                  ),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 10,
                                        sigmaY: 10,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: colorScheme.surface
                                              .withOpacity(0.5),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white
                                                .withOpacity(0.2),
                                          ),
                                        ),
                                        child: IconButton(
                                          tooltip: 'Settings',
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const SettingsPage(),
                                              ),
                                            );
                                          },
                                          icon: const huge.HugeIcon(
                                            icon: huge.HugeIcons
                                                .strokeRoundedSettings01,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Avatar
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 32),
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer Glow
                                  Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: colorScheme.primary
                                              .withOpacity(0.4),
                                          blurRadius: 40,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Animated Gradient Border
                                  Container(
                                    width: 136,
                                    height: 136,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          colorScheme.primary,
                                          colorScheme.tertiary,
                                          colorScheme.secondary,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colorScheme.surface,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: GestureDetector(
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
                                            _navigateToEditProfileScreen();
                                          }
                                        },
                                        child: Hero(
                                          tag: 'profile_pic_hero_current_user',
                                          child: CircleAvatar(
                                            backgroundColor: colorScheme
                                                .surfaceContainerHighest,
                                            backgroundImage:
                                                _selectedProfilePic.isNotEmpty
                                                    ? (_selectedProfilePic
                                                            .startsWith('http')
                                                        ? CachedNetworkImageProvider(
                                                            _selectedProfilePic)
                                                        : AssetImage(
                                                                _selectedProfilePic)
                                                            as ImageProvider)
                                                    : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Camera Badge
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _navigateToEditProfileScreen,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colorScheme.surface,
                                            width: 4,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.2),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Glassmorphic Info Card
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface
                                        .withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: Colors.white
                                          .withOpacity(0.2),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Name & Badge
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _nameController.text.isNotEmpty
                                                  ? _nameController.text
                                                  : 'Cuqter User',
                                              style: const TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: -0.5,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary
                                                  .withOpacity(0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: huge.HugeIcon(
                                              icon: huge.HugeIcons
                                                  .strokeRoundedCheckmarkBadge01,
                                              color: colorScheme.primary,
                                              size: 22,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Username
                                      GestureDetector(
                                        onTap: _copyUsernameToClipboard,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(24),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  '@${_usernameController.text}',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: colorScheme.primary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              huge.HugeIcon(
                                                icon: huge.HugeIcons
                                                    .strokeRoundedCopy01,
                                                color: colorScheme.primary,
                                                size: 16,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // Divider
                                      Container(
                                        height: 1,
                                        width: 100,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.1),
                                      ),
                                      const SizedBox(height: 24),

                                      // Bio
                                      Text(
                                        _bioController.text.isNotEmpty
                                            ? _bioController.text
                                            : '✨ Loving every moment on Cuqter!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          height: 1.5,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface
                                              .withOpacity(0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 16),
                        ),

                        // Friends Card
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ContactScreen(),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                      horizontal: 24,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface
                                          .withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Colors.white
                                            .withOpacity(0.2),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary
                                                .withOpacity(0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: huge.HugeIcon(
                                            icon: huge.HugeIcons
                                                .strokeRoundedUserGroup,
                                            color: colorScheme.primary,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${contacts.whereType<String>().where((id) => id.trim().isNotEmpty && id != user?.uid).toSet().length}',
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            Text(
                                              'Friends',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: colorScheme.onSurface
                                                    .withOpacity(0.7),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: colorScheme.surface
                                                .withOpacity(0.5),
                                            shape: BoxShape.circle,
                                          ),
                                          child: huge.HugeIcon(
                                            icon: huge.HugeIcons
                                                .strokeRoundedArrowRight01,
                                            color: colorScheme.onSurface,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: 24),
                        ),

                        // Edit Profile Button
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                elevation: 8,
                                shadowColor:
                                    colorScheme.primary.withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: _navigateToEditProfileScreen,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const huge.HugeIcon(
                                    icon: huge.HugeIcons.strokeRoundedEdit02,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Edit Profile',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: 40),
                        ),
                      ],
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
