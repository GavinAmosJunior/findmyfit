import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A choice capsule: solid ink when selected, a gray tile when not.
///
/// Drawn here rather than with Material's chips, which size their label
/// before the app's font has loaded and then clip it.
class Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const Pill({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? context.colors.surface : context.ink;
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: still ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 44),
          padding: EdgeInsets.fromLTRB(icon == null ? 18 : 14, 10, 18, 10),
          decoration: BoxDecoration(
            color: selected ? context.ink : context.palette.tile,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                maxLines: 1,
                style: context.text.titleSmall?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
