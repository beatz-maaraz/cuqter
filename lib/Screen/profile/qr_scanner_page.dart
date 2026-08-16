import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cuqter/Screen/chat/chat_screen.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:image_picker/image_picker.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickAndScanImage() async {
    if (_isProcessing) return;

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _isProcessing = true;
        });

        final BarcodeCapture? capture =
            await _controller.analyzeImage(image.path);
        if (capture != null && capture.barcodes.isNotEmpty) {
          final String? rawValue = capture.barcodes.first.rawValue;
          if (rawValue != null) {
            await _handleQrCode(rawValue);
            return;
          }
        }
        _showError('No QR code found in the selected image.');
      }
    } catch (e) {
      _showError('Error reading the image from gallery.');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleQrCode(String value) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    String rawSlug = value.trim();

    // Strip URL — handle cuqter.com/<username> and cuqter.com/user/<uid>
    if (rawSlug.contains('cuqter.com/')) {
      rawSlug = rawSlug.split('cuqter.com/').last.replaceFirst('user/', '');
    }

    if (rawSlug.isEmpty) {
      _showError('Invalid QR code scanned.');
      return;
    }

    try {
      String? targetUid;

      // First try as a UID directly
      final directDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(rawSlug)
          .get();

      if (directDoc.exists) {
        targetUid = rawSlug;
      } else {
        // Look up by username field
        final usernameQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: rawSlug)
            .limit(1)
            .get();

        if (usernameQuery.docs.isNotEmpty) {
          targetUid = usernameQuery.docs.first.id;
        }
      }

      if (targetUid == null) {
        _showError('User not found on Cuqter.');
        return;
      }

      if (targetUid == currentUserId) {
        _showError('You scanned your own QR code!');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final name = data['name'] ?? 'User';
        final profilePic = data['profilepic'] ?? '';
        final isOnline = data['isOnline'] as bool?;

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                receiverId: targetUid!,
                receiverName: name,
                receiverProfilePic: profilePic,
                receiverIsOnline: isOnline,
              ),
            ),
          );
        }
      } else {
        _showError('User not found on Cuqter.');
      }
    } catch (e) {
      _showError('Error retrieving user details.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    _controller.stop();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Invalid Code',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isProcessing = false;
              });
              _controller.start();
            },
            child: const Text('OK',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && !_isProcessing) {
                final String? rawValue = barcodes.first.rawValue;
                if (rawValue != null) {
                  _handleQrCode(rawValue);
                }
              }
            },
          ),
          // Scanner frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          // Gallery & Flash buttons
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gallery picker
                GestureDetector(
                  onTap: _pickAndScanImage,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: const huge.HugeIcon(
                      icon: huge.HugeIcons.strokeRoundedImage01,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                // Flash toggle
                GestureDetector(
                  onTap: () => _controller.toggleTorch(),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: ValueListenableBuilder<MobileScannerState>(
                      valueListenable: _controller,
                      builder: (context, state, child) {
                        switch (state.torchState) {
                          case TorchState.on:
                            return const huge.HugeIcon(
                              icon: huge.HugeIcons.strokeRoundedFlash,
                              color: Colors.yellow,
                              size: 24,
                            );
                          case TorchState.off:
                          case TorchState.auto:
                          case TorchState.unavailable:
                            return const huge.HugeIcon(
                              icon: huge.HugeIcons.strokeRoundedFlashOff,
                              color: Colors.white,
                              size: 24,
                            );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Hint text
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Center code in the scanner frame',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
