import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cuqter/Account/login.dart';
import 'package:cuqter/Screen/chat_screen.dart';
import 'package:cuqter/Screen/profile_screen.dart';
import 'package:cuqter/resources/auth_method.dart';
import 'package:cuqter/utils/colors.dart';
import 'package:flutter/material.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with WidgetsBindingObserver {
  String username = "";
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUserStatus(true);
    getUsername();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserStatus(true);
    } else {
      _setUserStatus(false);
    }
  }

  Future<void> _setUserStatus(bool isOnline) async {
    if (_auth.currentUser != null) {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((e) {
        // Handle error conceptually if document somehow doesn't exist
      });
    }
  }

  void getUsername() async {
    try {
      var snap = await AuthMethod().getUserDetails();
      if (snap.exists && snap.data() != null) {
        setState(() {
          username = (snap.data() as Map<String, dynamic>)['name'] ?? '';
        });
      }
    } catch (e) {
      print(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Cuqter Chat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () async {
              await AuthMethod().signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const Loginpage()),
                (route) => false,
              );
            },
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _auth.currentUser != null ? _firestore.collection('users').doc(_auth.currentUser!.uid).snapshots() : const Stream.empty(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<dynamic> myContacts = [];
                if (userSnapshot.hasData && userSnapshot.data?.exists == true) {
                  var myData = userSnapshot.data!.data() as Map<String, dynamic>?;
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

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No users found.'));
                    }

                    var users = snapshot.data!.docs.where((doc) {
                      if (_auth.currentUser == null) return false;
                      if (doc.id == _auth.currentUser!.uid) return false;
                      
                      if (searchQuery.isNotEmpty) {
                        var data = doc.data() as Map<String, dynamic>?;
                        if (data == null) return false;
                        String name = (data['name'] ?? '').toString().toLowerCase();
                        String email = (data['email'] ?? '').toString().toLowerCase();
                        return name.contains(searchQuery) || email.contains(searchQuery);
                      } else {
                        return myContacts.contains(doc.id);
                      }
                    }).toList();

                    if (users.isEmpty) {
                      return Center(
                        child: Text(searchQuery.isNotEmpty 
                            ? 'No users match your search.' 
                            : 'No recent chats. Search to find users!'),
                      );
                    }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var userData = users[index].data() as Map<String, dynamic>;
                    String userName = userData['name'] ?? 'Unknown User';
                    String userBio = userData['bio'] ?? userData['email'] ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?'),
                      ),
                      title: Text(userName),
                      subtitle: Text(userBio, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              receiverId: users[index].id,
                              receiverName: userName,
                            ),
                          ),
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
);
  }
}