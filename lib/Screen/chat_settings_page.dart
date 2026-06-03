import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import '../widgets/chat_message_text.dart';

class ChatSettingsPage extends StatefulWidget {
  const ChatSettingsPage({super.key});

  @override
  State<ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends State<ChatSettingsPage> {
  int _wallpaperIndex = 0;
  bool _enterIsSend = false;
  bool _saveToGallery = false;
  double _fontSize = 20.0;
  bool _isLoading = true;

  final List<Color> _wallpapers = [
    Colors.white,
    const Color(0xFFFEF3C7), // Amber 50
    const Color(0xFFEFF6FF), // Blue 50
    const Color(0xFFF0FDF4), // Green 50
    const Color(0xFFFAF5FF), // Purple 50
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _wallpaperIndex = prefs.getInt('global_wallpaper_index') ?? 0;
        _enterIsSend = prefs.getBool('chat_enter_is_send') ?? false;
        _saveToGallery = prefs.getBool('chat_save_to_gallery') ?? false;
        _fontSize = prefs.getDouble('chat_font_size') ?? 20.0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }

  void _clearAllHistories() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear all chat histories?'),
          content: Text(
            'This will clear all local cached files and settings. Your messages on the server will not be deleted.',
            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.8)),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat histories cleared'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Clear All',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Chat Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 20),
                _buildSectionLabel('DEFAULT CHAT WALLPAPER'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose a default background for your conversations:',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _wallpapers.length,
                          itemBuilder: (context, index) {
                            bool isSelected = _wallpaperIndex == index;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _wallpaperIndex = index;
                                });
                                _savePreference('global_wallpaper_index', index);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 60,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: _wallpapers[index],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.1),
                                    width: isSelected ? 3 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: colorScheme.primary.withValues(alpha: 0.2),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? Icon(Icons.check_rounded, color: colorScheme.primary, size: 24)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _buildSectionLabel('TEXT SIZE'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: _fontSize, end: _fontSize),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedSize, child) {
                          return ChatMessageText(
                            text: 'This is a preview of your chat message size.',
                            baseStyle: TextStyle(
                              fontSize: animatedSize,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            linkColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.blue[300]!
                                : Colors.blue[800]!,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Now',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(left: 4.0),
                                  child: Icon(
                                    Icons.done_all,
                                    size: 14,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Chat Font Size',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${_fontSize.toInt()} px',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('A', style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.5))),
                          Expanded(
                            child: Slider(
                              value: _fontSize,
                              min: 12.0,
                              max: 30.0,
                              divisions: 18,
                              label: '${_fontSize.toInt()}',
                              activeColor: colorScheme.primary,
                              onChanged: (val) {
                                setState(() {
                                  _fontSize = val;
                                });
                                _savePreference('chat_font_size', val);
                              },
                            ),
                          ),
                          Text('A', style: TextStyle(fontSize: 24, color: colorScheme.onSurface.withValues(alpha: 0.8), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _buildSectionLabel('PREFERENCES'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        icon: huge.HugeIcons.strokeRoundedSent,
                        title: 'Enter is Send',
                        subtitle: 'Keyboard enter key will send messages',
                        value: _enterIsSend,
                        onChanged: (val) {
                          setState(() => _enterIsSend = val);
                          _savePreference('chat_enter_is_send', val);
                        },
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildSwitchTile(
                        icon: huge.HugeIcons.strokeRoundedDownload01,
                        title: 'Save to Gallery',
                        subtitle: 'Automatically save media files to your storage',
                        value: _saveToGallery,
                        onChanged: (val) {
                          setState(() => _saveToGallery = val);
                          _savePreference('chat_save_to_gallery', val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _buildSectionLabel('DANGER ZONE'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
                  ),
                  child: ListTile(
                    onTap: _clearAllHistories,
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
                      'Clear Chat Histories',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.error,
                      ),
                    ),
                    subtitle: Text(
                      'Clear all conversation logs on this device',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colorScheme.error.withValues(alpha: 0.6)),
                  ),
                ),
                const SizedBox(height: 40),
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
          color: colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: colorScheme.primary,
      ),
    );
  }
}
