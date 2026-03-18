import 'package:flutter/material.dart';

class Phonepages extends StatefulWidget {
  const Phonepages({super.key});

  @override
  State<Phonepages> createState() => _PhonepagesState();
}

class _PhonepagesState extends State<Phonepages> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Phone Pages'),
      ),
    );
  }
}