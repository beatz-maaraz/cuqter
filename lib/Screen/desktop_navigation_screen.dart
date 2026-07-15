import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cuqter/Screen/chat_screen.dart';
import 'package:cuqter/Screen/chatai.dart';
import 'package:cuqter/Screen/create_status_screen.dart';
import 'package:cuqter/Screen/homepage.dart';
import 'package:cuqter/Screen/profile_screen.dart';
import 'package:cuqter/Screen/status_view_screen.dart';
import 'package:cuqter/Screen/calls_history_page.dart';
import 'package:cuqter/modules/status.dart';
import 'package:cuqter/services/status_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cuqter/Screen/incoming_call_screen.dart';
import 'package:cuqter/widgets/resizable_sidebar.dart';

class DesktopNavigationScreen extends StatefulWidget {
  const DesktopNavigationScreen({super.key});

  @override
  State<DesktopNavigationScreen> createState() => _DesktopNavigationScreenState();
}

class _DesktopNavigationScreenState extends State<DesktopNavigationScreen> {
  int _selectedIndex = 0;
  String? _selectedUserId;
  String? _selectedUserName;

  final StatusService _statusService = StatusService();
  Stream<List<Status>>? _statusesStream;
  // ignore: cancel_subscriptions
  var _incomingCallSubscription;
  String? _currentRingingRoomId;
  bool _isShowingIncomingCall = false;

  late final Stream<DocumentSnapshot> _currentUserStream = FirebaseFirestore
      .instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser?.uid)
      .snapshots();

  @override
  void initState() {
    super.initState();
    _statusesStream = _statusService.getActiveStatuses();
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _listenForIncomingCalls(currentUser.uid);
    }
  }

  void _listenForIncomingCalls(String uid) {
    _incomingCallSubscription = FirebaseDatabase.instance
        .ref('incoming_calls/$uid')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final roomId = data['roomId'] as String? ?? '';
        final callerName = data['callerName'] as String? ?? 'Unknown';
        final callerId = data['callerId'] as String? ?? '';
        final isVideoCall = data['isVideo'] as bool? ?? false;

        // Guard: skip if this room is already being shown
        if (_isShowingIncomingCall && _currentRingingRoomId == roomId) return;

        _currentRingingRoomId = roomId;
        _isShowingIncomingCall = true;

        // Push incoming call screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IncomingCallScreen(
                roomId: roomId,
                callerName: callerName,
                callerId: callerId,
                isVideoCall: isVideoCall,
              ),
            ),
          ).whenComplete(() {
            _isShowingIncomingCall = false;
            if (_currentRingingRoomId == roomId) _currentRingingRoomId = null;
          });
        }
      } else {
        _isShowingIncomingCall = false;
        _currentRingingRoomId = null;
      }
    });
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest, // Slightly darker background to make panels pop
      body: Row(
        children: [
          // Pane 1: Navigation Rail
          _buildNavigationRail(context, colorScheme),

          // Pane 2 & 3: Content based on selected tab
          Expanded(
            child: _buildMainContent(context, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // FAB
          SizedBox(
            width: 46,
            height: 46,
            child: FloatingActionButton(
              heroTag: 'desktop_fab',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateStatusScreen()));
              },
              backgroundColor: colorScheme.primary,
              shape: const CircleBorder(),
              child: Icon(Icons.add, color: colorScheme.onPrimary, size: 24),
            ),
          ),
          const SizedBox(height: 32),
          // Navigation Items
          _buildNavItem(
            icon: huge.HugeIcons.strokeRoundedChat01,
            activeIcon: huge.HugeIcons.strokeRoundedBubbleChat,
            label: 'CHATS',
            index: 0,
            colorScheme: colorScheme,
          ),
          _buildNavItem(
            icon: huge.HugeIcons.strokeRoundedAiBrain01,
            activeIcon: huge.HugeIcons.strokeRoundedAiBrain03,
            label: 'AI BOT',
            index: 1,
            colorScheme: colorScheme,
          ),
          _buildNavItem(
            icon: huge.HugeIcons.strokeRoundedCall,
            activeIcon: huge.HugeIcons.strokeRoundedCalling,
            label: 'CALLS',
            index: 2,
            colorScheme: colorScheme,
          ),
          const Spacer(),
          // Profile avatar at bottom of rail
          StreamBuilder<DocumentSnapshot>(
            stream: _currentUserStream,
            builder: (context, snapshot) {
              String profilePic = '';
              if (snapshot.hasData && snapshot.data!.exists) {
                var data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data != null) {
                  profilePic = data['profilepic'] ?? '';
                }
              }
              return GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const SizedBox(
                        width: 400,
                        height: 600,
                        child: ProfileScreen(),
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage: profilePic.isNotEmpty
                        ? (profilePic.startsWith('http')
                            ? CachedNetworkImageProvider(profilePic)
                            : AssetImage(profilePic) as ImageProvider)
                        : null,
                    child: profilePic.isEmpty
                        ? Icon(Icons.person, color: colorScheme.primary)
                        : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required dynamic icon,
    required dynamic activeIcon,
    required String label,
    required int index,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: huge.HugeIcon(
                icon: isSelected ? activeIcon : icon,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4),
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, ColorScheme colorScheme) {
    Widget child;
    if (_selectedIndex == 1) {
      child = Padding(
        key: const ValueKey('AIChatPane'),
        padding: const EdgeInsets.all(12.0),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1), width: 1),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: const AIChatScreen(isDesktop: true),
        ),
      );
    } else if (_selectedIndex == 2) {
      child = Container(
        key: const ValueKey('CallsPane'),
        child: const CallsHistoryPage(isActive: true),
      );
    } else {
      // Chats view: Pane 2 (Chat List) + Pane 3 (Active Chat) + Pane 4 (Statuses)
      child = Padding(
        key: const ValueKey('ChatsPane'),
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Pane 2: Chat List (Resizable Sidebar)
            ResizableSidebar(
              initialWidth: 320.0,
              minWidth: 260.0,
              maxWidth: 480.0,
              child: RepaintBoundary(
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1), width: 1),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Homepage(
                    isDesktop: true,
                    selectedUserId: _selectedUserId,
                    onChatSelected: (userId, userName) {
                      setState(() {
                        _selectedUserId = userId;
                        _selectedUserName = userName;
                      });
                    },
                  ),
                ),
              ),
            ),

            // Pane 3: Active Chat
            Expanded(
              flex: 7,
              child: RepaintBoundary(
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1), width: 1),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _selectedUserId != null && _selectedUserName != null
                  ? ChatScreen(
                      key: ValueKey(_selectedUserId),
                      receiverId: _selectedUserId!,
                      receiverName: _selectedUserName!,
                      isDesktop: true,
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          huge.HugeIcon(
                            icon: huge.HugeIcons.strokeRoundedBubbleChat,
                            color: colorScheme.onSurface.withValues(alpha: 0.2),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Select a chat to start messaging',
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Pane 4: Statuses
            RepaintBoundary(
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1), width: 1),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildStatusSidebar(context),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: child,
    );
  }

  Widget _buildStatusSidebar(BuildContext context) {
    return StreamBuilder<List<Status>>(
      stream: _statusesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final statuses = snapshot.data!;
        Map<String, List<Status>> groupedStatuses = {};
        for (var s in statuses) {
          groupedStatuses.putIfAbsent(s.uid, () => []).add(s);
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        String? currentUserId = currentUser?.uid;
        List<Status> myStatuses = [];
        if (currentUserId != null && groupedStatuses.containsKey(currentUserId)) {
          myStatuses = groupedStatuses[currentUserId]!;
          groupedStatuses.remove(currentUserId);
        }

        List<List<Status>> allOtherUserStatuses = groupedStatuses.values.toList();
        
        if (currentUserId != null) {
          allOtherUserStatuses.sort((a, b) {
            bool aAllViewed = a.every((s) => s.viewers.any((v) => v.uid == currentUserId));
            bool bAllViewed = b.every((s) => s.viewers.any((v) => v.uid == currentUserId));
            if (aAllViewed == bAllViewed) {
              return b.last.createdAt.compareTo(a.last.createdAt);
            }
            return aAllViewed ? 1 : -1;
          });
        }

        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Statuses',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: allOtherUserStatuses.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: _buildMyStatusAvatar(context, myStatuses),
                    );
                  }
                  List<Status> userStatuses = allOtherUserStatuses[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: _buildUserStatusAvatar(context, userStatuses, allOtherUserStatuses, index - 1),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMyStatusAvatar(BuildContext context, List<Status> myStatuses) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: currentUser != null ? FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots() : null,
      builder: (context, snapshot) {
        String profilePic = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            profilePic = data['profilepic'] ?? '';
          }
        }

        return GestureDetector(
          onTap: () {
            if (myStatuses.isNotEmpty) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => StatusViewScreen(statuses: myStatuses)));
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateStatusScreen()));
            }
          },
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: myStatuses.isNotEmpty ? colorScheme.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      backgroundImage: profilePic.isNotEmpty
                          ? (profilePic.startsWith('http')
                              ? CachedNetworkImageProvider(profilePic)
                              : AssetImage(profilePic)) as ImageProvider
                          : null,
                      child: profilePic.isEmpty
                          ? Icon(Icons.person, color: colorScheme.onSurface, size: 24)
                          : null,
                    ),
                  ),
                  if (myStatuses.isEmpty)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: colorScheme.surface, width: 2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Icon(Icons.add, size: 20, color: colorScheme.onPrimary),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text('My status', style: TextStyle(fontSize: 12, color: colorScheme.onSurface), textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserStatusAvatar(BuildContext context, List<Status> statuses, List<List<Status>> allUserStatuses, int userIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    final latestStatus = statuses.last;
    
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    bool allViewed = currentUserId != null && statuses.every((s) => s.viewers.any((v) => v.uid == currentUserId));
    Color ringColor = allViewed ? colorScheme.onSurface.withValues(alpha: 0.2) : colorScheme.primary;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => StatusViewScreen(
          groupedStatusesList: allUserStatuses,
          initialUserIndex: userIndex,
        )));
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: 2),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundImage: latestStatus.profilePic.isNotEmpty
                  ? (latestStatus.profilePic.startsWith('http')
                      ? CachedNetworkImageProvider(latestStatus.profilePic)
                      : AssetImage(latestStatus.profilePic)) as ImageProvider
                  : null,
              child: latestStatus.profilePic.isEmpty
                  ? Icon(Icons.person, color: colorScheme.onSurface, size: 24)
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            latestStatus.username.length > 8 ? '${latestStatus.username.substring(0, 8)}...' : latestStatus.username,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
