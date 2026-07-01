import 'package:cuqter/Screen/chatai.dart';
import 'package:cuqter/services/update_service.dart';
import 'package:cuqter/services/notification_service.dart';
import 'package:cuqter/widgets/update_dialog.dart';
import 'package:cuqter/widgets/calls_coming_soon_page.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cuqter/Screen/homepage.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cuqter/services/web_lifecycle.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  bool _isProgrammaticChange = false;
  late final AppLifecycleListener _lifecycleListener;

  List<Widget> get _screens => [
    const Homepage(),
    const AIChatScreen(),
    CallsComingSoonPage(isActive: _selectedIndex == 2),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    
    // Initialize push notification service
    NotificationService().initialize();
    
    // Check for updates after the first frame so context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());

    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onStateChanged,
      onExitRequested: () async {
        await _setUserStatus(false);
        return AppExitResponse.exit;
      },
    );
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setupWebLifecycle(currentUser.uid);
    }
    
    _setUserStatus(true);
  }

  Future<void> _checkForUpdate() async {
    final info = await UpdateService.checkForUpdate();
    if (info != null && mounted) {
      await UpdateDialog.show(context, info);
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _setUserStatus(false);
    _pageController.dispose();
    super.dispose();
  }

  void _onStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserStatus(true);
    } else {
      _setUserStatus(false);
    }
  }

  Future<void> _setUserStatus(bool isOnline) async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    if (auth.currentUser != null) {
      await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .update({
            'isOnline': isOnline,
            'lastSeen': FieldValue.serverTimestamp(),
          })
          .catchError((e) {
            // Handle error conceptually
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: false,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          if (_isProgrammaticChange) {
            if (index == _selectedIndex) {
              setState(() => _isProgrammaticChange = false);
            }
            return;
          }
          if (_selectedIndex != index) {
            setState(() => _selectedIndex = index);
          }
        },
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 25),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: colorScheme.onSurface.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.08
                      : 0.03,
                ),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.4
                        : 0.12,
                  ),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.2
                        : 0.06,
                  ),
                  blurRadius: 10,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) {
                  if (_selectedIndex == index) return;
                  setState(() {
                    _selectedIndex = index;
                    _isProgrammaticChange = true;
                  });
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: colorScheme.primary,
                unselectedItemColor:
                    colorScheme.onSurface.withValues(alpha: 0.4),
                showUnselectedLabels: true,
                selectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: colorScheme.primary,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                  letterSpacing: 0.5,
                ),
                items: [
                  // CHATS
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: AnimatedScale(
                        scale: _selectedIndex == 0 ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedChat01,
                          color: _selectedIndex == 0
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.4),
                          size: 22,
                        ),
                      ),
                    ),
                    activeIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: AnimatedScale(
                        scale: _selectedIndex == 0 ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedBubbleChat,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      ),
                    ),
                    label: 'CHATS',
                  ),

                  // AI BOT
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: AnimatedScale(
                        scale: _selectedIndex == 1 ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedAiBrain01,
                          color: _selectedIndex == 1
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.4),
                          size: 22,
                        ),
                      ),
                    ),
                    activeIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: AnimatedScale(
                        scale: _selectedIndex == 1 ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedAiBrain03,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      ),
                    ),
                    label: 'AI BOT',
                  ),

                  // CALLS — Coming Soon
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: AnimatedScale(
                        scale: _selectedIndex == 2 ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedCall,
                          color: _selectedIndex == 2
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.4),
                          size: 22,
                        ),
                      ),
                    ),
                    activeIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: AnimatedScale(
                        scale: _selectedIndex == 2 ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedCalling,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      ),
                    ),
                    label: 'CALLS',
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
