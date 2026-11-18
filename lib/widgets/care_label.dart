import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../theme/app_theme.dart';

IconData statusIcon(GarmentStatus status) {
  switch (status) {
    case GarmentStatus.closet:
      return Icons.checkroom_rounded;
    case GarmentStatus.dirtyHamper:
      return Icons.shopping_basket_outlined;
    case GarmentStatus.inLaundry:
      return Icons.local_laundry_service_outlined;
    case GarmentStatus.missing:
      return Icons.travel_explore_rounded;
  }
}

/// A garment's status, drawn like the little care label sewn into clothes:
/// a stitched (dashed) border, small caps and an icon. Status is always
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
        painter: _StitchPainter(colors.border),
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
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
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
