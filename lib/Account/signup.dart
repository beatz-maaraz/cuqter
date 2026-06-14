import 'dart:typed_data';
import 'package:cuqter/resources/auth_method.dart';
import 'package:cuqter/services/cloudinary_service.dart';
import 'package:cuqter/utils/picker.dart';
import 'package:flutter/material.dart';
import 'package:cuqter/utils/colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Sighuppage extends StatefulWidget {
  const Sighuppage({super.key});

  @override
  State<Sighuppage> createState() => _SighuppageState();
}

class _SighuppageState extends State<Sighuppage> {

  TextEditingController nameController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;
  
  String _selectedProfilePic = 'assets/profile/BOY (1).jpg';
  String? _cloudinaryPublicId;
  bool _isLoading = false;

  final List<String> _profilePictures = [
    'assets/profile/BOY (1).jpg',
    'assets/profile/BOY (2).jpg',
    'assets/profile/BOY (3).jpg',
    'assets/profile/BOY (4).jpg',
    'assets/profile/Girl (1).jpg',
    'assets/profile/Girl (2).jpg',
    'assets/profile/NEW (1).jpg',
    'assets/profile/NEW (2).jpg',
    'assets/profile/NEW (3).jpg',
    'assets/profile/NEW (4).jpg',
    'assets/profile/NEW (5).jpg',
    'assets/profile/NEW (6).jpg',
  ];

  signUpUser() async {
    if (nameController.text.trim().isEmpty ||
        usernameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      showSnackBar('Please enter all the fields', context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String res = await AuthMethod().signUpUser(
      name: nameController.text.trim(),
      username: usernameController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
      profilepic: _selectedProfilePic,
      cloudinaryPublicId: _cloudinaryPublicId,
    );

    if (res == 'success') {
      // Cache details locally for instant loading
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_profile_name', nameController.text.trim());
        await prefs.setString('cached_profile_username', usernameController.text.trim());
        await prefs.setString('cached_profile_bio', 'Cuqter Member');
        await prefs.setString('cached_profile_pic', _selectedProfilePic);
        if (_cloudinaryPublicId != null) {
          await prefs.setString('cached_cloudinary_public_id', _cloudinaryPublicId!);
        }
      } catch (e) {
        print('Error caching signup details: $e');
      }

      showSnackBar('Account created successfully', context);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } else {
      showSnackBar(res, context);
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickAndUploadCustomImage(ImageSource source) async {
    try {
      final Uint8List? imageBytes = await pickImage(source);
      if (imageBytes == null) return;

      setState(() {
        _isLoading = true;
      });

      final uploadResult = await CloudinaryService.uploadImage(imageBytes);
      if (uploadResult != null) {
        final String newUrl = uploadResult['url']!;
        final String newPublicId = uploadResult['public_id']!;
        String? oldPublicId = _cloudinaryPublicId;

        setState(() {
          _selectedProfilePic = newUrl;
          _cloudinaryPublicId = newPublicId;
        });

        // Delete old picture if it existed
        if (oldPublicId != null && oldPublicId.isNotEmpty) {
          await CloudinaryService.deleteImage(oldPublicId);
        }

        showSnackBar('Profile picture uploaded successfully!', context);
      } else {
        showSnackBar('Failed to upload image to Cloudinary.', context);
      }
    } catch (e) {
      showSnackBar('Error: $e', context);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showProfilePicPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Choose Profile Picture',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select an avatar or upload your own.',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _pickAndUploadCustomImage(ImageSource.camera);
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _pickAndUploadCustomImage(ImageSource.gallery);
                            },
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _profilePictures.length,
                      itemBuilder: (context, index) {
                        final path = _profilePictures[index];
                        final isSelected = _selectedProfilePic == path;
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              _selectedProfilePic = path;
                            });
                            setState(() {
                              _selectedProfilePic = path;
                              // Clean up previous Cloudinary upload if user switches back to asset
                              if (_cloudinaryPublicId != null) {
                                CloudinaryService.deleteImage(_cloudinaryPublicId!);
                                _cloudinaryPublicId = null;
                              }
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? colorScheme.primary : Colors.transparent,
                                width: 4,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundImage: AssetImage(path),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Confirm Selection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: SizedBox(
                  width: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Sign Up',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _showProfilePicPicker,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                backgroundImage: _selectedProfilePic.startsWith('http')
                                    ? NetworkImage(_selectedProfilePic) as ImageProvider
                                    : AssetImage(_selectedProfilePic) as ImageProvider,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person),
                          hintText: 'Maaraz',
                          labelText: "Enter your Name",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: usernameController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.alternate_email),
                          hintText: 'maaraz',
                          labelText: "Enter your Username",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email),
                          hintText: 'cuqter@mail.com',
                          labelText: "Enter your Email",
                          fillColor: const Color.fromARGB(255, 112, 111, 111),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: passwordController,
                        obscureText: !isPasswordVisible,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                	isPasswordVisible = !isPasswordVisible;
                              });
                            },
                          ),
                          hintText: '********',
                          labelText: "Enter your password",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: signUpUser,
                        child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "I have an account? ",
                            style: TextStyle(color: AppColors.grey),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "Login",
                              style: TextStyle(color: AppColors.blueDefault),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}