import 'package:cuqter/Screen/profile/profilemanage.dart';
import 'package:flutter/material.dart';
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
import 'package:provider/provider.dart';
import 'package:cuqter/providers/theme_provider.dart';

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
  String _username = '';
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
              _username = doc.data()?['username'] ?? '';
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
                      subtitle: 'Design System (${Provider.of<ThemeProvider>(context).designStyle.shortName}), dark mode & colors',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBadge(context, Provider.of<ThemeProvider>(context).designStyle.shortName.toUpperCase()),
                          const SizedBox(width: 8),
                          huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedArrowRight01, size: 20, color: colorScheme.onSurface.withValues(alpha: 0.3)),
                        ],
                      ),
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
                        SharePlus.instance.share(
                          ShareParams(text: 'Hey! I am using Cuqter to chat and share media securely. Download it now to connect with me! https://cuqter.com'),
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
            const SizedBox(width: 12),
            IconButton(
              icon: huge.HugeIcon(
                icon: huge.HugeIcons.strokeRoundedQrCode01,
                color: colorScheme.primary,
                size: 28,
              ),
              onPressed: () {
                _showQrCodeDialog(context, colorScheme);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQrCodeDialog(BuildContext context, ColorScheme colorScheme) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'unknown';
    // Use username-based URL if available, fallback to uid
    final profileSlug = _username.isNotEmpty ? _username : uid;
    final qrData = 'https://cuqter.com/$profileSlug';
    final String hexColor = colorScheme.primary.toARGB32().toRadixString(16).padLeft(8, '0');
    final String rgbHex = hexColor.length >= 8 ? hexColor.substring(2) : hexColor;
    final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(qrData)}&color=$rgbHex';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'My QR Code',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan this code to add me on Cuqter',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 24),
              // QR Code container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: qrUrl,
                    width: 200,
                    height: 200,
                    placeholder: (context, url) => Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey.shade100,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.qr_code_rounded, size: 64, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Profile link
              GestureDetector(
                onTap: () {
                  SharePlus.instance.share(ShareParams(text: 'Add me on Cuqter! $qrData'));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedLink01,
                        color: colorScheme.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        qrData.replaceFirst('https://', ''),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Profile summary
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: _profilepic.isNotEmpty
                        ? (_profilepic.startsWith('http')
                            ? CachedNetworkImageProvider(_profilepic)
                            : AssetImage(_profilepic) as ImageProvider)
                        : null,
                    child: _profilepic.isEmpty ? Text(
                      _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer),
                    ) : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (_username.isNotEmpty)
                        Text(
                          '@$_username',
                          style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.w500),
                        )
                      else
                        Text(
                          _email,
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        SharePlus.instance.share(ShareParams(text: 'Add me on Cuqter! $qrData'));
                      },
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
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

