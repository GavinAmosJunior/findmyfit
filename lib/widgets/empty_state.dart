import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A calm placeholder that says what belongs here and how to get started.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 24, 36, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: context.palette.tile, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: context.ink),
            ),
            const SizedBox(height: 22),
            Text(title, style: context.text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              body,
              style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 26),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
