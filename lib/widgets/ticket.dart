import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable.dart';

/// A paper laundry ticket: the slip a laundromat hands you. A top part
/// (where and when), a dashed tear line with notches cut into both sides,
/// and a bottom part (what's inside).
class Ticket extends StatelessWidget {
  final Widget top;
  final Widget bottom;
  final VoidCallback? onTap;
  final String semanticLabel;

  const Ticket({super.key, required this.top, required this.bottom, required this.semanticLabel, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ticket = Container(
      decoration: BoxDecoration(color: context.palette.card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: top),
          const _TearLine(),
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 14), child: bottom),
        ],
      ),
    );
    if (onTap == null) return ticket;
    return Pressable(label: semanticLabel, onTap: onTap!, child: ticket);
  }
}

/// Dashed perforation with a half-circle notch on each edge. The notches
/// are circles in the page's background color, so the ticket looks cut.
class _TearLine extends StatelessWidget {
  const _TearLine();

  static const _notch = 9.0;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    Widget notch() => Container(
          width: _notch * 2,
          height: _notch * 2,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        );
    return SizedBox(
      height: _notch * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: _notch + 6,
            right: _notch + 6,
            child: CustomPaint(painter: _DashPainter(context.palette.separator)),
          ),
          Positioned(left: -_notch, top: 0, child: notch()),
          Positioned(right: -_notch, top: 0, child: notch()),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;

  _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, y), Offset((x + 4.5).clamp(0, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// A rubber stamp, slightly crooked: a double border and condensed
/// capitals in ink. With [slam], it lands with a thump the first time it
/// appears (skipped with Reduce Motion).
class Stamp extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  final bool slam;

  const Stamp(this.text, {super.key, required this.color, this.fontSize = 16, this.slam = false});

  @override
  Widget build(BuildContext context) {
    final ink = color.withValues(alpha: 0.88);
    final stamp = Transform.rotate(
      angle: -0.12,
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          border: Border.all(color: ink, width: 2.2),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: fontSize * 0.55, vertical: fontSize * 0.18),
          decoration: BoxDecoration(
            border: Border.all(color: ink, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            style: context.text.headlineSmall?.copyWith(
              fontSize: fontSize,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: fontSize * 0.12,
              color: ink,
            ),
          ),
        ),
      ),
    );
    if (!slam || MediaQuery.disableAnimationsOf(context)) return stamp;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 1.8 - 0.8 * t, child: child),
      ),
      child: stamp,
    );
  }
}
