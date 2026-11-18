import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/store_sign.dart';
import '../widgets/garment_image.dart';
import '../widgets/tags.dart';
import '../widgets/ticket.dart';
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
      // Loads with no laundromat set share one group.
      final place = state.batchById(g.currentBatchId)?.laundromatName ?? '';
      groups.putIfAbsent(place, () => []).add(g);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          StoreSign(title: s.missing, color: SignColors.ink),
          // Breathing room under the checker strip.
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
            // One ticket per laundromat: what's missing from there, and a
            // ready-made message to ask about it.
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList.separated(
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  final entry = groups.entries.elementAt(i);
                  return _MissingTicket(place: entry.key, garments: entry.value);
                },
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
          ],
        ],
      ),
    );
  }
}

class _MissingTicket extends StatelessWidget {
  final String place;
  final List<Garment> garments;

  const _MissingTicket({required this.place, required this.garments});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final title = place.isEmpty ? s.laundromat : place;
    return Ticket(
      title: title,
      color: SignColors.red,
      trailing: TicketNumber(s.stampMissing(garments.length)),
      semanticLabel: '$title, ${s.stampMissing(garments.length)}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, g) in garments.indexed) ...[
            if (i > 0) const Divider(height: 28),
            _MissingPiece(garment: g),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: s.askMessage(place, garments.map((g) => g.name).toList())),
            ),
            icon: const Icon(AppIcons.chat),
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
    final palette = context.palette;

    return Column(
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
                  HangTag(garment.name, fontSize: 13),
                  if (batch != null) ...[
                    const SizedBox(height: 6),
                    Text('${s.loadName(batch)} · ${s.sentOn(s.date(batch.createdAt))}', style: context.text.bodySmall),
                  ],
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
                  showMessage(context, s.foundMessage(garment.name), actionLabel: s.undo, onAction: () {
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.missing.foreground,
                  backgroundColor: palette.missing.background,
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
