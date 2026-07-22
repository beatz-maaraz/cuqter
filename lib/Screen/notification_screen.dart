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
                  .collection('friend_requests')
                  .where('receiverId', isEqualTo: currentUser.uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

                final requests = snapshot.data!.docs;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Friend Requests', colorScheme),
                      const SizedBox(height: 12),
                      _buildNotificationCard(
                        context,
                        notifications: requests.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          return _buildNotificationItem(
                            context,
                            requestId: doc.id,
                            senderId: data['senderId'] ?? '',
                            name: data['senderName'] ?? 'Someone',
                            action: 'Sent you a friend request',
                            imageUrl: data['senderProfilePic'] ?? '',
                          );
                        }).toList(),
                      ),
                    ],
                  ),
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

  Widget _buildNotificationItem(
    BuildContext context, {
    required String requestId,
    required String senderId,
    required String name,
    required String action,
    required String imageUrl,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        try {
          final userDoc = await _firestore.collection('users').doc(senderId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfilePage(
                    userId: senderId,
                    name: userData['name'] ?? name,
                    username: userData['username'] ?? '',
                    bio: userData['bio'] ?? '',
                    profilepic: userData['profilepic'] ?? imageUrl,
                  ),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Error fetching user for profile: $e');
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
                    action,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
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
                    await _firestore
                        .collection('friend_requests')
                        .doc(requestId)
                        .delete();
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

                    // Delete request
                    await _firestore
                        .collection('friend_requests')
                        .doc(requestId)
                        .delete();

                    // Add to receiver's contacts
                    await _firestore
                        .collection('users')
                        .doc(currentUserId)
                        .update({
                          'contacts': FieldValue.arrayUnion([senderId]),
                        });

                    // Add to sender's contacts
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
