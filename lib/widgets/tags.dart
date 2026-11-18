import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

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

/// The sign color for a status: closet blue, hamper mustard, laundry
/// green, missing red. Same as the tab the piece lives in.
Color statusSignColor(GarmentStatus status) {
  switch (status) {
    case GarmentStatus.closet:
      return SignColors.blue;
    case GarmentStatus.dirtyHamper:
      return SignColors.mustard;
    case GarmentStatus.inLaundry:
      return SignColors.green;
    case GarmentStatus.missing:
      return SignColors.red;
  }
}

/// A garment's status as a small painted chip: icon and word on a tint of
/// its color. Never color alone.
class StatusChip extends StatelessWidget {
  final GarmentStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = context.palette.forStatus(status);
    final label = S.of(context).statusLabel(status);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
        decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(6)),
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
                style: TextStyle(fontSize: 13, height: 1.15, fontWeight: FontWeight.w600, color: colors.foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dry cleaner's hang tag: a white card with an ink outline, a punched
/// hole and the name in sign letters. Used for names on the Fits rails
/// and on missing clothes.
class HangTag extends StatelessWidget {
  final String text;
  final double fontSize;

  const HangTag(this.text, {super.key, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
      decoration: BoxDecoration(
        color: context.palette.card,
        border: Border.all(color: ink, width: 1.5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ink, width: 1.5)),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.headlineSmall?.copyWith(fontSize: fontSize, height: 1.15, letterSpacing: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}

/// A straight enamel sign plate: solid color, white sign letters, like
/// "OPEN" on a laundromat door. With [land], it drops into place the first
/// time it shows (a plain fade with Reduce Motion).
class StatusPlate extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final double fontSize;
  final bool land;

  const StatusPlate(this.text, {super.key, required this.color, this.icon, this.fontSize = 13, this.land = false});

  @override
  Widget build(BuildContext context) {
    final plate = Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.7, vertical: fontSize * 0.35),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(fontSize * 0.4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize * 1.1, color: Colors.white),
            SizedBox(width: fontSize * 0.35),
          ],
          Flexible(
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.headlineSmall?.copyWith(
                fontSize: fontSize,
                height: 1.15,
                letterSpacing: fontSize * 0.09,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    if (!land) return plate;
    final still = MediaQuery.disableAnimationsOf(context);
    // A rare, celebratory moment: a short drop with a little settle.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: still ? 200 : 380),
      curve: still ? Curves.linear : Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: still ? child : Transform.scale(scale: 1.15 - 0.15 * t, child: child),
      ),
      child: plate,
    );
  }
}
