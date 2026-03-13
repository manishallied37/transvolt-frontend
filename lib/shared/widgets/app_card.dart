import 'package:flutter/material.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  double scale = 1.0;

  void _tapDown(TapDownDetails details) {
    setState(() {
      scale = 0.97;
    });
  }

  void _tapUp(TapUpDetails details) {
    setState(() {
      scale = 1.0;
    });
  }

  void _tapCancel() {
    setState(() {
      scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 120),

      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),

        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onTap,
          onTapDown: _tapDown,
          onTapUp: _tapUp,
          onTapCancel: _tapCancel,

          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
