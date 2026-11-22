import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

IconData statusIcon(GarmentStatus status) {
  switch (status) {
    case GarmentStatus.closet:
      return AppIcons.closet;
    case GarmentStatus.dirtyHamper:
      return AppIcons.hamper;
    case GarmentStatus.inLaundry:
      return AppIcons.laundry;
    case GarmentStatus.missing:
      return AppIcons.warning;
    case GarmentStatus.lost:
      return AppIcons.missing;
  }
}

/// A garment's status as a small capsule: icon and word, in ink. Only
/// missing is red. Never color alone.
class StatusChip extends StatelessWidget {
  final GarmentStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = context.palette.statusColor(status, context.ink);
    final label = S.of(context).statusLabel(status);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(99)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon(status), size: 14, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(color: color, height: 1.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How a load ended, in one line: "All back" with a check, or "2 missing"
/// in red.
class ResultLabel extends StatelessWidget {
  final String text;
  final bool missing;

  const ResultLabel(this.text, {super.key, this.missing = false});

  @override
  Widget build(BuildContext context) {
    final color = missing ? context.palette.signal : context.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(missing ? AppIcons.warning : AppIcons.checked, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(color: color)),
        ),
      ],
    );
  }
}

/// The big result at the top of a finished check: a disc with a check (or
/// a warning) and the words under it. With [land], it settles into place
/// the first time it shows (a plain fade with Reduce Motion).
class ResultStamp extends StatelessWidget {
  final String text;
  final bool missing;
  final bool land;

  const ResultStamp(this.text, {super.key, this.missing = false, this.land = false});

  @override
  Widget build(BuildContext context) {
    final color = missing ? context.palette.signal : context.ink;
    final stamp = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(missing ? AppIcons.missingFill : AppIcons.check, size: 36, color: context.colors.surface),
        ),
        const SizedBox(height: 14),
        Text(text, textAlign: TextAlign.center, style: context.text.headlineSmall?.copyWith(color: color)),
      ],
    );
    if (!land) return stamp;
    final still = MediaQuery.disableAnimationsOf(context);
    // A rare, happy moment: a short settle from slightly large.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: still ? 200 : 420),
      curve: still ? Curves.linear : Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: still ? child : Transform.scale(scale: 1.18 - 0.18 * t, child: child),
      ),
      child: stamp,
    );
  }
}
