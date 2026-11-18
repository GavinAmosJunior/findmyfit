import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/laundry_batch.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/garment_image.dart';
import '../widgets/grouped_section.dart';
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
          SliverAppBar.large(title: Text(s.laundry)),
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
      semanticLabel: '${batch.laundromatName}, ${s.backCount(batch.verifiedCount, batch.totalItems)}',
      onTap: () => BatchScreen.open(context, batch.id),
      top: _TicketHeader(batch: batch),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                for (final g in garments.take(5))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox.square(dimension: 44, child: GarmentImage(garment: g, iconSize: 20)),
                    ),
                  ),
                if (garments.length > 5) Text('+${garments.length - 5}', style: context.text.labelMedium),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
    );
  }
}

/// Laundromat, ticket number and date, printed like a receipt.
class _TicketHeader extends StatelessWidget {
  final LaundryBatch batch;

  const _TicketHeader({required this.batch});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                batch.laundromatName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.headlineSmall?.copyWith(fontSize: 21, letterSpacing: 0.6),
              ),
              const SizedBox(height: 2),
              Text(s.sentOn(s.date(batch.createdAt)), style: context.text.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          s.ticketNo(batch.batchCode.replaceAll('#', '')),
          style: context.text.labelMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: 0.8,
            color: context.palette.thread,
          ),
        ),
      ],
    );
  }
}

/// A finished batch: its ticket with a stamp across it.
class _HistoryTicket extends StatelessWidget {
  final LaundryBatch batch;

  const _HistoryTicket({required this.batch});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final missing = state.stillMissingFrom(batch);
    final palette = context.palette;

    return Ticket(
      semanticLabel: '${batch.laundromatName}, ${s.historySummary(batch.totalItems, missing)}',
      onTap: () => BatchScreen.open(context, batch.id),
      top: _TicketHeader(batch: batch),
      // Wraps the stamp under the summary when both don't fit on one line.
      bottom: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Text(s.historySummary(batch.totalItems, missing), style: context.text.bodySmall),
          missing == 0
              ? Stamp(s.allBack, color: palette.clean.foreground, fontSize: 14)
              : Stamp(s.stampMissing(missing), color: palette.missing.foreground, fontSize: 14),
        ],
      ),
    );
  }
}
