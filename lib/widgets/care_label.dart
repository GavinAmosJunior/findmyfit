import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../theme/app_theme.dart';
import '../theme/app_icons.dart';

IconData statusIcon(GarmentStatus status) {
  switch (status) {
    case GarmentStatus.closet:
      return AppIcons.closetFill;
    case GarmentStatus.dirtyHamper:
      return AppIcons.hamper;
    case GarmentStatus.inLaundry:
      return AppIcons.laundry;
    case GarmentStatus.missing:
      return AppIcons.missingFill;
  }
}

/// A garment's status, drawn like the little care label sewn into clothes:
/// a stitched (dashed) border, a short word and an icon. Status is always
/// shown as icon + word, never color alone.
class CareLabel extends StatelessWidget {
  final GarmentStatus status;

  const CareLabel({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = context.palette.forStatus(status);
    final label = S.of(context).statusLabel(status);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: _StitchPainter(colors.border),
        child: Container(
          padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: _shape,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon(status), size: 14, color: colors.foreground),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Square-ish top, rounder bottom — like a label folded over a seam.
const _shape = BorderRadius.only(
  topLeft: Radius.circular(3),
  topRight: Radius.circular(3),
  bottomLeft: Radius.circular(7),
  bottomRight: Radius.circular(7),
);

class _StitchPainter extends CustomPainter {
  final Color color;

  _StitchPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _shape.toRRect(Offset.zero & size).deflate(0.5);
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 5) {
        canvas.drawPath(metric.extractPath(d, d + 2.6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_StitchPainter old) => old.color != color;
}

/// A woven name label, like the one sewn into a collar: condensed capitals
/// on a plain tag, stitched on with the red thread. The app's signature;
/// use it for names and a few headings, not everywhere.
class WovenLabel extends StatelessWidget {
  final String text;
  final double fontSize;

  const WovenLabel(this.text, {super.key, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _StitchPainter(context.palette.thread),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 4),
        decoration: BoxDecoration(color: context.palette.card, borderRadius: _shape),
        child: Text(
          text.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.headlineSmall?.copyWith(
            fontSize: fontSize,
            height: 1.1,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}
