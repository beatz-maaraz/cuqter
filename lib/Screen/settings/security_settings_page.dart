import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cuqter/resources/auth_method.dart';
import 'package:cuqter/services/biometric_service.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _appLockEnabled = false;
  bool _showLastSeen = true;
  bool _showReadReceipts = true;
  bool _isLoading = true;
  bool _isSendingReset = false;
  bool _isSendingVerification = false;

  @override
  void initState() {
    super.initState();
    _loadSecurityPreferences();
  }

  Future<void> _loadSecurityPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;

      final user = _auth.currentUser;
      if (user != null) {
        // Try reloading user status in background without blocking
        user.reload().then((_) {
          if (mounted) setState(() {});
        }).catchError((e) {
          debugPrint('User reload error: $e');
        });

        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null) {
            _showLastSeen = data['showLastSeen'] ?? true;
            _showReadReceipts = data['showReadReceipts'] ?? true;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading security preferences: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    final bool authSuccess = await BiometricService.authenticate(
      reason: value
          ? 'Authenticate to enable App Lock'
          : 'Authenticate to disable App Lock',
    );

    if (!authSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication required to change App Lock'),
          ),
        );
      }
      return;
    }

    await BiometricService.setAppLockEnabled(value);
    if (mounted) {
      setState(() {
        _appLockEnabled = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'App Lock enabled' : 'App Lock disabled'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleLastSeen(bool value) async {
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() {
      _showLastSeen = value;
    });
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'showLastSeen': value,
      });
    } catch (e) {
      debugPrint('Error updating last seen setting: $e');
    }
  }

  Future<void> _toggleReadReceipts(bool value) async {
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() {
      _showReadReceipts = value;
    });
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'showReadReceipts': value,
      });
    } catch (e) {
      debugPrint('Error updating read receipts setting: $e');
    }
  }

  Future<void> _sendPasswordReset() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address associated with this account')),
      );
      return;
    }

    setState(() {
      _isSendingReset = true;
    });

    final res = await AuthMethod().resetPassword(email: user.email!);

    if (mounted) {
      setState(() {
        _isSendingReset = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res == 'success'
                ? 'Password reset link sent to ${user.email}'
                : res,
          ),
        ),
      );
    }
  }

  Future<void> _sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isSendingVerification = true;
    });

    try {
      await user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email sent to ${user.email}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send verification email: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingVerification = false;
        });
      }
    }
  }

  void _showDeleteAccountDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colorScheme.error),
            const SizedBox(width: 10),
            const Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'This action is permanent and cannot be undone. All your messages, profile data, and media will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final user = _auth.currentUser;
              if (user != null) {
                try {
                  await _firestore.collection('users').doc(user.uid).delete();
                  await user.delete();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting account: $e. Re-authentication may be required.')),
                    );
                  }
                }
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Security',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: huge.HugeIcon(
            icon: huge.HugeIcons.strokeRoundedArrowLeft01,
            color: colorScheme.onSurface,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSecurityStatusHeader(colorScheme, user),
                const SizedBox(height: 24),

                _buildSectionLabel('LOGIN & AUTHENTICATION'),
                const SizedBox(height: 8),
                _buildGroupedSection([
                  _buildListTile(
                    icon: huge.HugeIcons.strokeRoundedLockPassword,
                    title: 'Change Password',
                    subtitle: 'Send password reset link to your email',
                    trailing: _isSendingReset
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _sendPasswordReset,
                  ),
                  _buildListTile(
                    icon: huge.HugeIcons.strokeRoundedMail01,
                    title: 'Email Verification',
                    subtitle: user?.emailVerified == true
                        ? 'Email address is verified'
                        : 'Tap to send verification email',
                    trailing: user?.emailVerified == true
                        ? Icon(Icons.check_circle, color: colorScheme.primary, size: 20)
                        : (_isSendingVerification
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.error_outline, color: colorScheme.error, size: 20)),
                    onTap: user?.emailVerified == true ? null : _sendEmailVerification,
                  ),
                ]),
                const SizedBox(height: 24),

                _buildSectionLabel('PRIVACY & PROTECTION'),
                const SizedBox(height: 8),
                _buildGroupedSection([
                  _buildSwitchTile(
                    icon: huge.HugeIcons.strokeRoundedSecurityValidation,
                    title: 'App Lock',
                    subtitle: 'Require passcode/biometrics to open app',
                    value: _appLockEnabled,
                    onChanged: _toggleAppLock,
                  ),
                  _buildSwitchTile(
                    icon: huge.HugeIcons.strokeRoundedEye,
                    title: 'Show Last Seen',
                    subtitle: 'Allow contacts to see when you are active',
                    value: _showLastSeen,
                    onChanged: _toggleLastSeen,
                  ),
                  _buildSwitchTile(
                    icon: huge.HugeIcons.strokeRoundedTickDouble01,
                    title: 'Read Receipts',
                    subtitle: 'Show blue checks when messages are read',
                    value: _showReadReceipts,
                    onChanged: _toggleReadReceipts,
                  ),
                ]),
                const SizedBox(height: 24),

                _buildSectionLabel('ACCOUNT & SESSION INFO'),
                const SizedBox(height: 8),
                _buildGroupedSection([
                  _buildInfoTile(
                    icon: huge.HugeIcons.strokeRoundedUser,
                    title: 'Account Email',
                    value: user?.email ?? 'N/A',
                  ),
                  _buildInfoTile(
                    icon: huge.HugeIcons.strokeRoundedSecurityValidation,
                    title: 'Auth Provider',
                    value: user?.providerData.isNotEmpty == true
                        ? user!.providerData.map((p) => p.providerId).join(', ')
                        : 'Firebase Auth',
                  ),
                ]),
                const SizedBox(height: 32),

                _buildDangerSection(colorScheme),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSecurityStatusHeader(ColorScheme colorScheme, User? user) {
    final bool isVerified = user?.emailVerified ?? false;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isVerified ? colorScheme.primary : colorScheme.tertiary)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isVerified ? colorScheme.primary : colorScheme.tertiary)
              .withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isVerified ? colorScheme.primary : colorScheme.tertiary,
              shape: BoxShape.circle,
            ),
            child: huge.HugeIcon(
              icon: huge.HugeIcons.strokeRoundedSecurityValidation,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified ? 'Account Protected' : 'Security Attention Required',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isVerified
                      ? 'Your account email is verified and security parameters are active.'
                      : 'Verify your email address to strengthen account protection.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
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

  Widget _buildGroupedSection(List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    required List<List<dynamic>> icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: huge.HugeIcon(icon: icon, size: 20, color: colorScheme.primary),
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
      trailing: trailing ??
          huge.HugeIcon(
            icon: huge.HugeIcons.strokeRoundedArrowRight01,
            size: 20,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
    );
  }

  Widget _buildSwitchTile({
    required List<List<dynamic>> icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: huge.HugeIcon(icon: icon, size: 20, color: colorScheme.primary),
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
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: colorScheme.primary,
      ),
    );
  }

  Widget _buildInfoTile({
    required List<List<dynamic>> icon,
    required String title,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: huge.HugeIcon(icon: icon, size: 20, color: colorScheme.primary),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildDangerSection(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        onTap: _showDeleteAccountDialog,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: huge.HugeIcon(
            icon: huge.HugeIcons.strokeRoundedDelete02,
            size: 20,
            color: colorScheme.error,
          ),
        ),
        title: Text(
          'Delete Account',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.error,
          ),
        ),
        subtitle: Text(
          'Permanently erase your account and all data',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.error.withValues(alpha: 0.7),
          ),
        ),
        trailing: huge.HugeIcon(
          icon: huge.HugeIcons.strokeRoundedArrowRight01,
          size: 20,
          color: colorScheme.error,
        ),
      ),
    );
  }
}
