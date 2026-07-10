import 'package:flutter/material.dart';

class ResizableSidebar extends StatefulWidget {
  final Widget child;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;

  const ResizableSidebar({
    super.key,
    required this.child,
    this.initialWidth = 320.0,
    this.minWidth = 240.0,
    this.maxWidth = 480.0,
  });

  @override
  State<ResizableSidebar> createState() => _ResizableSidebarState();
}

class _ResizableSidebarState extends State<ResizableSidebar> {
  late double _width;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.minWidth,
            maxWidth: widget.maxWidth,
          ),
          child: SizedBox(
            width: _width,
            child: widget.child,
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              setState(() {
                _isDragging = true;
              });
            },
            onHorizontalDragUpdate: (details) {
              setState(() {
                _width = (_width + details.delta.dx).clamp(widget.minWidth, widget.maxWidth);
              });
            },
            onHorizontalDragEnd: (_) {
              setState(() {
                _isDragging = false;
              });
            },
            child: Container(
              width: 12,
              color: Colors.transparent,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _isDragging ? 4 : 2,
                  height: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _isDragging 
                        ? colorScheme.primary 
                        : colorScheme.outline.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
