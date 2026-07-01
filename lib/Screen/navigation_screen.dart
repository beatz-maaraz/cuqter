import 'package:cuqter/Screen/chatai.dart';
import 'package:cuqter/services/update_service.dart';
import 'package:cuqter/services/notification_service.dart';
import 'package:cuqter/widgets/update_dialog.dart';
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
    _CallsComingSoonPage(isActive: _selectedIndex == 2),
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

// ─────────────────────────────────────────────────────────────────────────────
// Calls Coming Soon Page
// ─────────────────────────────────────────────────────────────────────────────
class _CallsComingSoonPage extends StatefulWidget {
  final bool isActive;
  const _CallsComingSoonPage({required this.isActive});

  @override
  State<_CallsComingSoonPage> createState() => _CallsComingSoonPageState();
}

class _CallsComingSoonPageState extends State<_CallsComingSoonPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_CallsComingSoonPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing glowing call icon
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.tertiary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary
                              .withValues(alpha: isDark ? 0.45 : 0.3),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.call_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Coming Soon pill badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.secondaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    '\u2726  COMING SOON  \u2726',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onPrimaryContainer,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Calls',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                    letterSpacing: -1.5,
                    height: 1,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  'Voice & video calls are on the way.\nWe\'re building something amazing —\nstay tuned!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    height: 1.7,
                  ),
                ),

                const SizedBox(height: 48),

                // Feature preview cards
                Row(
                  children: [
                    _FeatureCard(
                      icon: Icons.call_rounded,
                      label: 'Voice\nCalls',
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: 14),
                    _FeatureCard(
                      icon: Icons.videocam_rounded,
                      label: 'Video\nCalls',
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: 14),
                    _FeatureCard(
                      icon: Icons.group_rounded,
                      label: 'Group\nCalls',
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colorScheme.primary, size: 28),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
