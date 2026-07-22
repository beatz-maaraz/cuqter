import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cuqter/Screen/userprofile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Search Bar Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 0.0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = "";
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Search Results Grid
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _auth.currentUser != null
                    ? _firestore
                          .collection('users')
                          .doc(_auth.currentUser!.uid)
                          .snapshots()
                    : const Stream.empty(),
                builder: (context, userSnapshot) {
                  List<dynamic> myContacts = [];
                  if (userSnapshot.hasData &&
                      userSnapshot.data?.exists == true) {
                    var myData =
                        userSnapshot.data!.data() as Map<String, dynamic>?;
                    if (myData != null) {
                      myContacts = myData['contacts'] as List<dynamic>? ?? [];
                    }
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: _auth.currentUser != null
                        ? _firestore
                              .collection('friend_requests')
                              .where(
                                'senderId',
                                isEqualTo: _auth.currentUser!.uid,
                              )
                              .snapshots()
                        : const Stream.empty(),
                    builder: (context, requestSnapshot) {
                      Set<String> requestedUserIds = {};
                      if (requestSnapshot.hasData) {
                        requestedUserIds = requestSnapshot.data!.docs
                            .map((doc) => doc['receiverId'] as String)
                            .toSet();
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collection('users').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          var users =
                              snapshot.data?.docs.where((doc) {
                                if (_auth.currentUser == null) return false;
                                if (doc.id == _auth.currentUser!.uid)
                                  return false;
                                if (myContacts.contains(doc.id))
                                  return false; // Filter out existing friends

                                if (_searchQuery.isNotEmpty) {
                                  var data =
                                      doc.data() as Map<String, dynamic>?;
                                  String username = (data?['username'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  String name = (data?['name'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  return username.contains(_searchQuery) ||
                                      name.contains(_searchQuery);
                                }
                                return true;
                              }).toList() ??
                              [];

                          if (users.isEmpty) {
                            return Center(
                              child: Text(
                                'No users found',
                                style: TextStyle(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            );
                          }

                          return GridView.builder(
                            padding: const EdgeInsets.all(16.0),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.95,
                                ),
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              var userData =
                                  users[index].data() as Map<String, dynamic>;
                              String name = userData['name'] ?? 'Unknown User';
                              String username = userData['username'] ?? '';
                              String profilePic = userData['profilepic'] ?? '';
                              String bio = userData['bio'] ?? '';

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder:
                                              (
                                                context,
                                                animation,
                                                secondaryAnimation,
                                              ) => UserProfilePage(
                                                userId: users[index].id,
                                                name: name,
                                                username: username,
                                                bio: bio,
                                                profilepic: profilePic,
                                                isFriend: false, // Already filtered out
                                                isRequested: requestedUserIds.contains(users[index].id),
                                              ),
                                          transitionsBuilder:
                                              (
                                                context,
                                                animation,
                                                secondaryAnimation,
                                                child,
                                              ) {
                                                return FadeTransition(
                                                  opacity: animation,
                                                  child: ScaleTransition(
                                                    scale:
                                                        Tween<double>(
                                                          begin: 0.95,
                                                          end: 1.0,
                                                        ).animate(
                                                          CurvedAnimation(
                                                            parent: animation,
                                                            curve: Curves
                                                                .easeOutCubic,
                                                          ),
                                                        ),
                                                    child: child,
                                                  ),
                                                );
                                              },
                                          transitionDuration: const Duration(
                                            milliseconds: 250,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.05),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Hero(
                                            tag: 'profile_pic_hero_$username',
                                            child: CircleAvatar(
                                              radius: 36,
                                              backgroundColor: colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.1),
                                              backgroundImage:
                                                  profilePic.isNotEmpty
                                                  ? (profilePic.startsWith(
                                                              'http',
                                                            )
                                                            ? CachedNetworkImageProvider(
                                                                profilePic,
                                                              )
                                                            : AssetImage(
                                                                profilePic,
                                                              ))
                                                        as ImageProvider
                                                  : null,
                                              child: profilePic.isEmpty
                                                  ? Icon(
                                                      Icons.person,
                                                      color:
                                                          colorScheme.primary,
                                                      size: 36,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: colorScheme.onSurface,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: colorScheme.primary,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'View',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: () async {
                                          if (_auth.currentUser == null) return;
                                          String currentUserId =
                                              _auth.currentUser!.uid;
                                          String targetUserId = users[index].id;

                                          if (requestedUserIds.contains(
                                            targetUserId,
                                          ))
                                            return; // Already requested

                                          String requestId =
                                              '${currentUserId}_$targetUserId';

                                          try {
                                            DocumentSnapshot myDoc =
                                                await _firestore
                                                    .collection('users')
                                                    .doc(currentUserId)
                                                    .get();
                                            String myName =
                                                (myDoc.data()
                                                    as Map<
                                                      String,
                                                      dynamic
                                                    >?)?['name'] ??
                                                'Unknown User';
                                            String myPic =
                                                (myDoc.data()
                                                    as Map<
                                                      String,
                                                      dynamic
                                                    >?)?['profilepic'] ??
                                                '';

                                            await _firestore
                                                .collection('friend_requests')
                                                .doc(requestId)
                                                .set({
                                                  'senderId': currentUserId,
                                                  'receiverId': targetUserId,
                                                  'status': 'pending',
                                                  'senderName': myName,
                                                  'senderProfilePic': myPic,
                                                  'timestamp':
                                                      FieldValue.serverTimestamp(),
                                                });

                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Friend request sent to $name!',
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Failed to send request',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color:
                                                requestedUserIds.contains(
                                                  users[index].id,
                                                )
                                                ? colorScheme.primary
                                                : colorScheme.surface,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: colorScheme.primary,
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.1,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            transitionBuilder:
                                                (child, animation) =>
                                                    ScaleTransition(
                                                      scale: animation,
                                                      child: child,
                                                    ),
                                            child: Icon(
                                              requestedUserIds.contains(
                                                    users[index].id,
                                                  )
                                                  ? Icons.check
                                                  : Icons.add,
                                              key: ValueKey(
                                                requestedUserIds.contains(
                                                  users[index].id,
                                                ),
                                              ),
                                              size: 20,
                                              color:
                                                  requestedUserIds.contains(
                                                    users[index].id,
                                                  )
                                                  ? colorScheme.onPrimary
                                                  : colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
