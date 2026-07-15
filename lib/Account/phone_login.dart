import 'package:cuqter/Account/otp_screen.dart';
import 'package:cuqter/utils/colors.dart';
import 'package:cuqter/utils/picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  TextEditingController countryCodeController = TextEditingController(text: '+1');
  TextEditingController phoneController = TextEditingController();
  bool _isLoading = false;

  void sendOtp() async {
    final String code = countryCodeController.text.trim();
    final String number = phoneController.text.trim();
    
    if (code.isEmpty || number.isEmpty) {
      showSnackBar('Please enter country code and phone number', context);
      return;
    }
    
    // Sanitize phone number to strictly E.164 format (no spaces, dashes, or brackets)
    String rawPhone = '$code$number'.replaceAll(RegExp(r'[^\d+]'), '');
    if (!rawPhone.startsWith('+')) {
      rawPhone = '+$rawPhone';
    }
    final String phone = rawPhone;

    setState(() {
      _isLoading = true;
    });

    try {
      print('Attempting to send OTP to: $phone');

      if (kIsWeb) {
        // Web requires signInWithPhoneNumber which handles reCAPTCHA automatically
        ConfirmationResult confirmationResult = await FirebaseAuth.instance.signInWithPhoneNumber(phone);
        
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(
                verificationId: '',
                phoneNumber: phone,
                confirmationResult: confirmationResult,
              ),
            ),
          );
        }
      } else {
        // Mobile uses verifyPhoneNumber
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone,
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto-resolution handling
          },
          verificationFailed: (FirebaseAuthException e) {
            setState(() {
              _isLoading = false;
            });
            showSnackBar(e.message ?? 'Verification failed', context);
          },
          codeSent: (String verificationId, int? resendToken) {
            setState(() {
              _isLoading = false;
            });
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtpScreen(
                  verificationId: verificationId,
                  phoneNumber: phone,
                ),
              ),
            );
          },
          timeout: const Duration(seconds: 60),
          codeAutoRetrievalTimeout: (String verificationId) {},
        );
      }
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
        title: const Text('Login with Phone'),
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
                      'Enter Phone Number',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Include your country code (e.g., +1, +91)',
                      style: TextStyle(color: AppColors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: countryCodeController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              label: const Text("Code"),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.phone),
                              label: const Text("Phone Number"),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              hintText: '1234567890',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: sendOtp,
                      child: const Text('Send OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
