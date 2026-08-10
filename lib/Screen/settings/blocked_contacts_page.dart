import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart' as huge;

class BlockedContactsPage extends StatefulWidget {
  const BlockedContactsPage({super.key});

  @override
  State<BlockedContactsPage> createState() => _BlockedContactsPageState();
}

class _BlockedContactsPageState extends State<BlockedContactsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _unblockUser(String peerId, String peerName) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(peerId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unblocked $peerName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unblocking user: $e')),
        );
      }
    }
  }

  Future<void> _blockUser(String peerId, String peerName) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(peerId)
          .set({
        'peerId': peerId,
        'blockedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Blocked $peerName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error blocking user: $e')),
        );
      }
    }
  }

  void _showAddBlockModal(
      BuildContext context, Set<String> currentlyBlockedIds) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _auth.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Block a Contact',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('users').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];
                      final eligibleUsers = docs.where((doc) {
                        final id = doc.id;
                        return id != currentUserId &&
                            !currentlyBlockedIds.contains(id);
                      }).toList();

                      if (eligibleUsers.isEmpty) {
                        return const Center(
                          child: Text('No contacts available to block'),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: eligibleUsers.length,
                        itemBuilder: (context, index) {
                          final data = eligibleUsers[index].data()
                              as Map<String, dynamic>;
                          final peerId = eligibleUsers[index].id;
                          final name = data['name'] ?? 'User';
                          final username = data['username'] ?? '';
                          final profilePic = data['profilepic'] ?? '';

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: colorScheme.primaryContainer,
                              backgroundImage: profilePic.isNotEmpty &&
                                      profilePic.startsWith('http')
                                  ? ResizeImage(
                                      CachedNetworkImageProvider(profilePic),
                                      width: 120,
                                      height: 120,
                                    )
                                  : const AssetImage(
                                          'assets/icon/default_profile.png')
                                      as ImageProvider,
                            ),
                            title: Text(
                              name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '@$username',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _blockUser(peerId, name);
                              },
                              child: const Text(
                                'Block',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _auth.currentUser?.uid;

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
          'Blocked Contacts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('blocked_users')
            .snapshots(),
        builder: (context, blockedSnapshot) {
          if (blockedSnapshot.connectionState == ConnectionState.waiting &&
              !blockedSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final blockedDocs = blockedSnapshot.data?.docs ?? [];
          final blockedIds = blockedDocs.map((d) => d.id).toSet();

          return Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: huge.HugeIcon(
                    icon: huge.HugeIcons.strokeRoundedUserAdd01,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Block a Friend or Contact',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Prevent unwanted messages and calls',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () => _showAddBlockModal(context, blockedIds),
              ),
              const Divider(height: 1),
              Expanded(
                child: blockedDocs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            huge.HugeIcon(
                              icon: huge.HugeIcons.strokeRoundedUserBlock01,
                              size: 64,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No blocked contacts',
                              style: TextStyle(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Blocked contacts will not be able to call you\nor send you messages.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collection('users').snapshots(),
                        builder: (context, usersSnapshot) {
                          final userMap = <String, Map<String, dynamic>>{};
                          if (usersSnapshot.hasData) {
                            for (var doc in usersSnapshot.data!.docs) {
                              userMap[doc.id] =
                                  doc.data() as Map<String, dynamic>;
                            }
                          }

                          return ListView.builder(
                            itemCount: blockedDocs.length,
                            itemBuilder: (context, index) {
                              final peerId = blockedDocs[index].id;
                              final userData = userMap[peerId];
                              final peerName =
                                  userData?['name'] ?? 'Blocked User';
                              final username = userData?['username'] ?? '';
                              final profilePic = userData?['profilepic'] ?? '';

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor:
                                      colorScheme.primaryContainer,
                                  backgroundImage: profilePic.isNotEmpty &&
                                          profilePic.startsWith('http')
                                      ? ResizeImage(
                                          CachedNetworkImageProvider(
                                            profilePic,
                                          ),
                                          width: 160,
                                          height: 160,
                                        )
                                      : const AssetImage(
                                              'assets/icon/default_profile.png')
                                          as ImageProvider,
                                ),
                                title: Text(
                                  peerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  username.isNotEmpty
                                      ? '@$username'
                                      : 'Blocked',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    foregroundColor: colorScheme.onSurface,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _unblockUser(peerId, peerName),
                                  child: const Text('Unblock'),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
