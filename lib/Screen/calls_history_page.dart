import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import '../widgets/full_screen_profile_pic_page.dart';
import 'call_screen.dart';
import '../services/message_service.dart';

class CallsHistoryPage extends StatefulWidget {
  final bool isActive;
  const CallsHistoryPage({super.key, required this.isActive});

  @override
  State<CallsHistoryPage> createState() => _CallsHistoryPageState();
}

class _CallsHistoryPageState extends State<CallsHistoryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MessageService _messageService = MessageService();

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();
    
    String timeStr = TimeOfDay.fromDateTime(date).format(context);
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return timeStr;
    }
    return '${DateFormat('MMM d').format(date)}, $timeStr';
  }

  void _startNewCall(BuildContext context, String peerId, String peerName, bool isVideo) {
    // When starting a new call from history, we just navigate to CallScreen as caller
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          isVideoCall: isVideo,
          receiverName: peerName,
          receiverId: peerId,
          onRoomCreated: (roomId) async {
            // Send a call message
            String chatId = peerId.compareTo(_auth.currentUser!.uid) > 0
                ? '${peerId}_${_auth.currentUser!.uid}'
                : '${_auth.currentUser!.uid}_$peerId';

            await _messageService.sendMessage(
              chatId: chatId,
              senderId: _auth.currentUser!.uid,
              receiverId: peerId,
              text: roomId,
              type: isVideo ? 'video_call' : 'voice_call',
            );

            // Log call for caller
            await _messageService.logCall(
              currentUserId: _auth.currentUser!.uid,
              peerId: peerId,
              type: isVideo ? 'video' : 'voice',
              status: 'outgoing',
              roomId: roomId,
            );

            // Log call for receiver
            await _messageService.logCall(
              currentUserId: peerId,
              peerId: _auth.currentUser!.uid,
              type: isVideo ? 'video' : 'voice',
              status: 'incoming',
              roomId: roomId,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Calls'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surface,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('call_history')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading call history'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_missed, 
                    size: 64, 
                    color: colorScheme.outline
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No calls yet',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final groupedDocs = <String, List<QueryDocumentSnapshot>>{};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            String dateLabel = 'Unknown';
            if (timestamp != null) {
              DateTime date = timestamp.toDate();
              DateTime now = DateTime.now();
              DateTime yesterday = now.subtract(const Duration(days: 1));
              if (date.year == now.year && date.month == now.month && date.day == now.day) {
                dateLabel = 'Today';
              } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
                dateLabel = 'Yesterday';
              } else {
                dateLabel = DateFormat('MMMM d, yyyy').format(date);
              }
            }
            if (!groupedDocs.containsKey(dateLabel)) {
              groupedDocs[dateLabel] = [];
            }
            groupedDocs[dateLabel]!.add(doc);
          }

          final listItems = [];
          for (var dateLabel in groupedDocs.keys) {
            listItems.add(dateLabel);
            listItems.addAll(groupedDocs[dateLabel]!);
          }

          return ListView.builder(
            itemCount: listItems.length,
            itemBuilder: (context, index) {
              final item = listItems[index];

              if (item is String) {
                return Padding(
                  padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8, right: 16),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: colorScheme.primary,
                    ),
                  ),
                );
              }

              final doc = item as QueryDocumentSnapshot;
              final data = doc.data() as Map<String, dynamic>;
              final peerId = data['peerId'] ?? '';
              final type = data['type'] ?? 'voice'; // 'voice' or 'video'
              final status = data['status'] ?? 'incoming'; // 'incoming' or 'outgoing'
              final timestamp = data['timestamp'] as Timestamp?;

              // Fetch user data for the peer
              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(peerId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox(height: 72);
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                  if (userData == null) return const SizedBox();

                  final peerName = userData['name'] ?? 'Unknown User';
                  final profilePic = userData['profilepic'] ?? '';
                  final isVideo = type == 'video';
                  final isOutgoing = status == 'outgoing';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: GestureDetector(
                      onTap: () {
                        if (profilePic.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenProfilePicPage(
                                imageUrl: profilePic,
                                heroTag: 'call_profile_pic_$peerId',
                              ),
                            ),
                          );
                        }
                      },
                      child: Hero(
                        tag: 'call_profile_pic_$peerId',
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: colorScheme.primaryContainer,
                          backgroundImage: profilePic.isNotEmpty && profilePic.startsWith('http')
                              ? CachedNetworkImageProvider(profilePic)
                              : null,
                          child: profilePic.isEmpty || !profilePic.startsWith('http')
                              ? Icon(Icons.person, color: colorScheme.onPrimaryContainer)
                              : null,
                        ),
                      ),
                    ),
                    title: Text(
                      peerName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Icon(
                          isOutgoing ? Icons.call_made : Icons.call_received,
                          size: 16,
                          color: isOutgoing ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: huge.HugeIcon(
                        icon: isVideo ? huge.HugeIcons.strokeRoundedVideo01 : huge.HugeIcons.strokeRoundedCall02,
                        color: colorScheme.primary,
                      ),
                      onPressed: () {
                        _startNewCall(context, peerId, peerName, isVideo);
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
