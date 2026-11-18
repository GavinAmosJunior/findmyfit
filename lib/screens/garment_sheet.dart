import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/tags.dart';
import '../widgets/dialogs.dart';
import '../widgets/garment_image.dart';
import 'closet_screen.dart';
import 'garment_form_screen.dart';
import '../theme/app_icons.dart';
import '../widgets/store_sign.dart';

/// Details and actions for one garment, in a bottom sheet.
class GarmentSheet extends StatelessWidget {
  final String garmentId;

  /// The screen that opened the sheet; its tab shows the snackbars.
  final BuildContext origin;

  const GarmentSheet({super.key, required this.garmentId, required this.origin});

  static Future<void> show(BuildContext context, String garmentId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      clipBehavior: Clip.antiAlias,
      builder: (_) => GarmentSheet(garmentId: garmentId, origin: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final garment = state.garmentById(garmentId);
    if (garment == null) return const SizedBox(height: 120);

    // Snackbars must outlive the sheet, so use the screen behind it.
    final outer = origin;

    void close() => Navigator.of(context).pop();

    final wear = garment.lastWornAt == null
        ? (garment.wearCount == 0 ? s.neverWorn : s.timesWorn(garment.wearCount))
        : '${s.timesWorn(garment.wearCount)} · ${s.lastWorn(s.date(garment.lastWornAt!))}';

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The piece's name on a sign in its status color.
          SheetSign(
            title: garment.name,
            subtitle: s.categoryLabel(garment.category),
            color: statusSignColor(garment.status),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GarmentImage(garment: garment, iconSize: 56),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: IconButton(
                            tooltip: garment.isFavorite ? s.unfavorite : s.favorite,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.94),
                              minimumSize: const Size(44, 44),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              state.toggleFavorite(garment.id);
                            },
                            icon: Icon(
                              garment.isFavorite ? AppIcons.favorite : AppIcons.favoriteOutline,
                              color: garment.isFavorite ? SignColors.red : SignColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip(status: garment.status),
                    Text(wear, style: context.text.bodySmall),
                  ],
                ),
                if (garment.brand != null || garment.notes != null) ...[
                  const SizedBox(height: 16),
                  // Brand and notes in one card, like the details on a care tag.
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
                    decoration: BoxDecoration(color: context.palette.card, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (garment.brand != null) _Detail(label: s.brand, value: garment.brand!),
                        if (garment.notes != null) _Detail(label: s.notes, value: garment.notes!),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (garment.status == GarmentStatus.closet)
                  FilledButton.icon(
                    onPressed: () {
                      close();
                      wearGarment(outer, garment);
                    },
                    icon: const Icon(AppIcons.hamper),
                    label: Text(s.woreIt),
                  ),
                if (garment.status == GarmentStatus.dirtyHamper)
                  OutlinedButton.icon(
                    onPressed: () {
                      state.moveToCloset(garment.id);
                      close();
                    },
                    icon: const Icon(AppIcons.closetFill),
                    label: Text(s.putBackClean),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          close();
                          GarmentFormScreen.openEdit(outer, garment);
                        },
                        icon: const Icon(AppIcons.edit),
                        label: Text(s.edit),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: context.palette.signal),
                        onPressed: () {
                          final index = state.removeGarment(garment.id);
                          close();
                          showMessage(
                            outer,
                            s.removed(garment.name),
                            actionLabel: s.undo,
                            onAction: () => state.restoreGarment(garment, index),
                          );
                        },
                        icon: const Icon(AppIcons.delete),
                        label: Text(s.delete),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;

  const _Detail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: context.text.labelSmall?.copyWith(letterSpacing: 1.1)),
          const SizedBox(height: 2),
          Text(value, style: context.text.bodyLarge),
        ],
      ),
    );
  }
}
