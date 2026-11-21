import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/garment_image.dart';
import '../widgets/tags.dart';
import 'closet_screen.dart';
import 'garment_form_screen.dart';

/// Details and actions for one garment, in a bottom sheet.
class GarmentSheet extends StatelessWidget {
  final String garmentId;

  /// The screen that opened the sheet; its tab shows the messages.
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

    // Messages must outlive the sheet, so use the screen behind it.
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
          // The piece itself, large, on its gray tile.
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: AspectRatio(
              aspectRatio: 1.1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GarmentImage(garment: garment, iconSize: 56),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      tooltip: garment.isFavorite ? s.unfavorite : s.favorite,
                      style: IconButton.styleFrom(
                        backgroundColor: context.colors.surface.withValues(alpha: 0.94),
                        foregroundColor: context.ink,
                        minimumSize: const Size(44, 44),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        state.toggleFavorite(garment.id);
                      },
                      icon: Icon(garment.isFavorite ? AppIcons.favorite : AppIcons.favoriteOutline, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(garment.name, style: context.text.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '${s.categoryLabel(garment.category)} · $wear',
            style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText),
          ),
          const SizedBox(height: 12),
          Align(alignment: AlignmentDirectional.centerStart, child: StatusChip(status: garment.status)),
          if (garment.brand != null || garment.notes != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              decoration: BoxDecoration(color: context.palette.tile, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (garment.brand != null) _Detail(label: s.brand, value: garment.brand!),
                  if (garment.notes != null) _Detail(label: s.notes, value: garment.notes!),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          if (garment.status == GarmentStatus.closet) ...[
            FilledButton.icon(
              onPressed: () {
                close();
                wearGarment(outer, garment);
              },
              icon: Icon(garment.category.goesToHamper ? AppIcons.hamper : AppIcons.check, size: 20),
              label: Text(s.woreIt),
            ),
            // Shoes and the like skip the hamper, unless they need a clean.
            if (!garment.category.goesToHamper) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  state.moveToHamper(garment.id);
                  close();
                  showMessage(outer, s.movedToHamper(garment.name));
                },
                icon: const Icon(AppIcons.hamper, size: 20),
                label: Text(s.putInHamper),
              ),
            ],
          ],
          // A missing piece can turn up again, from wherever it's opened.
          if (garment.status == GarmentStatus.missing)
            FilledButton.icon(
              onPressed: () {
                final fromBatch = garment.currentBatchId;
                state.markFound(garment.id);
                HapticFeedback.mediumImpact();
                close();
                showMessage(outer, s.foundMessage(garment.name), actionLabel: s.undo, onAction: () {
                  final g = state.garmentById(garment.id);
                  if (g == null) return;
                  g
                    ..status = GarmentStatus.missing
                    ..currentBatchId = fromBatch;
                  state.updateGarment(g);
                });
              },
              icon: const Icon(AppIcons.check, size: 20),
              label: Text(s.foundIt),
            ),
          if (garment.status == GarmentStatus.dirtyHamper)
            OutlinedButton.icon(
              onPressed: () {
                state.moveToCloset(garment.id);
                close();
              },
              icon: const Icon(AppIcons.closetFill, size: 20),
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
                  icon: const Icon(AppIcons.edit, size: 20),
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
                  icon: const Icon(AppIcons.delete, size: 20),
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
