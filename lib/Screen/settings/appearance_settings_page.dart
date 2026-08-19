import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cuqter/providers/theme_provider.dart';
import 'package:cuqter/widgets/adaptive/adaptive.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  int _selectedIconIndex = 0;
  bool _isLoading = true;
  bool _demoSwitchVal = true;
  final TextEditingController _demoTextController = TextEditingController(text: 'Adaptive Text Field');

  final List<Map<String, dynamic>> _accentColors = [
    {'name': 'Violet', 'color': const Color(0xFF7C3AED)},
    {'name': 'Sky Blue', 'color': const Color(0xFF0EA5E9)},
    {'name': 'Emerald', 'color': const Color(0xFF10B981)},
    {'name': 'Coral', 'color': const Color(0xFFF43F5E)},
    {'name': 'Sunset', 'color': const Color(0xFFF97316)},
    {'name': 'Rose Pink', 'color': const Color(0xFFEC4899)},
    {'name': 'Royal Indigo', 'color': const Color(0xFF3F51B5)},
  ];

  final List<Map<String, dynamic>> _appIcons = [
    {
      'name': 'Classic Violet',
      'colors': [const Color(0xFF7C3AED), const Color(0xFFC4B5FD)],
      'textColor': Colors.white,
    },
    {
      'name': 'Stealth Midnight',
      'colors': [const Color(0xFF0F172A), const Color(0xFF1E293B)],
      'textColor': const Color(0xFFC4B5FD),
    },
    {
      'name': 'Ocean Breeze',
      'colors': [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)],
      'textColor': Colors.white,
    },
    {
      'name': 'Sunset Glow',
      'colors': [const Color(0xFFF43F5E), const Color(0xFFF97316)],
      'textColor': Colors.white,
    },
    {
      'name': 'Mint Fresh',
      'colors': [const Color(0xFF10B981), const Color(0xFF059669)],
      'textColor': Colors.white,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAppIconPreference();
  }

  @override
  void dispose() {
    _demoTextController.dispose();
    super.dispose();
  }

  Future<void> _loadAppIconPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedIconIndex = prefs.getInt('selected_app_icon_index') ?? 0;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAppIconPreference(int index) async {
    setState(() {
      _selectedIconIndex = index;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_app_icon_index', index);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Appearance',
          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: _isLoading
          ? const Center(child: AdaptiveProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                _buildLivePreview(colorScheme, themeProvider),
                const SizedBox(height: 30),
                _buildSectionLabel('DESIGN STYLE'),
                const SizedBox(height: 12),
                _buildDesignStyleSelector(themeProvider, colorScheme),
                const SizedBox(height: 30),
                _buildSectionLabel('THEME MODE'),
                const SizedBox(height: 12),
                _buildThemeSelector(themeProvider, colorScheme),
                const SizedBox(height: 30),
                _buildSectionLabel('ACCENT COLOR'),
                const SizedBox(height: 12),
                _buildAccentColorPicker(themeProvider, colorScheme),
                const SizedBox(height: 30),
                _buildSectionLabel('LIVE ADAPTIVE SHOWCASE'),
                const SizedBox(height: 12),
                _buildAdaptiveShowcase(themeProvider, colorScheme),
                const SizedBox(height: 30),
                _buildSectionLabel('APP ICON STYLE'),
                const SizedBox(height: 12),
                _buildAppIconPicker(colorScheme),
                const SizedBox(height: 30),
                _buildSectionLabel('EFFECTS'),
                const SizedBox(height: 12),
                _buildLiquidEffectToggle(themeProvider, colorScheme),
                const SizedBox(height: 20),
                _buildHomeScreenMockup(colorScheme),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: colorScheme.onSurface.withValues(alpha: 0.45),
      ),
    );
  }

  Widget _buildDesignStyleSelector(ThemeProvider themeProvider, ColorScheme colorScheme) {
    final currentStyle = themeProvider.designStyle;

    return Column(
      children: AppDesignStyle.values.map((style) {
        final isSelected = currentStyle == style;
        final primaryColor = themeProvider.primaryColor;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => themeProvider.setDesignStyle(style),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.10)
                    : colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected ? primaryColor : colorScheme.onSurface.withValues(alpha: 0.08),
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor
                          : colorScheme.onSurface.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      style.icon,
                      color: isSelected ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.7),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              style.displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor.withValues(alpha: 0.2)
                                    : colorScheme.onSurface.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                style == AppDesignStyle.material ? 'Google M3' : 'Apple iOS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? primaryColor : colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          style.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.65),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? primaryColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? primaryColor : colorScheme.onSurface.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLivePreview(ColorScheme colorScheme, ThemeProvider themeProvider) {
    final isDark = themeProvider.themeMode == ThemeMode.dark ||
        (themeProvider.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final isCupertino = themeProvider.isCupertino;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.05),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: _selectedIconIndex == 0
                        ? ClipOval(
                            child: Image.asset(
                              'assets/icon/icon.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.chat_bubble_rounded,
                                color: colorScheme.primary,
                                size: 16,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.chat_bubble_rounded,
                            color: colorScheme.primary,
                            size: 16,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live Theme & Design Preview',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Active System: ${themeProvider.designStyle.displayName}',
                    style: TextStyle(fontSize: 10, color: themeProvider.primaryColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: themeProvider.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCupertino ? Icons.apple_rounded : Icons.android_rounded,
                      size: 14,
                      color: themeProvider.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCupertino ? 'Cupertino' : 'Material 3',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Recipient Message
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(right: 40),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262626) : Colors.white,
                borderRadius: isCupertino
                    ? BorderRadius.circular(18)
                    : const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Text(
                'Switching to ${themeProvider.designStyle.shortName} mode!',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Sender Message
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(left: 40),
              decoration: BoxDecoration(
                color: themeProvider.primaryColor,
                borderRadius: isCupertino
                    ? BorderRadius.circular(18)
                    : const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                      ),
              ),
              child: const Text(
                'Awesome, the whole UI adapts instantly! 🎨✨',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveShowcase(ThemeProvider themeProvider, ColorScheme colorScheme) {
    return AdaptiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Interactive Reusable Components',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              AdaptiveProgressIndicator(radius: 10),
            ],
          ),
          const SizedBox(height: 16),
          AdaptiveTextField(
            controller: _demoTextController,
            labelText: 'Sample Text Field',
            placeholder: 'Type something...',
            prefix: Icon(Icons.edit_note_rounded, size: 20, color: themeProvider.primaryColor),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Adaptive Switch Control',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
              AdaptiveSwitch(
                value: _demoSwitchVal,
                onChanged: (val) => setState(() => _demoSwitchVal = val),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AdaptiveButton.filled(
                  onPressed: () {
                    AdaptiveDialog.show(
                      context: context,
                      title: Text('${themeProvider.designStyle.shortName} Dialog'),
                      content: Text('This dialog is rendered using native ${themeProvider.designStyle.displayName} components.'),
                      actions: [
                        AdaptiveDialogAction(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                          isDefaultAction: true,
                        ),
                      ],
                    );
                  },
                  icon: const Icon(Icons.touch_app_rounded, size: 18),
                  child: const Text('Test Dialog'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdaptiveButton.outlined(
                  onPressed: () {},
                  child: const Text('Outlined'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(ThemeProvider themeProvider, ColorScheme colorScheme) {
    return Row(
      children: [
        _buildThemeCard(
          label: 'Light',
          mode: ThemeMode.light,
          icon: huge.HugeIcons.strokeRoundedSun02,
          currentMode: themeProvider.themeMode,
          onTap: () => themeProvider.setThemeMode(ThemeMode.light),
          colorScheme: colorScheme,
        ),
        const SizedBox(width: 12),
        _buildThemeCard(
          label: 'Dark',
          mode: ThemeMode.dark,
          icon: huge.HugeIcons.strokeRoundedMoon02,
          currentMode: themeProvider.themeMode,
          onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
          colorScheme: colorScheme,
        ),
        const SizedBox(width: 12),
        _buildThemeCard(
          label: 'System',
          mode: ThemeMode.system,
          icon: huge.HugeIcons.strokeRoundedSettings02,
          currentMode: themeProvider.themeMode,
          onTap: () => themeProvider.setThemeMode(ThemeMode.system),
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _buildThemeCard({
    required String label,
    required ThemeMode mode,
    required List<List<dynamic>> icon,
    required ThemeMode currentMode,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    final isSelected = currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              huge.HugeIcon(
                icon: icon,
                color: isSelected ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.6),
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccentColorPicker(ThemeProvider themeProvider, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 14,
        children: _accentColors.map((colorInfo) {
          final color = colorInfo['color'] as Color;
          final isSelected = themeProvider.primaryColor.toARGB32() == color.toARGB32();
          return GestureDetector(
            onTap: () => themeProvider.updatePrimaryColor(color),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colorScheme.onSurface : Colors.transparent,
                  width: 3.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    )
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAppIconPicker(ColorScheme colorScheme) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _appIcons.length,
        itemBuilder: (context, index) {
          final iconData = _appIcons[index];
          final isSelected = _selectedIconIndex == index;
          final colors = iconData['colors'] as List<Color>;
          final textColor = iconData['textColor'] as Color;

          return GestureDetector(
            onTap: () => _updateAppIconPreference(index),
            child: Container(
              margin: const EdgeInsets.only(right: 14, top: 4, bottom: 4),
              width: 90,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.08),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  index == 0
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/icon/icon.png',
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: colors),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.chat_bubble_rounded, color: textColor, size: 22),
                            ),
                          ),
                        )
                      : Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: colors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.chat_bubble_rounded,
                              color: textColor,
                              size: 22,
                            ),
                          ),
                        ),
                  const SizedBox(height: 6),
                  Text(
                    iconData['name'].split(' ').last,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiquidEffectToggle(ThemeProvider themeProvider, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        title: const Text(
          'Liquid Glass Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Show floating glassmorphism blobs behind screens',
          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.water_drop_outlined,
            color: colorScheme.primary,
            size: 20,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: colorScheme.onSurface.withValues(alpha: 0.5)),
        onTap: () => _showLiquidSettingsSheet(context, themeProvider, colorScheme),
      ),
    );
  }

  void _showLiquidSettingsSheet(BuildContext context, ThemeProvider themeProvider, ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Liquid Glass Controls',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Enable Effect',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    value: themeProvider.isLiquidBackgroundEnabled,
                    onChanged: (val) {
                      setState(() {
                        themeProvider.toggleLiquidBackground(val);
                      });
                    },
                    activeColor: colorScheme.primary,
                  ),
                  const SizedBox(height: 10),
                  if (themeProvider.isLiquidBackgroundEnabled) ...[
                    Text(
                      'Transparency (Opacity)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Slider(
                      value: themeProvider.liquidOpacity,
                      min: 0.0,
                      max: 1.0,
                      activeColor: colorScheme.primary,
                      onChanged: (val) {
                        setState(() {
                          themeProvider.updateLiquidOpacity(val, save: false);
                        });
                      },
                      onChangeEnd: (val) {
                        themeProvider.updateLiquidOpacity(val, save: true);
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Edge Control (Blur Amount)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Slider(
                      value: themeProvider.liquidBlur,
                      min: 0.0,
                      max: 100.0,
                      activeColor: colorScheme.primary,
                      onChanged: (val) {
                        setState(() {
                          themeProvider.updateLiquidBlur(val, save: false);
                        });
                      },
                      onChangeEnd: (val) {
                        themeProvider.updateLiquidBlur(val, save: true);
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHomeScreenMockup(ColorScheme colorScheme) {
    final activeIcon = _appIcons[_selectedIconIndex];
    final activeColors = activeIcon['colors'] as List<Color>;
    final activeTextColor = activeIcon['textColor'] as Color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Home Screen Mockup',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 220,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500&auto=format&fit=crop&q=60',
                  ),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMockAppIcon('Camera', Colors.grey.shade800, Icons.camera_alt),
                        _buildMockAppIcon('Mail', Colors.blue.shade800, Icons.mail),
                        // Cuqter App Mock Launcher Icon
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _selectedIconIndex == 0
                                ? Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(13),
                                      boxShadow: [
                                        BoxShadow(
                                          color: activeColors.first.withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(13),
                                      child: Image.asset(
                                        'assets/icon/icon.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Icon(
                                          Icons.chat_bubble_rounded,
                                          color: activeTextColor,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: activeColors,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(13),
                                      boxShadow: [
                                        BoxShadow(
                                          color: activeColors.first.withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.chat_bubble_rounded,
                                        color: activeTextColor,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                            const SizedBox(height: 6),
                            const Text(
                              'Cuqter',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    offset: Offset(0, 1.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        _buildMockAppIcon('Photos', Colors.white, Icons.photo_library, iconColor: Colors.amber.shade700),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockAppIcon(String label, Color bgColor, IconData icon, {Color iconColor = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
