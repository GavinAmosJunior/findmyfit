import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/garment_image.dart';
import '../widgets/pressable.dart';
import 'garment_sheet.dart';

/// Clothes that didn't come back. Grouped by laundromat, each group can
/// send that laundromat a ready-made message listing what's missing.
/// Opened from the Laundry tab.
class MissingScreen extends StatelessWidget {
  const MissingScreen({super.key});

  static Future<void> open(BuildContext context, {bool replace = false}) {
    final route = MaterialPageRoute<void>(builder: (_) => const MissingScreen());
    final nav = Navigator.of(context);
    return replace ? nav.pushReplacement(route) : nav.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final missing = state.withStatus(GarmentStatus.missing);

    // Group by laundromat so one message covers each place.
    final groups = <String, List<Garment>>{};
    for (final g in missing) {
      // Loads with no laundromat set share one group.
      final place = state.batchById(g.currentBatchId)?.laundromatName ?? '';
      groups.putIfAbsent(place, () => []).add(g);
    }

    return Scaffold(
      appBar: AppBar(title: BarTitle(s.missing, subtitle: missing.isEmpty ? null : s.missingSubtitle)),
      body: missing.isEmpty
          ? EmptyState(icon: AppIcons.allFound, title: s.emptyMissingTitle, body: s.emptyMissingBody)
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final entry = groups.entries.elementAt(i);
                return _PlaceCard(place: entry.key, garments: entry.value);
              },
            ),
    );
  }
}

/// One laundromat: what's missing from there, and a ready-made message to
/// ask about it.
class _PlaceCard extends StatelessWidget {
  final String place;
  final List<Garment> garments;

  const _PlaceCard({required this.place, required this.garments});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final title = place.isEmpty ? s.laundromat : place;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(color: context.palette.tile, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                ),
                const SizedBox(width: 8),
                Text(
                  s.stampMissing(garments.length),
                  style: context.text.labelMedium?.copyWith(color: context.palette.signal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final (i, g) in garments.indexed) ...[if (i > 0) const Divider(height: 28), _MissingPiece(garment: g)],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(backgroundColor: context.colors.surface),
            onPressed: () =>
                SharePlus.instance.share(ShareParams(text: s.askMessage(place, garments.map((g) => g.name).toList()))),
            icon: const Icon(AppIcons.chat, size: 20),
            label: Text(s.askLaundromat),
          ),
        ],
      ),
    );
  }
}

class _MissingPiece extends StatelessWidget {
  final Garment garment;

  const _MissingPiece({required this.garment});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.read(context);
    final batch = state.batchById(garment.currentBatchId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tap the piece for its details: edit it, or delete it.
        Pressable(
          label: garment.name,
          onTap: () => GarmentSheet.show(context, garment.id),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox.square(
                  dimension: 64,
                  child: GarmentImage(garment: garment, iconSize: 26, backdrop: context.colors.surface),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(garment.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                    if (batch != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${s.loadName(batch)} · ${s.sentOn(s.date(batch.createdAt))}',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(AppIcons.chevron, size: 14, color: context.palette.tertiaryText),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(44, 46)),
                onPressed: () {
                  final fromBatch = garment.currentBatchId;
                  state.markFound(garment.id);
                  HapticFeedback.mediumImpact();
                  showMessage(
                    context,
                    s.foundMessage(garment.name),
                    actionLabel: s.undo,
                    onAction: () {
                      garment
                        ..status = GarmentStatus.missing
                        ..currentBatchId = fromBatch;
                      state.updateGarment(garment);
                    },
                  );
                },
                icon: const Icon(AppIcons.check, size: 18),
                label: Text(s.foundIt),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 46),
                  foregroundColor: context.palette.signal,
                  backgroundColor: context.colors.surface,
                ),
                onPressed: () async {
                  final ok = await confirmAction(
                    context,
                    title: s.lostTitle(garment.name),
                    body: s.lostBody,
                    confirmLabel: s.delete,
                    cancelLabel: s.cancel,
                    destructive: true,
                  );
                  if (ok) state.markLost(garment.id);
                },
                child: Text(s.lostForGood),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
