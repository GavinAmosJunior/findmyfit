import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/garment_image.dart';
import '../widgets/grouped_section.dart';
import '../theme/app_icons.dart';

/// Clothes that didn't come back. Grouped by laundromat, each group can
/// send that laundromat a ready-made message listing what's missing.
class MissingScreen extends StatelessWidget {
  const MissingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final missing = state.withStatus(GarmentStatus.missing);

    // Group by laundromat so one message covers each place.
    final groups = <String, List<Garment>>{};
    for (final g in missing) {
      final place = state.batchById(g.currentBatchId)?.laundromatName ?? s.laundromat;
      groups.putIfAbsent(place, () => []).add(g);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(s.missing)),
          if (missing.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: AppIcons.allFound,
                title: s.emptyMissingTitle,
                body: s.emptyMissingBody,
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(s.missingSubtitle,
                    style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText)),
              ),
            ),
            for (final entry in groups.entries) ...[
              SliverToBoxAdapter(child: SectionTitle(entry.key)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: entry.value.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _MissingCard(garment: entry.value[i]),
                ),
              ),
              // Own row, so it fits next to long laundromat names on small phones.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: OutlinedButton.icon(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(text: s.askMessage(entry.key, entry.value.map((g) => g.name).toList())),
                    ),
                    icon: const Icon(AppIcons.chat),
                    label: Text(s.askLaundromat),
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
          ],
        ],
      ),
    );
  }
}

class _MissingCard extends StatelessWidget {
  final Garment garment;

  const _MissingCard({required this.garment});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.read(context);
    final batch = state.batchById(garment.currentBatchId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(dimension: 56, child: GarmentImage(garment: garment, iconSize: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(garment.name, style: context.text.titleMedium),
                      if (batch != null)
                        Text(s.sentOn(s.date(batch.createdAt)), style: context.text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final fromBatch = garment.currentBatchId;
                      state.markFound(garment.id);
                      HapticFeedback.mediumImpact();
                      showMessage(context, s.foundMessage(garment.name),
                          actionLabel: s.undo, onAction: () {
                        garment
                          ..status = GarmentStatus.missing
                          ..currentBatchId = fromBatch;
                        state.updateGarment(garment);
                      });
                    },
                    icon: const Icon(AppIcons.check),
                    label: Text(s.foundIt),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: context.colors.error),
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
        ),
      ),
    );
  }
}
