import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuqter/providers/theme_provider.dart';
import 'package:cuqter/resources/auth_method.dart';
import 'package:cuqter/Account/login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _name = 'User';
  String _email = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _name = doc.data()?['name'] ?? 'User';
            _email = user.email ?? '';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {},
          ),
        ],
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
                    icon: Icons.person_outline,
                    title: 'Profile',
                    subtitle: 'Manage your public identity',
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: Icons.notifications_none,
                    title: 'Notifications',
                    subtitle: 'Tone and frequency control',
                    trailing: _buildBadge(context, '3 Active'),
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: Icons.security_outlined,
                    title: 'Security',
                    subtitle: 'Authentication and privacy',
                    onTap: () {},
                  ),
                  _buildAppearanceTile(themeProvider, colorScheme),
                ]),
                const SizedBox(height: 30),
                _buildSectionLabel(context, 'SUPPORT'),
                const SizedBox(height: 10),
                 _buildGroupedSection(children: [
                  _buildSettingsTile(
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    subtitle: 'Guided solutions',
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: Icons.description_outlined,
                    title: 'Terms',
                    subtitle: 'Legal clarity',
                    onTap: () {},
                  ),
                ]),
                const SizedBox(height: 40),
                _buildSignOutButton(context, colorScheme),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'VERSION 1.0.0 • CUQTER UI',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurface.withOpacity(0.4),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer),
                ),
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
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
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
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildGroupedSection({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: Colors.blue),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
    );
  }

  Widget _buildAppearanceTile(ThemeProvider themeProvider, ColorScheme colorScheme) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
          size: 20,
          color: Colors.deepPurple,
        ),
      ),
      title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('Adjust appearance'),
      value: themeProvider.isDarkMode,
      onChanged: (value) => themeProvider.toggleTheme(value),
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
          backgroundColor: colorScheme.errorContainer.withOpacity(0.3),
          foregroundColor: colorScheme.error,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => _showSignOutDialog(context),
        icon: const Icon(Icons.logout),
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
                  color: colorScheme.errorContainer.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout, color: colorScheme.error, size: 32),
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
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
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
                    await AuthMethod().signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => const Loginpage(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(opacity: animation, child: child);
                          },
                        ),
                        (route) => false,
                      );
                    }
                  },
                  child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: colorScheme.surfaceVariant.withOpacity(0.5),
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

