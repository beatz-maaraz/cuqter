import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cuqter/Screen/chat_screen.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  final List<String> _alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

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
          'Friends',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
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

          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(currentUserId)
                  .snapshots(),
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
                  stream: _firestore.collection('users').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var allUsers =
                        snapshot.data?.docs.where((doc) {
                          if (doc.id == currentUserId) return false;
                          return myContacts.contains(doc.id);
                        }).toList() ??
                        [];

                    // Group by first letter
                    Map<String, List<QueryDocumentSnapshot>> groupedContacts =
                        {};
                    for (var user in allUsers) {
                      var data = user.data() as Map<String, dynamic>?;
                      String name = (data?['name'] ?? '').toString();
                      if (_searchQuery.isNotEmpty &&
                          !name.toLowerCase().contains(_searchQuery)) {
                        continue; // Skip if it doesn't match search
                      }

                      String firstLetter = name.isNotEmpty
                          ? name[0].toUpperCase()
                          : "#";
                      if (!RegExp(r'[A-Z]').hasMatch(firstLetter)) {
                        firstLetter = "#";
                      }
                      groupedContacts
                          .putIfAbsent(firstLetter, () => [])
                          .add(user);
                    }

                    // Sort groups and items within groups
                    var sortedKeys = groupedContacts.keys.toList()..sort();
                    for (var key in sortedKeys) {
                      groupedContacts[key]!.sort((a, b) {
                        var dataA = a.data() as Map<String, dynamic>?;
                        var dataB = b.data() as Map<String, dynamic>?;
                        return (dataA?['name'] ?? '').toString().compareTo(
                          (dataB?['name'] ?? '').toString(),
                        );
                      });
                    }

                    if (groupedContacts.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'No friends found'
                              : 'You have no friends yet',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      );
                    }

                    return Stack(
                      children: [
                        ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(
                            right: 32,
                            left: 16,
                            top: 8,
                            bottom: 24,
                          ),
                          itemCount: sortedKeys.length,
                          itemBuilder: (context, sectionIndex) {
                            String letter = sortedKeys[sectionIndex];
                            List<QueryDocumentSnapshot> sectionUsers =
                                groupedContacts[letter]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 8.0,
                                  ),
                                  child: Text(
                                    letter,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                                ...sectionUsers.map((userDoc) {
                                  var data =
                                      userDoc.data() as Map<String, dynamic>;
                                  String name = data['name'] ?? 'Unknown User';
                                  String profilePic = data['profilepic'] ?? '';
                                  String userId = userDoc.id;

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            receiverId: userId,
                                            receiverName: name,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.05),
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                        leading: CircleAvatar(
                                          radius: 22,
                                          backgroundColor: colorScheme.primary
                                              .withValues(alpha: 0.1),
                                          backgroundImage: profilePic.isNotEmpty
                                              ? (profilePic.startsWith('http')
                                                        ? CachedNetworkImageProvider(
                                                            profilePic,
                                                          )
                                                        : AssetImage(
                                                            profilePic,
                                                          ))
                                                    as ImageProvider
                                              : const AssetImage('assets/icon/default_profile.png'),
                                        ),
                                        title: Text(
                                          name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),

                        // Alphabet Scrollbar
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: _alphabet.map((letter) {
                                bool isActive = sortedKeys.contains(letter);
                                return GestureDetector(
                                  onTap: () {
                                    // Basic scroll behavior; advanced would calculate exact offset
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2.0,
                                    ),
                                    child: Text(
                                      letter,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isActive
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isActive
                                            ? colorScheme.primary
                                            : colorScheme.onSurface.withValues(
                                                alpha: 0.3,
                                              ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
