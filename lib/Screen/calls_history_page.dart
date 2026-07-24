import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import '../widgets/full_screen_profile_pic_page.dart';
import 'call_screen.dart';
import '../services/message_service.dart';

class GroupedCallLog {
  final String peerId;
  final List<QueryDocumentSnapshot> docs;

  GroupedCallLog({required this.peerId, required this.docs});

  QueryDocumentSnapshot get latestDoc => docs.first;

  int get count => docs.length;

  bool get hasMissedCall => docs.any((doc) {
        final status =
            (doc.data() as Map<String, dynamic>)['status']?.toString() ?? '';
        return status == 'missed' || status == 'declined';
      });
}

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

  String _activeFilter = 'All'; // 'All' or 'Missed'
  bool _isSelectionMode = false;
  final Set<String> _selectedDocIds = {};

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

  void _startNewCall(
      BuildContext context, String peerId, String peerName, bool isVideo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          isVideoCall: isVideo,
          receiverName: peerName,
          receiverId: peerId,
          onRoomCreated: (roomId) async {
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

            await _messageService.logCall(
              currentUserId: _auth.currentUser!.uid,
              peerId: peerId,
              type: isVideo ? 'video' : 'voice',
              status: 'outgoing',
              roomId: roomId,
            );

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

  Future<void> _deleteSelectedLogs() async {
    if (_selectedDocIds.isEmpty) return;
    try {
      final batch = _firestore.batch();
      for (var id in _selectedDocIds) {
        final ref = _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('call_history')
            .doc(id);
        batch.delete(ref);
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${_selectedDocIds.length} call log(s)')),
      );

      setState(() {
        _selectedDocIds.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting logs: $e')),
      );
    }
  }

  void _showClearAllConfirmDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Call History?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete all call history logs? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _clearAllHistory();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllHistory() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('call_history')
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call history cleared')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing history: $e')),
      );
    }
  }

  void _showCallDetailsModal(
      BuildContext context, GroupedCallLog groupedLog, String peerName, String profilePic) {
    final colorScheme = Theme.of(context).colorScheme;

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
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
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
                CircleAvatar(
                  radius: 36,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: profilePic.isNotEmpty &&
                          profilePic.startsWith('http')
                      ? CachedNetworkImageProvider(profilePic)
                      : const AssetImage('assets/icon/default_profile.png')
                          as ImageProvider,
                ),
                const SizedBox(height: 8),
                Text(
                  peerName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${groupedLog.count} call${groupedLog.count > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _startNewCall(context, groupedLog.peerId, peerName, false);
                      },
                      icon: const huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedCall02,
                        size: 18,
                      ),
                      label: const Text('Voice Call'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _startNewCall(context, groupedLog.peerId, peerName, true);
                      },
                      icon: const huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedVideo01,
                        size: 18,
                      ),
                      label: const Text('Video Call'),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: groupedLog.docs.length,
                    itemBuilder: (context, idx) {
                      final doc = groupedLog.docs[idx];
                      final data = doc.data() as Map<String, dynamic>;
                      final type = data['type'] ?? 'voice';
                      final status = data['status'] ?? 'incoming';
                      final timestamp = data['timestamp'] as Timestamp?;

                      final isVideo = type == 'video';
                      final isOutgoing = status == 'outgoing';
                      final isMissed = status == 'missed' || status == 'declined';

                      IconData iconData;
                      Color iconColor;
                      String statusLabel;

                      if (isMissed) {
                        iconData = Icons.call_missed;
                        iconColor = Colors.red;
                        statusLabel = isVideo ? 'Missed Video Call' : 'Missed Voice Call';
                      } else if (isOutgoing) {
                        iconData = Icons.call_made;
                        iconColor = Colors.green;
                        statusLabel = isVideo ? 'Outgoing Video Call' : 'Outgoing Voice Call';
                      } else {
                        iconData = Icons.call_received;
                        iconColor = Colors.blue;
                        statusLabel = isVideo ? 'Incoming Video Call' : 'Incoming Voice Call';
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withValues(alpha: 0.12),
                          child: Icon(iconData, color: iconColor, size: 20),
                        ),
                        title: Text(
                          statusLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isMissed ? Colors.red : colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                          onPressed: () async {
                            await _firestore
                                .collection('users')
                                .doc(_auth.currentUser!.uid)
                                .collection('call_history')
                                .doc(doc.id)
                                .delete();
                            if (context.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          },
                        ),
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

  Widget _buildFilterPills() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterChip('All', _activeFilter == 'All'),
          _buildFilterChip('Missed', _activeFilter == 'Missed'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        if (_activeFilter != label) {
          setState(() {
            _activeFilter = label;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.fastOutSlowIn,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              _isSelectionMode = false;
              _selectedDocIds.clear();
            });
          },
        ),
        title: Text(
          '${_selectedDocIds.length} selected',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_selectedDocIds.isNotEmpty)
            IconButton(
              icon: const huge.HugeIcon(
                icon: huge.HugeIcons.strokeRoundedDelete02,
                color: Colors.red,
                size: 22,
              ),
              onPressed: _deleteSelectedLogs,
            ),
        ],
      );
    }

    return AppBar(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surface,
      elevation: 0,
      title: Row(
        children: [
          const Text(
            'Call History',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const Spacer(),
          _buildFilterPills(),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'select') {
              setState(() {
                _isSelectionMode = true;
                _selectedDocIds.clear();
              });
            } else if (value == 'clear_all') {
              _showClearAllConfirmDialog();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'select',
              child: Row(
                children: [
                  Icon(Icons.check_box_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Select'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear_all',
              child: Row(
                children: [
                  huge.HugeIcon(
                    icon: huge.HugeIcons.strokeRoundedDelete02,
                    color: Colors.red,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text('Clear All History', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(context),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, usersSnapshot) {
          final userMap = <String, Map<String, dynamic>>{};
          if (usersSnapshot.hasData) {
            for (var doc in usersSnapshot.data!.docs) {
              userMap[doc.id] = doc.data() as Map<String, dynamic>;
            }
          }

          return StreamBuilder<QuerySnapshot>(
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

              // Apply Filter (All vs Missed)
              var filteredDocs = docs;
              if (_activeFilter == 'Missed') {
                filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status']?.toString() ?? '';
                  return status == 'missed' || status == 'declined';
                }).toList();
              }

              if (filteredDocs.isEmpty) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Center(
                    key: ValueKey('empty_$_activeFilter'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        huge.HugeIcon(
                          icon: huge.HugeIcons.strokeRoundedCall02,
                          size: 64,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _activeFilter == 'Missed'
                              ? 'No missed calls'
                              : 'No call history yet',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Group consecutive calls for the same peerId under each date section
              final dateGroups = <String, List<GroupedCallLog>>{};

              for (var doc in filteredDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = data['timestamp'] as Timestamp?;
                final peerId = data['peerId'] ?? '';

                String dateLabel = 'Unknown';
                if (timestamp != null) {
                  DateTime date = timestamp.toDate();
                  DateTime now = DateTime.now();
                  DateTime yesterday = now.subtract(const Duration(days: 1));
                  if (date.year == now.year &&
                      date.month == now.month &&
                      date.day == now.day) {
                    dateLabel = 'Today';
                  } else if (date.year == yesterday.year &&
                      date.month == yesterday.month &&
                      date.day == yesterday.day) {
                    dateLabel = 'Yesterday';
                  } else {
                    dateLabel = DateFormat('MMMM d, yyyy').format(date);
                  }
                }

                if (!dateGroups.containsKey(dateLabel)) {
                  dateGroups[dateLabel] = [];
                }

                final listForDate = dateGroups[dateLabel]!;
                if (listForDate.isNotEmpty && listForDate.last.peerId == peerId) {
                  listForDate.last.docs.add(doc);
                } else {
                  listForDate.add(GroupedCallLog(peerId: peerId, docs: [doc]));
                }
              }

              final listItems = [];
              for (var dateLabel in dateGroups.keys) {
                listItems.add(dateLabel);
                listItems.addAll(dateGroups[dateLabel]!);
              }

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.fastOutSlowIn,
                switchOutCurve: Curves.fastOutSlowIn,
                child: ListView.builder(
                  key: ValueKey('list_$_activeFilter'),
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 90),
                  itemCount: listItems.length,
                  itemBuilder: (context, index) {
                    final item = listItems[index];

                    if (item is String) {
                      return Padding(
                        padding: const EdgeInsets.only(
                            left: 20, top: 16, bottom: 8, right: 20),
                        child: Text(
                          item,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    }

                    final groupedLog = item as GroupedCallLog;
                    final latestData =
                        groupedLog.latestDoc.data() as Map<String, dynamic>;
                    final peerId = groupedLog.peerId;
                    final latestStatus = latestData['status'] ?? 'incoming';
                    final latestTimestamp = latestData['timestamp'] as Timestamp?;

                    final allDocIds = groupedLog.docs.map((d) => d.id).toSet();
                    final isGroupSelected =
                        allDocIds.every((id) => _selectedDocIds.contains(id));

                    // Synchronous instant lookup from userMap (0 delay!)
                    final userData = userMap[peerId];
                    final peerName = userData?['name'] ?? 'User';
                    final profilePic = userData?['profilepic'] ?? '';
                    final isOutgoing = latestStatus == 'outgoing';
                    final isMissed =
                        latestStatus == 'missed' || latestStatus == 'declined';

                    IconData statusIcon;
                    Color statusColor;
                    if (isMissed) {
                      statusIcon = Icons.call_missed;
                      statusColor = Colors.red;
                    } else if (isOutgoing) {
                      statusIcon = Icons.call_made;
                      statusColor = Colors.green;
                    } else {
                      statusIcon = Icons.call_received;
                      statusColor = Colors.blue;
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.fastOutSlowIn,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(
                        color: isGroupSelected
                            ? colorScheme.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isGroupSelected
                              ? colorScheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        onTap: () {
                          if (_isSelectionMode) {
                            setState(() {
                              if (isGroupSelected) {
                                _selectedDocIds.removeAll(allDocIds);
                                if (_selectedDocIds.isEmpty) {
                                  _isSelectionMode = false;
                                }
                              } else {
                                _selectedDocIds.addAll(allDocIds);
                              }
                            });
                          } else {
                            _showCallDetailsModal(
                                context, groupedLog, peerName, profilePic);
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedDocIds.addAll(allDocIds);
                          });
                        },
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isSelectionMode)
                              Checkbox(
                                value: isGroupSelected,
                                activeColor: colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedDocIds.addAll(allDocIds);
                                    } else {
                                      _selectedDocIds.removeAll(allDocIds);
                                      if (_selectedDocIds.isEmpty) {
                                        _isSelectionMode = false;
                                      }
                                    }
                                  });
                                },
                              ),
                            GestureDetector(
                              onTap: () {
                                if (profilePic.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          FullScreenProfilePicPage(
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
                                  radius: 24,
                                  backgroundColor: colorScheme.primaryContainer,
                                  backgroundImage: profilePic.isNotEmpty &&
                                          profilePic.startsWith('http')
                                      ? CachedNetworkImageProvider(profilePic)
                                      : const AssetImage(
                                              'assets/icon/default_profile.png')
                                          as ImageProvider,
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          groupedLog.count > 1
                              ? '$peerName (${groupedLog.count})'
                              : peerName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isMissed ? Colors.red : colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Icon(
                              statusIcon,
                              size: 15,
                              color: statusColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTimestamp(latestTimestamp),
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        trailing: _isSelectionMode
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: huge.HugeIcon(
                                      icon: huge.HugeIcons.strokeRoundedCall02,
                                      color: colorScheme.primary,
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      _startNewCall(
                                          context, peerId, peerName, false);
                                    },
                                  ),
                                  IconButton(
                                    icon: huge.HugeIcon(
                                      icon: huge.HugeIcons.strokeRoundedVideo01,
                                      color: colorScheme.primary,
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      _startNewCall(
                                          context, peerId, peerName, true);
                                    },
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
