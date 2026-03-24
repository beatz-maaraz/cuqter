import 'package:flutter/material.dart';
import 'package:cuqter/Screen/homepage.dart';
import 'package:cuqter/Screen/profile_screen.dart';
import 'package:cuqter/Screen/settings_page.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const Homepage(),
    const Center(child: Text('Analytics', style: TextStyle(fontSize: 24))),
    const SettingsPage(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        height: 85,
        padding: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurface.withOpacity(0.4),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: [
            _buildNavItem(Icons.chat_bubble, 'CHATS', 0, colorScheme),
            _buildNavItem(Icons.group, 'GROUPS', 1, colorScheme),
            _buildNavItem(Icons.call, 'CALLS', 2, colorScheme),
            _buildNavItem(Icons.settings, 'SETTINGS', 3, colorScheme),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index, ColorScheme colorScheme) {
    bool isSelected = _selectedIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon),
      ),
      label: label,
    );
  }
}
