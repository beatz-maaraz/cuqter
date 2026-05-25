import 'package:cuqter/Screen/chatai.dart';
import 'package:flutter/material.dart';
import 'package:cuqter/Screen/homepage.dart';
import 'package:cuqter/Screen/settings_page.dart';
import 'package:hugeicons/hugeicons.dart' as huge;

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const Homepage(),
    const AIChatScreen(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: false,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 25),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
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
                showUnselectedLabels: true,
                selectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: colorScheme.primary,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withOpacity(0.4),
                  letterSpacing: 0.5,
                ),
                items: [
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedChat01,
                        color: _selectedIndex == 0
                            ? colorScheme.primary
                            : colorScheme.onSurface.withOpacity(0.4),
                        size: 24,
                      ),
                    ),
                    activeIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedBubbleChat,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    label: "CHATS",
                  ),
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedAiBrain01,
                        color: _selectedIndex == 1
                            ? colorScheme.primary
                            : colorScheme.onSurface.withOpacity(0.4),
                        size: 24,
                      ),
                    ),
                    activeIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedAiBrain03,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    label: "AI BOT",
                  ),
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedSettings01,
                        color: _selectedIndex == 2
                            ? colorScheme.primary
                            : colorScheme.onSurface.withOpacity(0.4),
                        size: 24,
                      ),
                    ),
                    activeIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedSettings02,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    label: "SETTINGS",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
