import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:cuqter/resources/auth_method.dart';
import 'package:cuqter/services/cloudinary_service.dart';
import 'package:cuqter/utils/picker.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cuqter/Screen/media/camera_screen.dart';
import 'package:cuqter/media.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cuqter/Account/login.dart';
import 'package:cuqter/Screen/home/navigation_screen.dart';
import 'package:cuqter/Screen/home/desktop_navigation_screen.dart';
import 'package:cuqter/responsive/responsive_layout.dart';
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
  int _currentStep = 0;

  String _selectedProfilePic = '';
  String? _cloudinaryPublicId;
  bool _isLoading = false;

  Future<void> signUpUser() async {
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
      showSnackBar(
        'Username can only contain letters, numbers, underscores, and dots',
        context,
      );
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
        await prefs.setString(
          'cached_profile_name',
          nameController.text.trim(),
        );
        await prefs.setString(
          'cached_profile_username',
          usernameController.text.trim(),
        );
        await prefs.setString('cached_profile_bio', '');
        await prefs.setString('cached_profile_pic', _selectedProfilePic);
        if (_cloudinaryPublicId != null) {
          await prefs.setString(
            'cached_cloudinary_public_id',
            _cloudinaryPublicId!,
          );
        }
      } catch (e) {
        print('Error caching signup details: $e');
      }

      if (mounted) {
        showSnackBar('Account created successfully', context);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const ResponsiveLayout(
              mobileLayout: NavigationScreen(),
              desktopLayout: DesktopNavigationScreen(),
            ),
          ),
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        showSnackBar(res, context);
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const ResponsiveLayout(
              mobileLayout: NavigationScreen(),
              desktopLayout: DesktopNavigationScreen(),
            ),
          ),
          (route) => false,
        );
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
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
              child: huge.HugeIcon(icon: icon, color: color, size: 24),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

  Future<void> _pickAndUploadCustomImage(
    ImageSource source, {
    bool isNativePicker = false,
  }) async {
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

        if (mounted) {
          showSnackBar('Profile picture uploaded successfully!', context);
        }
      } else {
        if (mounted) {
          showSnackBar('Failed to upload image to Cloudinary.', context);
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar('Error: $e', context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                      _pickAndUploadCustomImage(
                        ImageSource.gallery,
                        isNativePicker: true,
                      );
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

  void _nextStep() {
    if (_currentStep == 0) {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      if (email.isEmpty || password.isEmpty) {
        showSnackBar('Please enter your email and password', context);
        return;
      }
      if (!email.contains('@') || !email.contains('.')) {
        showSnackBar('Please enter a valid email address', context);
        return;
      }
      if (password.length < 6) {
        showSnackBar('Password must be at least 6 characters', context);
        return;
      }

      // Auto-suggest username from email prefix before '@'
      if (email.contains('@')) {
        final emailPrefix = email
            .split('@')
            .first
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '');
        if (emailPrefix.isNotEmpty && usernameController.text.trim().isEmpty) {
          usernameController.text = emailPrefix;
        }
      }

      setState(() {
        _currentStep = 1;
      });
    } else if (_currentStep == 1) {
      final username = usernameController.text.trim();
      if (username.isEmpty) {
        showSnackBar('Please choose a username', context);
        return;
      }
      if (username.contains(' ')) {
        showSnackBar('Spaces are not allowed in username', context);
        return;
      }
      final RegExp usernameRegex = RegExp(r'^[a-zA-Z0-9._]+$');
      if (!usernameRegex.hasMatch(username)) {
        showSnackBar(
          'Username can only contain letters, numbers, underscores, and dots',
          context,
        );
        return;
      }
      setState(() {
        _currentStep = 2;
      });
    } else if (_currentStep == 2) {
      if (nameController.text.trim().isEmpty) {
        showSnackBar('Please enter your name', context);
        return;
      }
      signUpUser();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  List<String> _getUsernameSuggestions() {
    final email = emailController.text.trim();
    if (!email.contains('@')) return [];
    final prefix = email
        .split('@')
        .first
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '');
    if (prefix.isEmpty) return [];

    final suggestions = <String>{prefix};
    if (prefix.contains('.')) {
      suggestions.add(prefix.replaceAll('.', ''));
      suggestions.add(prefix.replaceAll('.', '_'));
    } else {
      suggestions.add('${prefix}_');
      suggestions.add('${prefix}1');
    }
    return suggestions.take(3).toList();
  }

  Widget _buildStepContent(bool isDark) {
    switch (_currentStep) {
      case 0:
        return KeyedSubtree(
          key: const ValueKey(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.mail_outline_rounded,
                    color: Color(0xFF727786),
                  ),
                  hintText: 'hello@example.com',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF3F3F6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFF727786),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: const Color(0xFF727786),
                    ),
                    onPressed: () {
                      setState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                  hintText: '••••••••',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF3F3F6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        );

      case 1:
        return KeyedSubtree(
          key: const ValueKey(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _nextStep(),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.alternate_email_rounded,
                    color: Color(0xFF727786),
                  ),
                  hintText: 'johndoe',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF3F3F6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  final suggestions = _getUsernameSuggestions();
                  if (suggestions.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 13,
                              color: Color(0xFF0057C3),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Suggested from your email:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF727786),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: suggestions.map((sug) {
                            final isSelected =
                                usernameController.text.trim() == sug;
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    usernameController.text = sug;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF0057C3).withValues(alpha: 0.15)
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.06)
                                            : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF0057C3)
                                          : (isDark
                                              ? Colors.white12
                                              : Colors.black12),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '@$sug',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF0057C3)
                                          : (isDark
                                              ? Colors.white70
                                              : const Color(0xFF424754)),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Your friends will use this username to find and chat with you.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );

      case 2:
      default:
        return KeyedSubtree(
          key: const ValueKey(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _showProfilePicPicker,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF0057C3),
                                Color(0xFF883CA6),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: isDark
                                ? Colors.grey.shade900
                                : Colors.white,
                            backgroundImage:
                                _selectedProfilePic.isNotEmpty
                                ? (_selectedProfilePic.startsWith('http')
                                    ? CachedNetworkImageProvider(_selectedProfilePic)
                                    : AssetImage(_selectedProfilePic) as ImageProvider)
                                : null,
                            child: !(_selectedProfilePic.isNotEmpty)
                                ? const Icon(Icons.person, size: 48, color: Colors.grey)
                                : null,
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
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _showProfilePicPicker,
                    child: Text(
                      _selectedProfilePic.isNotEmpty
                          ? 'Change profile photo'
                          : 'Tap to choose profile photo',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0057C3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'FULL NAME',
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
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _nextStep(),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF727786),
                  ),
                  hintText: 'John Doe',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF3F3F6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        );
    }
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
                        colors: [
                          Color(0xFF0F172A),
                          Color(0xFF1E293B),
                          Color(0xFF0F172A),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [
                          Color(0xFFF8FAFC),
                          Color(0xFFE2E8F0),
                          Color(0xFFF1F5F9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              ),
            ),
          ),

          // Main Content
          Center(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                scrollbars: false,
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
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
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
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
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF424754),
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
                              color: const Color(
                                0xFF0057C3,
                              ).withValues(alpha: 0.12),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Step Indicator Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(3, (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentStep == index ? 28 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentStep == index
                                      ? const Color(0xFF0057C3)
                                      : (_currentStep > index
                                          ? const Color(0xFF0057C3).withValues(alpha: 0.5)
                                          : Colors.grey.withValues(alpha: 0.3)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              )),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                _currentStep == 0
                                    ? 'Step 1 of 3: Account Credentials'
                                    : _currentStep == 1
                                        ? 'Step 2 of 3: Choose Username'
                                        : 'Step 3 of 3: Profile Details',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white60 : const Color(0xFF727786),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Dynamic Step Form with AnimatedSize
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                                child: _buildStepContent(isDark),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Navigation Buttons (Back & Next/Create)
                            Row(
                              children: [
                                if (_currentStep > 0) ...[
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _isLoading ? null : _previousStep,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        side: BorderSide(
                                          color: isDark ? Colors.white30 : const Color(0xFF0057C3),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                      ),
                                      child: Text(
                                        'Back',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : const Color(0xFF0057C3),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  flex: _currentStep > 0 ? 2 : 1,
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
                                      onPressed: _isLoading ? null : _nextStep,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              _currentStep == 2 ? 'Create Account' : 'Next',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (_currentStep == 0) ...[
                              const SizedBox(height: 24),
                              // Divider
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.black12,
                                    ),
                                  ),
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
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.black12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Google Sign Up
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.grey.shade300,
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
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Footer Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF424754),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const Loginpage(),
                                    ),
                                  );
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: Text(
                                  'Login',
                                  style: TextStyle(
                                    color: Color(0xFF0057C3),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
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
