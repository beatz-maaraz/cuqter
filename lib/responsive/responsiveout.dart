import 'package:cuqter/responsive/phonepages.dart';
import 'package:cuqter/responsive/webpage.dart';
import 'package:flutter/material.dart';

class Responsiveout extends StatefulWidget {
  final Widget Phonepages;
  final Widget Webpage;


  const Responsiveout({super.key, required this.Phonepages, required this.Webpage});

  @override
  State<Responsiveout> createState() => _ResponsiveoutState();
}

class _ResponsiveoutState extends State<Responsiveout> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return Webpage();
        } else {
          return Phonepages();
        }
      },
    );
  }
}