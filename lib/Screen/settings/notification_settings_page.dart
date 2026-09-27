import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _messageNotifications = true;
  bool _callNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _previewMessage = true;
  int _historyDuration = 0; // 0 means forever
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _messageNotifications = prefs.getBool('notif_messages') ?? true;
        _callNotifications = prefs.getBool('notif_calls') ?? true;
        _soundEnabled = prefs.getBool('notif_sound') ?? true;
        _vibrationEnabled = prefs.getBool('notif_vibration') ?? true;
        _previewMessage = prefs.getBool('notif_preview') ?? true;
        _historyDuration = prefs.getInt('notif_history_duration') ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _updateIntPref(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<void> _deleteOldNotifications(int days) async {
    if (days == 0) return; // 0 means forever
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final threshold = DateTime.now().subtract(Duration(days: days));
    final thresholdTimestamp = Timestamp.fromDate(threshold);
    
    try {
      final notifsRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc(currentUser.uid)
          .collection('userNotifications');
          
      final querySnapshot = await notifsRef
          .where('timestamp', isLessThan: thresholdTimestamp)
          .get();
          
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      if (querySnapshot.docs.isNotEmpty) {
        await batch.commit();
        debugPrint('Deleted ${querySnapshot.docs.length} old notifications');
      }
    } catch (e) {
      debugPrint('Error deleting old notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
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
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('MESSAGES & CALLS'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildSwitchTile(
                    title: 'Message Notifications',
                    subtitle: 'Show alerts for incoming chat messages',
                    icon: huge.HugeIcons.strokeRoundedBubbleChat,
                    value: _messageNotifications,
                    onChanged: (val) {
                      setState(() => _messageNotifications = val);
                      _updatePref('notif_messages', val);
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSwitchTile(
                    title: 'Call Notifications',
                    subtitle: 'Show alerts for incoming voice & video calls',
                    icon: huge.HugeIcons.strokeRoundedCall02,
                    value: _callNotifications,
                    onChanged: (val) {
                      setState(() => _callNotifications = val);
                      _updatePref('notif_calls', val);
                    },
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionHeader('SOUND & ALERTS'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildSwitchTile(
                    title: 'In-App Sound',
                    subtitle: 'Play sounds for sent and received messages',
                    icon: huge.HugeIcons.strokeRoundedNotification01,
                    value: _soundEnabled,
                    onChanged: (val) {
                      setState(() => _soundEnabled = val);
                      _updatePref('notif_sound', val);
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSwitchTile(
                    title: 'Vibration',
                    subtitle: 'Vibrate on notifications and incoming calls',
                    icon: huge.HugeIcons.strokeRoundedSmartPhone01,
                    value: _vibrationEnabled,
                    onChanged: (val) {
                      setState(() => _vibrationEnabled = val);
                      _updatePref('notif_vibration', val);
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSwitchTile(
                    title: 'Message Preview',
                    subtitle:
                        'Show message content in push notification popups',
                    icon: huge.HugeIcons.strokeRoundedEye,
                    value: _previewMessage,
                    onChanged: (val) {
                      setState(() => _previewMessage = val);
                      _updatePref('notif_preview', val);
                    },
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionHeader('HISTORY & DATA'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildDurationTile(),
                ]),
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
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required List<List<dynamic>> icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: colorScheme.primary,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: huge.HugeIcon(icon: icon, size: 20, color: colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildDurationTile() {
    final colorScheme = Theme.of(context).colorScheme;
    String durationText = _historyDuration == 0 ? 'Forever' : '$_historyDuration Days';
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: huge.HugeIcon(
          icon: huge.HugeIcons.strokeRoundedClock01,
          size: 20,
          color: colorScheme.primary,
        ),
      ),
      title: const Text('Keep Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        'Delete history older than selected duration',
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            durationText,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios, size: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
        ],
      ),
      onTap: () {
        _showDurationSelectionDialog();
      },
    );
  }

  void _showDurationSelectionDialog() {
    final options = [0, 30, 15, 10];
    final labels = ['Forever', '30 Days', '15 Days', '10 Days'];
    
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Keep Notifications For', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(options.length, (index) {
              final val = options[index];
              return RadioListTile<int>(
                title: Text(labels[index]),
                value: val,
                groupValue: _historyDuration,
                activeColor: colorScheme.primary,
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    setState(() => _historyDuration = newValue);
                    _updateIntPref('notif_history_duration', newValue);
                    _deleteOldNotifications(newValue);
                    Navigator.pop(context);
                  }
                },
              );
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
          ],
        );
      },
    );
  }
}
