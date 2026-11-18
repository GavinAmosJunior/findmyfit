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
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: GarmentImage(garment: garment, iconSize: 56),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(garment.name, style: context.text.headlineSmall)),
              IconButton(
                tooltip: garment.isFavorite ? s.unfavorite : s.favorite,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  state.toggleFavorite(garment.id);
                },
                icon: Icon(
                  garment.isFavorite ? AppIcons.favorite : AppIcons.favoriteOutline,
                  color: garment.isFavorite ? const Color(0xFFE11D48) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(status: garment.status),
              Text(s.categoryLabel(garment.category), style: context.text.bodyMedium),
            ],
          ),
          const SizedBox(height: 10),
          Text(wear, style: context.text.bodySmall),
          if (garment.brand != null || garment.notes != null) ...[
            const SizedBox(height: 16),
            if (garment.brand != null) _Detail(label: s.brand, value: garment.brand!),
            if (garment.notes != null) _Detail(label: s.notes, value: garment.notes!),
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
                  style: TextButton.styleFrom(foregroundColor: context.colors.error),
                  onPressed: () {
                    final index = state.removeGarment(garment.id);
                    close();
                    showMessage(outer, s.removed(garment.name),
                        actionLabel: s.undo, onAction: () => state.restoreGarment(garment, index));
                  },
                  icon: const Icon(AppIcons.delete),
                  label: Text(s.delete),
                ),
              ),
            ],
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
          Text(label, style: context.text.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: context.text.bodyLarge),
        ],
      ),
    );
  }
}
