import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuqter/providers/theme_provider.dart';
import 'package:cuqter/resources/auth_method.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cuqter/Screen/profile_screen.dart';
import 'package:cuqter/Screen/chat_settings_page.dart';
import 'package:cuqter/Screen/about_page.dart';
import 'package:hugeicons/hugeicons.dart' as huge;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

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
    _loadUserData();
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
      }
    } catch (e) {
      // Handle error conceptually
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
                    title: 'Profile',
                    subtitle: 'Manage your public identity',
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: huge.HugeIcons.strokeRoundedNotification01,
                    title: 'Notifications',
                    subtitle: 'Tone and frequency control',
                    trailing: _buildBadge(context, '3 Active'),
                    onTap: () {},
                  ),
                   _buildSettingsTile(
                     icon: huge.HugeIcons.strokeRoundedSecurityValidation,
                     title: 'Security',
                     subtitle: 'Authentication and privacy',
                     onTap: () {},
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
                   _buildAppearanceTile(themeProvider, colorScheme),
                ]),
                 const SizedBox(height: 30),
                 _buildSectionLabel(context, 'ABOUT'),
                 const SizedBox(height: 10),
                 _buildGroupedSection(children: [
                   _buildSettingsTile(
                     icon: huge.HugeIcons.strokeRoundedHelpCircle,
                     title: 'About Cuqter',
                     subtitle: 'Team, version, and details',
                     onTap: () {
                       Navigator.push(
                         context,
                         MaterialPageRoute(builder: (context) => const AboutPage()),
                       );
                     },
                   ),
                 ]),
                 const SizedBox(height: 40),
                _buildSignOutButton(context, colorScheme),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'VERSION 1.3.7 • CUQTER UI',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                      letterSpacing: 1.2,
                    ),
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
                          ? NetworkImage(_profilepic) as ImageProvider
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

  Widget _buildAppearanceTile(ThemeProvider themeProvider, ColorScheme colorScheme) {
    String themeText;
    List<List<dynamic>> themeIcon;
    switch (themeProvider.themeMode) {
      case ThemeMode.dark:
        themeText = 'On';
        themeIcon = huge.HugeIcons.strokeRoundedMoon02;
        break;
      case ThemeMode.light:
        themeText = 'Off';
        themeIcon = huge.HugeIcons.strokeRoundedSun02;
        break;
      case ThemeMode.system:
        themeText = 'System';
        themeIcon = huge.HugeIcons.strokeRoundedSettings02;
        break;
    }

    return _buildSettingsTile(
      icon: themeIcon,
      title: 'Dark Mode',
      subtitle: themeText,
      iconColor: colorScheme.primary,
      onTap: () => _showThemePicker(themeProvider, colorScheme),
    );
  }

  void _showThemePicker(ThemeProvider themeProvider, ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
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
            const Text(
              'Appearance',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Customize how the interface looks and feels on your device.',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _buildThemeOption(
                    sheetContext,
                    themeProvider, 
                    ThemeMode.light, 
                    'Off', 
                    'Classic light theme', 
                    huge.HugeIcons.strokeRoundedSun02,
                  ),
                  const SizedBox(height: 8),
                  _buildThemeOption(
                    sheetContext,
                    themeProvider, 
                    ThemeMode.dark, 
                    'On', 
                    'Easy on the eyes', 
                    huge.HugeIcons.strokeRoundedMoon02,
                  ),
                  const SizedBox(height: 8),
                  _buildThemeOption(
                    sheetContext,
                    themeProvider, 
                    ThemeMode.system, 
                    'Use System', 
                    'Sync with device settings', 
                    huge.HugeIcons.strokeRoundedSettings02,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext sheetContext, ThemeProvider themeProvider, ThemeMode mode, String title, String subtitle, List<List<dynamic>> icon) {
    bool isSelected = themeProvider.themeMode == mode;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        Navigator.pop(sheetContext);
        themeProvider.setThemeMode(mode);
      },
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Selection Indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 4,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                ),
              ),
              const SizedBox(width: 12),
              // Icon
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: huge.HugeIcon(icon: icon, size: 24, color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Radio
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: isSelected 
                    ? Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
                ),
              ),
            ],
          ),
        ),
      ),
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

