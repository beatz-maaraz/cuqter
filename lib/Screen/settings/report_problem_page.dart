import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String _selectedReportCategory = 'Bug Report';
  bool _isSubmitting = false;

  final List<String> _reportCategories = [
    'Bug Report',
    'Feature Request',
    'Interface Layout Issue',
    'Account & Privacy Issue',
    'General Feedback'
  ];

  @override
  void initState() {
    super.initState();
    // Prefill user email automatically for support form
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Log report to Firestore for database records
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('support_reports').add({
        'category': _selectedReportCategory,
        'email': _emailController.text.trim(),
        'description': _descController.text.trim(),
        'userId': user?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging report to Firestore: $e');
    }

    // 2. Launch email client directed to user email inbox
    try {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: 'smahendran6317@gmail.com',
        query: _encodeQueryParameters({
          'subject': 'Cuqter Support: $_selectedReportCategory',
          'body': 'User Email: ${_emailController.text.trim()}\n\nDescription:\n${_descController.text.trim()}',
        }),
      );
      
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      }
    } catch (e) {
      debugPrint('Error launching email client: $e');
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      _descController.clear();
      _showSuccessDialog();
    }
  }

  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  void _showSuccessDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Report Submitted!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Thank you for helping us improve Cuqter! Our development team has received your feedback and will review it shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), height: 1.4),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                  },
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Report a Problem',
          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: _isSubmitting
          ? _buildSubmittingState(colorScheme)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('SELECT CATEGORY'),
                    const SizedBox(height: 10),
                    _buildDropdownField(colorScheme),
                    const SizedBox(height: 24),
                    _buildSectionLabel('YOUR EMAIL'),
                    const SizedBox(height: 10),
                    _buildEmailField(colorScheme),
                    const SizedBox(height: 24),
                    _buildSectionLabel('PROBLEM DETAILS & FEEDBACK'),
                    const SizedBox(height: 10),
                    _buildDetailsField(colorScheme),
                    const SizedBox(height: 36),
                    _buildSubmitButton(colorScheme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: colorScheme.onSurface.withValues(alpha: 0.45),
      ),
    );
  }

  Widget _buildDropdownField(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.06)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: _selectedReportCategory,
          icon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurface.withValues(alpha: 0.5)),
          decoration: const InputDecoration(border: InputBorder.none),
          items: _reportCategories.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: TextStyle(color: colorScheme.onSurface, fontSize: 14)),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedReportCategory = newValue!;
            });
          },
        ),
      ),
    );
  }

  Widget _buildEmailField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Enter your email address',
        hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4)),
        filled: true,
        fillColor: colorScheme.onSurface.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please provide your email address';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please provide a valid email address';
        }
        return null;
      },
    );
  }

  Widget _buildDetailsField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _descController,
      keyboardType: TextInputType.multiline,
      maxLines: 8,
      minLines: 4,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Explain the issue in detail (e.g. how it happened, steps to reproduce, or feedback on what to change)...',
        hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4)),
        filled: true,
        fillColor: colorScheme.onSurface.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please explain the issue or provide feedback';
        }
        if (value.trim().length < 10) {
          return 'Please describe the problem with more details (minimum 10 characters)';
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 2,
        ),
        onPressed: _submitReport,
        child: const Text(
          'Submit Report',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildSubmittingState(ColorScheme colorScheme) {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              'Sending Report...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Uploading report details securely to our support queue',
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
