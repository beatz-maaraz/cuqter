import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cuqter/modules/user.dart' as model;
import 'package:cuqter/utils/colors.dart';
import 'package:cuqter/utils/picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final ConfirmationResult? confirmationResult;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.confirmationResult,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  TextEditingController otpController = TextEditingController();
  bool _isLoading = false;

  void verifyOtp() async {
    final String otp = otpController.text.trim();

    if (otp.isEmpty) {
      showSnackBar('Please enter the OTP', context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCred;
      
      if (widget.confirmationResult != null) {
        // Web flow
        userCred = await widget.confirmationResult!.confirm(otp);
      } else {
        // Mobile flow
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: widget.verificationId,
          smsCode: otp,
        );
        userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      if (userCred.user != null) {
        // Check if user exists in our Firestore database
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCred.user!.uid)
            .get();

        if (!userDoc.exists) {
          // Create default profile for the phone user
          String defaultUsername = 'user_${userCred.user!.uid.substring(0, 8)}'.toLowerCase();
          
          model.user newUser = model.user(
            name: widget.phoneNumber,
            email: '',
            password: '',
            uid: userCred.user!.uid,
            username: defaultUsername,
            profilepic: 'assets/profile/BOY (1).jpg',
          );

          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCred.user!.uid)
              .set(newUser.toJson());
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          // main.dart's authStateChanges will automatically navigate to NavigationScreen
          // We can pop until root just in case, but authStream usually handles it
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      showSnackBar(e.message ?? 'Invalid OTP', context);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      showSnackBar(e.toString(), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SizedBox(
                width: 300,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Enter OTP',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sent to ${widget.phoneNumber}',
                      style: const TextStyle(color: AppColors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.security),
                        label: const Text("OTP Code"),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        hintText: '123456',
                      ),
                      maxLength: 6,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: verifyOtp,
                      child: const Text('Verify & Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
