import 'package:cuqter/Screen/profile/profilemanage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuqter/providers/theme_provider.dart';
import 'package:cuqter/resources/auth_method.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuqter/Screen/profile/profile_screen.dart';
import 'package:cuqter/Screen/settings/chat_settings_page.dart';
import 'package:cuqter/Screen/settings/security_settings_page.dart';
import 'package:cuqter/Screen/settings/notification_settings_page.dart';
import 'package:cuqter/Screen/settings/about_page.dart';
import 'package:cuqter/Screen/settings/storage_settings_page.dart';
import 'package:cuqter/Screen/settings/appearance_settings_page.dart';
import 'package:cuqter/Screen/settings/network_usage_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:share_plus/share_plus.dart';

class SettingsPage extends StatefulWidget {
  final bool isDialog;
  const SettingsPage({super.key, this.isDialog = false});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _name = 'User';
  String _email = '';
  String _profilepic = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _name = user.displayName ?? 'User';
      _email = user.email ?? '';
    }
    _loadCachedProfile();
    _loadUserData();
  }

  Future<void> _loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedName = prefs.getString('cached_profile_name');
      final String? cachedPic = prefs.getString('cached_profile_pic');
      
      if (mounted) {
        setState(() {
          if (cachedName != null && cachedName.isNotEmpty) {
            _name = cachedName;
          }
          if (cachedPic != null && cachedPic.isNotEmpty) {
            _profilepic = cachedPic;
          }
        });
      }
    } catch (e) {
      print('Error loading cached profile in settings: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            if (doc.exists) {
              _name = doc.data()?['name'] ?? 'User';
              _profilepic = doc.data()?['profilepic'] ?? '';
            }
            _email = user.email ?? '';
          });
        }

        // Cache the latest Firestore data
        if (doc.exists) {
          final String name = doc.data()?['name'] ?? 'User';
          final String profilepic = doc.data()?['profilepic'] ?? '';
          final String bio = doc.data()?['bio'] ?? '';
          final String? cloudinaryPublicId = doc.data()?['cloudinary_public_id'];
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_profile_name', name);
          await prefs.setString('cached_profile_bio', bio);
          await prefs.setString('cached_profile_pic', profilepic);
          if (cloudinaryPublicId != null) {
            await prefs.setString('cached_cloudinary_public_id', cloudinaryPublicId);
          } else {
            await prefs.remove('cached_cloudinary_public_id');
          }
        }
      }
    } catch (e) {
      // Handle error conceptually
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isDialog
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              )
            : null,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 20),
                _buildProfileHeader(colorScheme),
                const SizedBox(height: 30),
                _buildSectionLabel(context, 'ACCOUNT PREFERENCES'),
                const SizedBox(height: 10),
                _buildGroupedSection(children: [
                   _buildSettingsTile(
                    icon: huge.HugeIcons.strokeRoundedUser,
                    title: 'Profile Manage',
                    subtitle: 'Identity, privacy & blocked friends',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileManage()),
                      ).then((_) => _loadUserData());
                    },
                  ),
                  _buildSettingsTile(
                    icon: huge.HugeIcons.strokeRoundedNotification01,
                    title: 'Notifications',
                    subtitle: 'Tone and frequency control',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationSettingsPage()),
                      );
                    },
                  ),
                   _buildSettingsTile(
                     icon: huge.HugeIcons.strokeRoundedSecurityValidation,
                     title: 'Security',
                     subtitle: 'Authentication and privacy',
                     onTap: () {
                       Navigator.push(
                         context,
                         MaterialPageRoute(builder: (context) => const SecuritySettingsPage()),
                       );
                     },
                   ),
                   _buildSettingsTile(
                     icon: huge.HugeIcons.strokeRoundedBubbleChat,
                     title: 'Chats',
                     subtitle: 'Wallpaper, preferences and history',
                     onTap: () {
                       Navigator.push(
                         context,
                         MaterialPageRoute(builder: (context) => const ChatSettingsPage()),
                       );
                     },
                   ),
                    _buildSettingsTile(
                      icon: huge.HugeIcons.strokeRoundedPaintBoard,
                      title: 'Appearance',
                      subtitle: 'Dark mode, custom colors, text size',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AppearanceSettingsPage()),
                        );
                      },
                    ),
                 ]),
                  const SizedBox(height: 30),
                  _buildSectionLabel(context, 'STORAGE & DATA'),
                  const SizedBox(height: 10),
                  _buildGroupedSection(children: [
                    _buildSettingsTile(
                      icon: huge.HugeIcons.strokeRoundedHardDrive,
                      title: 'Storage & Data',
                      subtitle: 'Network usage, cache and downloads',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const StorageSettingsPage()),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      icon: huge.HugeIcons.strokeRoundedUpload01,
                      title: 'Network Usage',
                      subtitle: 'Detailed messaging and calling statistics',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NetworkUsagePage()),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 30),
                  _buildSectionLabel(context, 'ABOUT'),
                  const SizedBox(height: 10),
                  _buildGroupedSection(children: [
                    _buildSettingsTile(
                      icon: huge.HugeIcons.strokeRoundedHelpCircle,
                      title: 'About Cuqter',
                      subtitle: 'Help, FAQ, and app details',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AboutPage()),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      icon: huge.HugeIcons.strokeRoundedShare01,
                      title: 'Share Cuqter',
                      subtitle: 'Invite friends to chat on Cuqter',
                      onTap: () {
                        Share.share(
                          'Hey! I am using Cuqter to chat and share media securely. Download it now to connect with me! https://cuqter.com',
                        );
                      },
                    ),
                  ]),
                 const SizedBox(height: 40),
                _buildSignOutButton(context, colorScheme),
                const SizedBox(height: 20),
                 Center(
                   child: FutureBuilder<PackageInfo>(
                     future: PackageInfo.fromPlatform(),
                     builder: (context, snapshot) {
                       final version = snapshot.hasData ? snapshot.data!.version : '1.4.21';
                       return Text(
                         'VERSION $version • CUQTER UI',
                         style: TextStyle(
                           fontSize: 10,
                           color: colorScheme.onSurface.withValues(alpha: 0.4),
                           letterSpacing: 1.2,
                         ),
                       );
                     },
                   ),
                 ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildProfileHeader(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ProfileScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
                  child: child,
                ),
              );
            },
          ),
        ).then((_) => _loadUserData());
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: _profilepic.isNotEmpty
                      ? (_profilepic.startsWith('http')
                          ? CachedNetworkImageProvider(_profilepic)
                          : AssetImage(_profilepic) as ImageProvider)
                      : null,
                  child: _profilepic.isEmpty ? Text(
                    _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer),
                  ) : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.surface, width: 2),
                    ),
                    child: const Icon(Icons.edit, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _email,
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ACTIVE USER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildGroupedSection({required List<Widget> children}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile({
    required List<List<dynamic>> icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeIconColor = iconColor ?? colorScheme.primary;
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: themeIconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: huge.HugeIcon(icon: icon, size: 20, color: themeIconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: trailing ?? huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedArrowRight01, size: 20, color: colorScheme.onSurface.withValues(alpha: 0.3)),
    );
  }

  Widget _buildBadge(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context, ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.3),
          foregroundColor: colorScheme.error,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => _showSignOutDialog(context),
        icon: huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedLogout01, color: colorScheme.error, size: 20),
        label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedLogout01, color: colorScheme.error, size: 32),
              ),
              const SizedBox(height: 24),
              const Text(
                'Sign Out?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'You\'re about to end your session. You\'ll need to enter your credentials again to access your account.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B2D26), // Matching the red from design
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () async {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                        'isOnline': false,
                        'lastSeen': FieldValue.serverTimestamp(),
                      }).catchError((_) {});
                    }
                    
                    await AuthMethod().signOut();
                  },
                  child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

