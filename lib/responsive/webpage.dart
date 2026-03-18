import 'package:flutter/material.dart';

class Webpage extends StatefulWidget {
  const Webpage({super.key});

  @override
  State<Webpage> createState() => _WebpageState();
}

class _WebpageState extends State<Webpage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Webpage'),
      ),
    );
  }
}