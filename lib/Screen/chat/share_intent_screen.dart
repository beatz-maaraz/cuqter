import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:cuqter/Screen/chat/chat_screen.dart';
import 'package:cuqter/Screen/status/create_status_screen.dart';

class ShareIntentScreen extends StatefulWidget {
  final List<SharedMediaFile> sharedFiles;

  const ShareIntentScreen({super.key, required this.sharedFiles});

  @override
  State<ShareIntentScreen> createState() => _ShareIntentScreenState();
}

class _ShareIntentScreenState extends State<ShareIntentScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = _firestore.collection('users').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: currentUserId != null
                  ? _firestore.collection('users').doc(currentUserId).snapshots()
                  : null,
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<dynamic> myContacts = [];
                if (userSnapshot.hasData && userSnapshot.data?.exists == true) {
                  var myData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  if (myData != null) {
                    myContacts = myData['contacts'] as List<dynamic>? ?? [];
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _usersStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No friends found'));
                    }

                    var users = snapshot.data!.docs.where((doc) {
                      if (_auth.currentUser == null) return false;
                      if (doc.id == _auth.currentUser!.uid) return false;
                      return myContacts.contains(doc.id);
                    }).toList();

                    if (users.isEmpty) {
                      return const Center(child: Text('No friends found'));
                    }

                return GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var userData = users[index].data() as Map<String, dynamic>;
                    String userName = userData['name'] ?? 'Unknown User';
                    String profilePic = userData['profilepic']?.toString() ?? '';
                    String userId = users[index].id;

                    return InkWell(
                      onTap: () {
                        // Navigate to ChatScreen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              receiverId: userId,
                              receiverName: userName,
                              sharedMedia: widget.sharedFiles,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: colorScheme.primaryContainer,
                            backgroundImage: profilePic.isNotEmpty
                                ? NetworkImage(profilePic)
                                : null,
                            child: profilePic.isEmpty
                                ? Icon(Icons.person,
                                    size: 30, color: colorScheme.onPrimaryContainer)
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            userName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  final media = widget.sharedFiles.first;
                  final path = media.path;
                  final isVideo = media.type == SharedMediaType.video;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateStatusScreen(
                        sharedMediaPath: path,
                        isSharedMediaVideo: isVideo,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  'Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
