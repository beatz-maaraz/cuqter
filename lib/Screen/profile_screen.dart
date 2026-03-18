import 'package:cloud_firestore/cloud_firestore.dart';
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
                       border: OutlineInputBorder(),
                     ),
                   ),
                   const SizedBox(height: 16),
                   TextField(
                     controller: _bioController,
                     maxLines: 3,
                     decoration: const InputDecoration(
                       labelText: 'Bio',
                       border: OutlineInputBorder(),
                     ),
                   ),
                   const SizedBox(height: 24),
                   SizedBox(
                     width: double.infinity,
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
                   )
                ],
              ),
            ),
    );
  }
}
