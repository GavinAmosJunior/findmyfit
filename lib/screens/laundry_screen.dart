import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../models/laundry_batch.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/store_sign.dart';
import '../widgets/garment_image.dart';
import '../widgets/grouped_section.dart';
import '../widgets/tags.dart';
import '../widgets/ticket.dart';
import 'batch_screen.dart';
import '../theme/app_icons.dart';

/// Batches out at the laundromat, plus a short history.
class LaundryScreen extends StatelessWidget {
  const LaundryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final active = state.activeBatches;
    final done = state.completedBatches.take(10).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          StoreSign(title: s.laundry, color: SignColors.green),
          // Breathing room under the checker strip.
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (active.isEmpty && done.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: AppIcons.laundry,
                title: s.emptyLaundryTitle,
                body: s.emptyLaundryBody,
              ),
            )
          else ...[
            if (active.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionTitle(s.atLaundryNow)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList.separated(
                  itemCount: active.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _ActiveBatchCard(batch: active[i]),
                ),
              ),
            ] else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Text(s.emptyLaundryBody, style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText)),
                ),
              ),
            if (done.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionTitle(s.history)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: done.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _HistoryTicket(batch: done[i]),
                ),
              ),
            ],
            SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
          ],
        ],
      ),
    );
  }
}

class _ActiveBatchCard extends StatelessWidget {
  final LaundryBatch batch;

  const _ActiveBatchCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final garments = state.garmentsInBatch(batch);

    return Ticket(
      title: batch.laundromatName,
      color: SignColors.blue,
      trailing: TicketNumber(s.ticketNo(batch.batchCode.replaceAll('#', ''))),
      semanticLabel: '${batch.laundromatName}, ${s.backCount(batch.verifiedCount, batch.totalItems)}',
      onTap: () => BatchScreen.open(context, batch.id),
      body: Row(
        children: [
          _Porthole(garments: garments),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.sentOn(s.date(batch.createdAt)), style: context.text.bodySmall),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: batch.progress,
                    minHeight: 6,
                    backgroundColor: context.palette.separator,
                    color: context.palette.clean.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(s.backCount(batch.verifiedCount, batch.totalItems), style: context.text.labelMedium),
                    ),
                    Icon(AppIcons.chevron, size: 16, color: context.palette.tertiaryText),
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

/// A washing machine door: a steel ring with the first piece inside the
/// glass, and a count when more are in the load.
class _Porthole extends StatelessWidget {
  final List<Garment> garments;

  const _Porthole({required this.garments});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox.square(
      dimension: 68,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(shape: BoxShape.circle, color: palette.steel),
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(shape: BoxShape.circle, color: palette.card),
              child: ClipOval(
                child: garments.isEmpty
                    ? ColoredBox(color: palette.separator)
                    : GarmentImage(garment: garments.first, iconSize: 22),
              ),
            ),
          ),
          if (garments.length > 1)
            Positioned(
              right: -4,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: SignColors.ink, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '+${garments.length - 1}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A finished batch: its ticket with a status plate.
class _HistoryTicket extends StatelessWidget {
  final LaundryBatch batch;

  const _HistoryTicket({required this.batch});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final missing = state.stillMissingFrom(batch);

    return Ticket(
      title: batch.laundromatName,
      color: SignColors.ink,
      trailing: TicketNumber(s.ticketNo(batch.batchCode.replaceAll('#', ''))),
      semanticLabel: '${batch.laundromatName}, ${s.historySummary(batch.totalItems, missing)}',
      onTap: () => BatchScreen.open(context, batch.id),
      // Wraps the plate under the summary when both don't fit on one line.
      body: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.sentOn(s.date(batch.createdAt)), style: context.text.bodySmall),
              Text(s.historySummary(batch.totalItems, missing), style: context.text.bodyMedium),
            ],
          ),
          missing == 0
              ? StatusPlate(s.allBack, color: SignColors.green, icon: AppIcons.check)
              : StatusPlate(s.stampMissing(missing), color: SignColors.red),
        ],
      ),
    );
  }
}
