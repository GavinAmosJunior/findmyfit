import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/laundry_batch.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/garment_image.dart';
import '../widgets/grouped_section.dart';
import 'batch_screen.dart';

bool _isToday(DateTime d) {
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

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
                icon: Icons.local_laundry_service_outlined,
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
            if (done.isNotEmpty)
              SliverToBoxAdapter(
                child: GroupedSection(
                  header: s.history.toUpperCase(),
                  children: [
                    for (final b in done)
                      ListTile(
                        title: Text(b.laundromatName),
                        subtitle: Text('${s.date(b.createdAt)} · ${s.historySummary(b.totalItems, state.stillMissingFrom(b))}'),
                        trailing: Icon(
                          state.stillMissingFrom(b) > 0 ? Icons.travel_explore_rounded : Icons.check_circle_rounded,
                          color: state.stillMissingFrom(b) > 0
                              ? context.palette.missing.foreground
                              : context.palette.clean.foreground,
                        ),
                        onTap: () => BatchScreen.open(context, b.id),
                      ),
                  ],
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
    final pickup = batch.pickupDate;
    final pickupToday = pickup != null && _isToday(pickup);
    final dates = [
      s.sentOn(s.date(batch.createdAt)),
      if (pickup != null && !pickupToday) s.pickupOn(s.weekdayDate(pickup)),
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => BatchScreen.open(context, batch.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(batch.laundromatName, style: context.text.titleMedium),
                        const SizedBox(height: 2),
                        Text(dates, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: context.palette.tertiaryText),
                ],
              ),
              if (pickupToday) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: context.palette.laundry.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_available_rounded, size: 16, color: context.palette.laundry.foreground),
                      const SizedBox(width: 6),
                      Text(s.pickupToday,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.palette.laundry.foreground)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
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
                    if (garments.length > 5)
                      Text('+${garments.length - 5}', style: context.text.labelMedium),
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
              Text(s.backCount(batch.verifiedCount, batch.totalItems), style: context.text.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
