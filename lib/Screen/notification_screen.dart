import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cuqter/Screen/userprofile.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else {
      return '';
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = _auth.currentUser;

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
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: currentUser == null
          ? const Center(child: Text("Not logged in"))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('notifications')
                  .where('receiverId', isEqualTo: currentUser.uid)
                  .snapshots(),
              builder: (context, notifSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('friend_requests')
                      .where('receiverId', isEqualTo: currentUser.uid)
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, freqSnapshot) {
                    if (notifSnapshot.connectionState == ConnectionState.waiting &&
                        freqSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Map notifications by unique key to combine both collections safely
                    final Map<String, Map<String, dynamic>> combinedNotifications = {};

                    // 1. Process notifications collection
                    if (notifSnapshot.hasData) {
                      for (var doc in notifSnapshot.data!.docs) {
                        var data = Map<String, dynamic>.from(doc.data() as Map);
                        data['docId'] = doc.id;
                        data['source'] = 'notifications';
                        combinedNotifications[doc.id] = data;
                      }
                    }

                    // 2. Process friend_requests collection (legacy / fallback support)
                    if (freqSnapshot.hasData) {
                      for (var doc in freqSnapshot.data!.docs) {
                        var data = Map<String, dynamic>.from(doc.data() as Map);
                        String notifKey = 'friend_request_${doc.id}';
                        if (!combinedNotifications.containsKey(notifKey)) {
                          combinedNotifications[notifKey] = {
                            'docId': doc.id,
                            'notificationId': notifKey,
                            'type': 'friend_request',
                            'requestId': doc.id,
                            'senderId': data['senderId'] ?? '',
                            'receiverId': data['receiverId'] ?? currentUser.uid,
                            'senderName': data['senderName'] ?? 'Someone',
                            'senderProfilePic': data['senderProfilePic'] ?? '',
                            'title': 'Friend Request',
                            'body': '${data['senderName'] ?? 'Someone'} sent you a friend request',
                            'timestamp': data['timestamp'],
                            'source': 'friend_requests',
                          };
                        }
                      }
                    }

                    if (combinedNotifications.isEmpty) {
                      return Center(
                        child: Text(
                          'No new notifications',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      );
                    }

                    // Sort notifications by timestamp descending
                    final items = combinedNotifications.values.toList();
                    items.sort((a, b) {
                      final tA = a['timestamp'];
                      final tB = b['timestamp'];
                      if (tA == null && tB == null) return 0;
                      if (tA == null) return 1;
                      if (tB == null) return -1;
                      final dA = tA is Timestamp ? tA.toDate() : (tA as DateTime);
                      final dB = tB is Timestamp ? tB.toDate() : (tB as DateTime);
                      return dB.compareTo(dA);
                    });

                    final friendRequests = items.where((i) => i['type'] == 'friend_request').toList();
                    final statusLikes = items.where((i) => i['type'] == 'status_like').toList();
                    final otherNotifs = items.where((i) => i['type'] != 'friend_request' && i['type'] != 'status_like').toList();

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (friendRequests.isNotEmpty) ...[
                            _buildSectionHeader('Friend Requests', colorScheme),
                            const SizedBox(height: 12),
                            _buildNotificationCard(
                              context,
                              notifications: friendRequests.map((item) {
                                return _buildFriendRequestItem(
                                  context,
                                  item: item,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (statusLikes.isNotEmpty) ...[
                            _buildSectionHeader('Status Likes', colorScheme),
                            const SizedBox(height: 12),
                            _buildNotificationCard(
                              context,
                              notifications: statusLikes.map((item) {
                                return _buildStatusLikeItem(
                                  context,
                                  item: item,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (otherNotifs.isNotEmpty) ...[
                            _buildSectionHeader('Other Activity', colorScheme),
                            const SizedBox(height: 12),
                            _buildNotificationCard(
                              context,
                              notifications: otherNotifs.map((item) {
                                return _buildGenericItem(
                                  context,
                                  item: item,
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context, {
    required List<Widget> notifications,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(children: notifications),
    );
  }

  Widget _buildFriendRequestItem(
    BuildContext context, {
    required Map<String, dynamic> item,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final senderId = item['senderId'] ?? '';
    final name = item['senderName'] ?? 'Someone';
    final imageUrl = item['senderProfilePic'] ?? '';
    final requestId = item['requestId'] ?? item['docId'] ?? '';
    final notifDocId = item['source'] == 'notifications' ? item['docId'] : 'friend_request_$requestId';

    return InkWell(
      onTap: () => _navigateToProfile(senderId, name, imageUrl),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: imageUrl.isNotEmpty
                  ? CachedNetworkImageProvider(imageUrl) as ImageProvider
                  : null,
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: imageUrl.isEmpty
                  ? Icon(Icons.person, color: colorScheme.onSurfaceVariant)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sent you a friend request',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (item['timestamp'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatTimestamp(item['timestamp']),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                _buildActionButton(
                  context,
                  icon: huge.HugeIcons.strokeRoundedCancel01,
                  color: colorScheme.error,
                  onTap: () async {
                    // Delete from friend_requests
                    await _firestore.collection('friend_requests').doc(requestId).delete().catchError((_) {});
                    // Delete from notifications
                    await _firestore.collection('notifications').doc(notifDocId).delete().catchError((_) {});
                  },
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  context,
                  icon: huge.HugeIcons.strokeRoundedTick01,
                  color: colorScheme.primary,
                  onTap: () async {
                    final currentUserId = _auth.currentUser?.uid;
                    if (currentUserId == null) return;

                    // Delete request and notification
                    await _firestore.collection('friend_requests').doc(requestId).delete().catchError((_) {});
                    await _firestore.collection('notifications').doc(notifDocId).delete().catchError((_) {});

                    // Add to contacts
                    await _firestore.collection('users').doc(currentUserId).update({
                      'contacts': FieldValue.arrayUnion([senderId]),
                    });
                    await _firestore.collection('users').doc(senderId).update({
                      'contacts': FieldValue.arrayUnion([currentUserId]),
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLikeItem(
    BuildContext context, {
    required Map<String, dynamic> item,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final senderId = item['senderId'] ?? '';
    final name = item['senderName'] ?? 'Someone';
    final imageUrl = item['senderProfilePic'] ?? '';
    final docId = item['docId'] ?? '';

    return InkWell(
      onTap: () => _navigateToProfile(senderId, name, imageUrl),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: imageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(imageUrl) as ImageProvider
                      : null,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  child: imageUrl.isEmpty
                      ? huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedUser, color: colorScheme.onSurfaceVariant, size: 22)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedFavourite, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Liked your status',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (item['timestamp'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatTimestamp(item['timestamp']),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _buildActionButton(
              context,
              icon: huge.HugeIcons.strokeRoundedDelete02,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              onTap: () async {
                if (docId.isNotEmpty) {
                  await _firestore.collection('notifications').doc(docId).delete();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericItem(
    BuildContext context, {
    required Map<String, dynamic> item,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final senderId = item['senderId'] ?? '';
    final name = item['senderName'] ?? item['title'] ?? 'Notification';
    final body = item['body'] ?? '';
    final imageUrl = item['senderProfilePic'] ?? '';
    final docId = item['docId'] ?? '';

    return InkWell(
      onTap: () {
        if (senderId.isNotEmpty) {
          _navigateToProfile(senderId, name, imageUrl);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: imageUrl.isNotEmpty
                  ? CachedNetworkImageProvider(imageUrl) as ImageProvider
                  : null,
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: imageUrl.isEmpty
                  ? huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedNotification01, color: colorScheme.onSurfaceVariant, size: 22)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  if (item['timestamp'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatTimestamp(item['timestamp']),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _buildActionButton(
              context,
              icon: huge.HugeIcons.strokeRoundedDelete02,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              onTap: () async {
                if (docId.isNotEmpty) {
                  await _firestore.collection('notifications').doc(docId).delete();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProfile(String senderId, String fallbackName, String fallbackPic) async {
    try {
      final userDoc = await _firestore.collection('users').doc(senderId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfilePage(
                userId: senderId,
                name: userData['name'] ?? fallbackName,
                username: userData['username'] ?? '',
                bio: userData['bio'] ?? '',
                profilepic: userData['profilepic'] ?? fallbackPic,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error navigating to user profile: $e');
    }
  }

  Widget _buildActionButton(
    BuildContext context, {
    required dynamic icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: huge.HugeIcon(icon: icon, color: color, size: 20),
      ),
    );
  }
}
