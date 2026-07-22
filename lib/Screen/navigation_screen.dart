import 'package:cuqter/Screen/profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cuqter/services/update_service.dart';
import 'package:cuqter/services/notification_service.dart';
import 'package:cuqter/widgets/update_dialog.dart';
import 'package:cuqter/Screen/calls_history_page.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cuqter/Screen/homepage.dart';
import 'package:cuqter/Screen/incoming_call_screen.dart';
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
  // ignore: cancel_subscriptions
  var _incomingCallSubscription;
  String? _currentRingingRoomId;
  bool _isShowingIncomingCall = false;

  Stream<DocumentSnapshot>? _currentUserStream;

  List<Widget> get _screens => [
    const Homepage(),
    CallsHistoryPage(isActive: _selectedIndex == 1),
    const ProfileScreen(),
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
      _currentUserStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots();
      setupWebLifecycle(currentUser.uid);
      _listenForIncomingCalls(currentUser.uid);
    }
    
    _setUserStatus(true);
  }

  void _listenForIncomingCalls(String uid) {
    _incomingCallSubscription = FirebaseDatabase.instance
        .ref('incoming_calls/$uid')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final roomId = data['roomId'] as String?;
        final callerName = data['callerName'] as String? ?? 'Unknown';
        final callerId = data['callerId'] as String? ?? '';
        final isVideoCall = data['isVideo'] as bool? ?? false;

        // Guard: skip if this room is already being shown or ringing
        if (_isShowingIncomingCall && _currentRingingRoomId == roomId) return;

        _currentRingingRoomId = roomId;
        _isShowingIncomingCall = true;

        NotificationService.showIncomingCallNotification(
          callerName: callerName,
          roomId: roomId ?? '',
          callerId: callerId,
          isVideoCall: isVideoCall,
        );

        // Push incoming call screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IncomingCallScreen(
                roomId: roomId ?? '',
                callerName: callerName,
                callerId: callerId,
                isVideoCall: isVideoCall,
              ),
            ),
          ).whenComplete(() {
            // Reset flag once the incoming call screen is dismissed
            _isShowingIncomingCall = false;
            if (_currentRingingRoomId == roomId) {
              _currentRingingRoomId = null;
            }
          });
        }
      } else {
        _isShowingIncomingCall = false;
        if (_currentRingingRoomId != null) {
          NotificationService.cancelCallNotification(_currentRingingRoomId!);
          _currentRingingRoomId = null;
        }
      }
    });
  }

  Future<void> _checkForUpdate() async {
    final info = await UpdateService.checkForUpdate();
    if (info != null && mounted) {
      await UpdateDialog.show(context, info);
    }
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  navigationBarTheme: const NavigationBarThemeData(
                    indicatorColor: Colors.transparent,
                  ),
                ),
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

                  // CALLS
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: AnimatedScale(
                        scale: _selectedIndex == 1 ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedCall,
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
                          icon: huge.HugeIcons.strokeRoundedCalling,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      ),
                    ),
                    label: 'CALLS',
                  ),

                  // PROFILE
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: AnimatedScale(
                        scale: _selectedIndex == 2 ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: _currentUserStream,
                          builder: (context, snapshot) {
                            String profilePic = '';
                            if (snapshot.hasData && snapshot.data!.exists) {
                              var data = snapshot.data!.data() as Map<String, dynamic>?;
                              if (data != null) profilePic = data['profilepic'] ?? '';
                            }
                            return CircleAvatar(
                              radius: 12,
                              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                              backgroundImage: profilePic.isNotEmpty
                                  ? (profilePic.startsWith('http')
                                      ? CachedNetworkImageProvider(profilePic)
                                      : AssetImage(profilePic) as ImageProvider)
                                  : null,
                              child: profilePic.isEmpty
                                  ? Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: _selectedIndex == 2 
                                        ? colorScheme.primary 
                                        : colorScheme.onSurface.withValues(alpha: 0.4),
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                    ),
                    activeIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: AnimatedScale(
                        scale: _selectedIndex == 2 ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: _currentUserStream,
                          builder: (context, snapshot) {
                            String profilePic = '';
                            if (snapshot.hasData && snapshot.data!.exists) {
                              var data = snapshot.data!.data() as Map<String, dynamic>?;
                              if (data != null) profilePic = data['profilepic'] ?? '';
                            }
                            return Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                                backgroundImage: profilePic.isNotEmpty
                                    ? (profilePic.startsWith('http')
                                        ? CachedNetworkImageProvider(profilePic)
                                        : AssetImage(profilePic) as ImageProvider)
                                    : null,
                                child: profilePic.isEmpty
                                    ? Icon(Icons.person, size: 16, color: colorScheme.primary)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    label: 'PROFILE',
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
