import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cuqter/Account/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
    });
    try {
      var snap = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
      if (snap.exists && snap.data() != null) {
        var data = snap.data() as Map<String, dynamic>;
        _nameController.text = data['name'] ?? '';
        _bioController.text = data['bio'] ?? '';
      }
    } catch (e) {
      print(e);
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _updateProfile() async {
    setState(() {
      isLoading = true;
    });
    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'name': _nameController.text,
        'bio': _bioController.text,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _deleteUserAccount() async {
    setState(() {
      isLoading = true;
    });
    try {
      String userId = _auth.currentUser!.uid;
      
      // Delete user data from Firestore
      await _firestore.collection('users').doc(userId).delete();
      
      // Delete user authentication account
      await _auth.currentUser!.delete();
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully! Redirecting to login...'),
            duration: Duration(seconds: 2),
          ),
        );
        
        // Wait for 2 seconds before navigation
        await Future.delayed(const Duration(seconds: 2));
        
        // Sign out explicitly
        await _auth.signOut();
        
        // Navigate to login page
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const Loginpage()),
            (Route<dynamic> route) => false,
          );
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted from our servers.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.teal)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteUserAccount();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                     const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.person, size: 50, color: Colors.white),
                     ),
                     const SizedBox(height: 20),
                     TextField(
                       controller: _nameController,
                       decoration: const InputDecoration(
                         labelText: 'Name',
                         border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                         ),
                       ),
                     ),
                     const SizedBox(height: 16),
                     TextField(
                       controller: _bioController,
                       maxLines: 3,
                       decoration: const InputDecoration(
                         labelText: 'Bio',
                         border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                         ),
                       ),
                     ),
                     const SizedBox(height: 24),
                     SizedBox(
                       width: 150,
                       height: 50,
                       child: ElevatedButton(
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.teal,
                           padding: const EdgeInsets.symmetric(vertical: 14),
                         ),
                         onPressed: _updateProfile,
                         child: const Text(
                           'Save Changes',
                           style: TextStyle(fontSize: 16, color: Colors.white),
                         ),
                       ),
                     ),
                     const SizedBox(height: 16),
                     SizedBox(
                       width: 150,
                       height: 50,
                       child: ElevatedButton(
                         style: ElevatedButton.styleFrom(
                           backgroundColor: const Color.fromARGB(255, 209, 114, 108),
                           padding: const EdgeInsets.symmetric(vertical: 14),
                         ),
                         onPressed: _showDeleteConfirmationDialog,
                         child: const Text(
                           'Delete Account',
                           style: TextStyle(fontSize: 16, color: Colors.white),
                         ),
                       ),
                     )
                  ],
                ),
              ),
            ),
    );
  }
}
