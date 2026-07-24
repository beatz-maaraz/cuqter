import 'dart:io';
import 'dart:typed_data';
import 'package:cuqter/resources/auth_method.dart';
import 'package:cuqter/services/cloudinary_service.dart';
import 'package:cuqter/utils/picker.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cuqter/Screen/camera_screen.dart';
import 'package:cuqter/media.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cuqter/widgets/floating_background_bubbles.dart';
import 'package:cuqter/widgets/google_logo_icon.dart';

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
  
  String _selectedProfilePic = '';
  String? _cloudinaryPublicId;
  bool _isLoading = false;

  signUpUser() async {
    final String usernameRaw = usernameController.text;
    if (nameController.text.trim().isEmpty ||
        usernameRaw.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      showSnackBar('Please enter all the fields', context);
      return;
    }

    if (usernameRaw.contains(' ')) {
      showSnackBar('Spaces are not allowed in username', context);
      return;
    }

    final RegExp usernameRegex = RegExp(r'^[a-zA-Z0-9._]+$');
    if (!usernameRegex.hasMatch(usernameRaw.trim())) {
      showSnackBar('Username can only contain letters, numbers, underscores, and dots', context);
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
        await prefs.setString('cached_profile_bio', '');
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

  void signUpWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    String res = await AuthMethod().signInWithGoogle();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (res == 'success') {
        showSnackBar('Account connected with Google successfully', context);
        Navigator.of(context).pop();
      } else if (res != 'cancelled') {
        showSnackBar(res, context);
      }
    }
  }

  void _removeProfilePicture() {
    setState(() {
      _selectedProfilePic = '';
      if (_cloudinaryPublicId != null) {
        CloudinaryService.deleteMedia(_cloudinaryPublicId!);
        _cloudinaryPublicId = null;
      }
    });
    showSnackBar('Profile picture removed', context);
  }

  Widget _buildChooseOptionItem({
    required dynamic icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: Center(
              child: huge.HugeIcon(
                icon: icon,
                color: color,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadCustomImage(ImageSource source, {bool isNativePicker = false}) async {
    try {
      Uint8List? imageBytes;
      if (source == ImageSource.camera) {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(builder: (context) => const CustomCameraScreen()),
        );
        if (result != null && result['file'] != null) {
          final XFile file = result['file'] as XFile;
          imageBytes = await file.readAsBytes();
        }
      } else if (isNativePicker) {
        // Mobile own native gallery / Google Photos / Files app
        final XFile? file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        if (file != null) {
          imageBytes = await file.readAsBytes();
        }
      } else {
        // Internal App Gallery (AssetManagerScreen)
        final result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const AssetManagerScreen(
            isPicker: true,
            onlyImages: true,
            initialTab: 'Images',
          ),
        );
        if (result != null && result is AppAsset) {
          imageBytes = await File(result.imageUrl).readAsBytes();
        }
      }
      
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
          await CloudinaryService.deleteMedia(oldPublicId);
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
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Choose',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (_selectedProfilePic.isNotEmpty)
                    IconButton(
                      tooltip: 'Remove profile picture',
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _removeProfilePicture();
                      },
                      icon: const huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedDelete02,
                        color: Colors.red,
                        size: 22,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildChooseOptionItem(
                    icon: huge.HugeIcons.strokeRoundedCamera01,
                    label: 'Camera',
                    color: colorScheme.primary,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndUploadCustomImage(ImageSource.camera);
                    },
                  ),
                  _buildChooseOptionItem(
                    icon: huge.HugeIcons.strokeRoundedImage01,
                    label: 'Gallery',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndUploadCustomImage(ImageSource.gallery);
                    },
                  ),
                  _buildChooseOptionItem(
                    icon: huge.HugeIcons.strokeRoundedFolder01,
                    label: 'Other',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndUploadCustomImage(ImageSource.gallery, isNativePicker: true);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF14142B), Color(0xFF0E0E1E), Color(0xFF1F122B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFD9E2FF), Color(0xFFFFFFFF), Color(0xFFF9D8FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              ),
            ),
          ),
          // Floating background animated conversation icons
          const FloatingBackgroundBubbles(),

          // Main Content
          Center(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Brand Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0057C3).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/icon/icon.png',
                        height: 54,
                        width: 54,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.chat_bubble_rounded,
                          size: 40,
                          color: Color(0xFF0057C3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF0057C3), Color(0xFF883CA6)],
                      ).createShader(bounds),
                      child: const Text(
                        'Cuqter',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create your new account',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : const Color(0xFF424754),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Glassmorphic Card
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0057C3).withValues(alpha: 0.12),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Picture Avatar Picker
                          Center(
                            child: GestureDetector(
                              onTap: _showProfilePicPicker,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF0057C3), Color(0xFF883CA6)],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: CircleAvatar(
                                      radius: 46,
                                      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
                                      backgroundImage: _selectedProfilePic.isNotEmpty
                                          ? (_selectedProfilePic.startsWith('http')
                                              ? CachedNetworkImageProvider(_selectedProfilePic)
                                              : AssetImage(_selectedProfilePic) as ImageProvider)
                                          : const AssetImage('assets/icon/default_profile.png'),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0057C3),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Name
                          const Text(
                            'NAME',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: Color(0xFF424754),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameController,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF727786)),
                              hintText: "John Doe",
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F3F6),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Username
                          const Text(
                            'USERNAME',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: Color(0xFF424754),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: usernameController,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF727786)),
                              hintText: "johndoe",
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F3F6),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Email
                          const Text(
                            'EMAIL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: Color(0xFF424754),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: emailController,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF727786)),
                              hintText: "hello@example.com",
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F3F6),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password
                          const Text(
                            'PASSWORD',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: Color(0xFF424754),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: passwordController,
                            obscureText: !isPasswordVisible,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF727786)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                  color: const Color(0xFF727786),
                                ),
                                onPressed: () {
                                  setState(() {
                                    isPasswordVisible = !isPasswordVisible;
                                  });
                                },
                              ),
                              hintText: "••••••••",
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F3F6),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Action Sign Up Gradient Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0057C3), Color(0xFF883CA6)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0057C3).withValues(alpha: 0.35),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: _isLoading ? null : signUpUser,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Text(
                                        'Sign Up',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Divider
                          Row(
                            children: [
                              Expanded(child: Container(height: 1, color: isDark ? Colors.white12 : Colors.black12)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR CONTINUE WITH',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: Color(0xFF727786),
                                  ),
                                ),
                              ),
                              Expanded(child: Container(height: 1, color: isDark ? Colors.white12 : Colors.black12)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Google Sign Up
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                side: BorderSide(
                                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                                ),
                              ),
                              onPressed: _isLoading ? null : signUpWithGoogle,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GoogleLogoIcon(size: 20),
                                  SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      'Continue with Google',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Footer Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF424754),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Login",
                            style: TextStyle(
                              color: Color(0xFF0057C3),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
