import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart' as huge;

void main() {
  testWidgets('check HugeIcon widget', (tester) async {
    final widget = huge.HugeIcon(
      icon: huge.HugeIcons.strokeRoundedChat01,
      color: Colors.blue,
      size: 24,
    );
    expect(widget.icon, huge.HugeIcons.strokeRoundedChat01);
  });
}
