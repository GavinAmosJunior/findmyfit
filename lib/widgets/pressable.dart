import 'package:flutter/material.dart';

/// A tappable surface that shrinks a little under your finger, the way
/// iOS photos and cards respond, instead of showing a ripple.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  /// Read by screen readers, since the child is often just a picture.
  final String label;

  const Pressable({super.key, required this.child, required this.onTap, required this.label});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: _down && !still ? 0.96 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _down ? 0.85 : 1,
            duration: const Duration(milliseconds: 140),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
