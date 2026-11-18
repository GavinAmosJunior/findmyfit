import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable.dart';
import 'store_sign.dart';

/// A laundromat claim ticket: a painted header band with the place and the
/// ticket number, and a plain white body for what's inside. Solid edges,
/// no perforation.
class Ticket extends StatelessWidget {
  final String title;
  final Color color;

  /// Letter color on the band; defaults to white (ink on mustard).
  final Color? foreground;
  final Widget? trailing;
  final Widget body;
  final VoidCallback? onTap;
  final String semanticLabel;

  const Ticket({
    super.key,
    required this.title,
    required this.color,
    required this.body,
    required this.semanticLabel,
    this.foreground,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onBand = foreground ?? onSignColor(color);
    final ticket = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: context.palette.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: color,
              padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineSmall
                          ?.copyWith(fontSize: 17, height: 1.2, letterSpacing: 1.1, color: onBand),
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), child: body),
          ],
        ),
      ),
    );
    if (onTap == null) return Semantics(container: true, label: semanticLabel, child: ticket);
    return Pressable(label: semanticLabel, onTap: onTap!, child: ticket);
  }
}

/// The ticket number on a mustard plate, like "NO. L-1003".
class TicketNumber extends StatelessWidget {
  final String text;

  const TicketNumber(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: SignColors.mustard, borderRadius: BorderRadius.circular(4)),
      child: Text(
        text.toUpperCase(),
        style: context.text.headlineSmall?.copyWith(fontSize: 13, height: 1.2, letterSpacing: 0.8, color: SignColors.ink),
      ),
    );
  }
}
