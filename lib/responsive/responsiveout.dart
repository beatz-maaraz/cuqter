import 'package:flutter/material.dart';

class Responsiveout extends StatefulWidget {
  final Widget phonepages;
  final Widget webpage;

  const Responsiveout({
    super.key,
    required this.phonepages,
    required this.webpage,
  });

  @override
  State<Responsiveout> createState() => _ResponsiveoutState();
}

class _ResponsiveoutState extends State<Responsiveout> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return widget.webpage;
        } else {
          return widget.phonepages;
        }
      },
    );
  }
}
