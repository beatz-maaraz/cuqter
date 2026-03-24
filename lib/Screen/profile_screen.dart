import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cuqter/Account/login.dart';
import 'package:cuqter/Screen/settings_page.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const SettingsPage(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(0.0, 1.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;
                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    return SlideTransition(position: animation.drive(tween), child: child);
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                   const SizedBox(height: 10),
                   Center(
                     child: Stack(
                       alignment: Alignment.center,
                       children: [
                         Container(
                           padding: const EdgeInsets.all(4),
                           decoration: BoxDecoration(
                             color: colorScheme.primary.withOpacity(0.1),
                             shape: BoxShape.circle,
                           ),
                           child: CircleAvatar(
                            radius: 60,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?',
                              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer),
                            ),
                           ),
                         ),
                         Positioned(
                           bottom: 4,
                           right: 4,
                           child: Container(
                             padding: const EdgeInsets.all(4),
                             decoration: BoxDecoration(
                               color: Colors.blue,
                               shape: BoxShape.circle,
                               border: Border.all(color: colorScheme.surface, width: 3),
                             ),
                             child: const Icon(Icons.verified, size: 16, color: Colors.white),
                           ),
                         ),
                       ],
                     ),
                   ),
                   const SizedBox(height: 24),
                   Text(
                     _nameController.text,
                     style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 4),
                   Text(
                     _bioController.text.isNotEmpty ? _bioController.text : 'Cuqter Member',
                     style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.6)),
                   ),
                   const SizedBox(height: 32),
                   Container(
                     padding: const EdgeInsets.all(24),
                     decoration: BoxDecoration(
                       color: colorScheme.surfaceVariant.withOpacity(0.3),
                       borderRadius: BorderRadius.circular(24),
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         _buildInfoItem(context, 'EMAIL ADDRESS', user?.email ?? 'No email'),
                         const Divider(height: 32),
                         _buildInfoItem(context, 'PHONE NUMBER', '+1 (555) 000-0000'), // Placeholder for design
                         const Divider(height: 32),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   'SUBSCRIPTION STATUS',
                                   style: TextStyle(
                                     fontSize: 10,
                                     fontWeight: FontWeight.bold,
                                     color: colorScheme.onSurface.withOpacity(0.5),
                                   ),
                                 ),
                                 const SizedBox(height: 8),
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                   decoration: BoxDecoration(
                                     color: Colors.blue.withOpacity(0.1),
                                     borderRadius: BorderRadius.circular(8),
                                   ),
                                   child: const Text(
                                     'Premium Plan',
                                     style: TextStyle(
                                       fontSize: 10,
                                       fontWeight: FontWeight.bold,
                                       color: Colors.blue,
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                             Text(
                               'Renews Oct 2026',
                               style: TextStyle(
                                 fontSize: 10,
                                 color: colorScheme.onSurface.withOpacity(0.5),
                               ),
                             ),
                           ],
                         ),
                       ],
                     ),
                   ),
                   const SizedBox(height: 32),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton.icon(
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.blue[700],
                         foregroundColor: Colors.white,
                         padding: const EdgeInsets.symmetric(vertical: 16),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                         elevation: 4,
                         shadowColor: Colors.blue.withOpacity(0.4),
                       ),
                       onPressed: _showEditDialog,
                       icon: const Icon(Icons.edit, size: 20),
                       label: const Text(
                         'Edit Profile',
                         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                       ),
                     ),
                   ),
                   const SizedBox(height: 16),
                   TextButton(
                     onPressed: _showDeleteConfirmationDialog,
                     child: Text(
                       'View Public Profile',
                       style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                     ),
                   ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateProfile();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

