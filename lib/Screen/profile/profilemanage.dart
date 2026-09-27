import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuqter/Screen/settings/blocked_contacts_page.dart';

class ProfileManage extends StatefulWidget {
  const ProfileManage({super.key});

  @override
  State<ProfileManage> createState() => _ProfileManageState();
}

class _ProfileManageState extends State<ProfileManage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Privacy Settings State
  String _profilePhotoPrivacy = 'Everyone';
  String _lastSeenPrivacy = 'Everyone';
  String _aboutPrivacy = 'Everyone';
  String _statusPrivacy = 'My Contacts';

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _profilePhotoPrivacy =
              prefs.getString('privacy_profile_pic') ?? 'Everyone';
          _lastSeenPrivacy = prefs.getString('privacy_last_seen') ?? 'Everyone';
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
          .update({key: value})
          .catchError((_) {});
    }
  }

  void _showVisibilityPicker(
    String title,
    String prefKey,
    String currentValue,
    ValueChanged<String> onSelected,
  ) {
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
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...options.map((opt) {
                final isSelected = opt == currentValue;
                return ListTile(
                  title: Text(
                    opt,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
                // Section 1: PRIVACY & VISIBILITY
                _buildSectionHeader('PRIVACY & VISIBILITY'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildOptionTile(
                    title: 'Profile Photo',
                    subtitle: _profilePhotoPrivacy,
                    icon: huge.HugeIcons.strokeRoundedUser,
                    onTap: () {
                      _showVisibilityPicker(
                        'Profile Photo Visibility',
                        'privacy_profile_pic',
                        _profilePhotoPrivacy,
                        (val) {
                          setState(() => _profilePhotoPrivacy = val);
                        },
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildOptionTile(
                    title: 'Last Seen & Online',
                    subtitle: _lastSeenPrivacy,
                    icon: huge.HugeIcons.strokeRoundedClock01,
                    onTap: () {
                      _showVisibilityPicker(
                        'Last Seen & Online',
                        'privacy_last_seen',
                        _lastSeenPrivacy,
                        (val) {
                          setState(() => _lastSeenPrivacy = val);
                        },
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildOptionTile(
                    title: 'About / Bio',
                    subtitle: _aboutPrivacy,
                    icon: huge.HugeIcons.strokeRoundedInformationCircle,
                    onTap: () {
                      _showVisibilityPicker(
                        'About Visibility',
                        'privacy_about',
                        _aboutPrivacy,
                        (val) {
                          setState(() => _aboutPrivacy = val);
                        },
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildOptionTile(
                    title: 'Status Updates',
                    subtitle: _statusPrivacy,
                    icon: huge.HugeIcons.strokeRoundedView,
                    onTap: () {
                      _showVisibilityPicker(
                        'Status Updates Visibility',
                        'privacy_status',
                        _statusPrivacy,
                        (val) {
                          setState(() => _statusPrivacy = val);
                        },
                      );
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
    return Material(
      color: colorScheme.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Column(children: children),
      ),
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
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
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
