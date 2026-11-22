import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../models/laundry_batch.dart';
import '../state/app_scope.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/garment_image.dart';
import '../widgets/pressable.dart';
import '../widgets/tags.dart';
import 'batch_screen.dart';
import 'missing_screen.dart';

/// Loads out at the laundromat, anything that didn't come back, and a
/// short history.
class LaundryScreen extends StatelessWidget {
  const LaundryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final active = state.activeBatches;
    final done = state.completedBatches.take(10).toList();
    final missing = state.countOf(GarmentStatus.missing);
    final lost = state.countOf(GarmentStatus.lost);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          LargeTitle(title: s.laundry),
          if (active.isEmpty && done.isEmpty && missing == 0 && lost == 0)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: AppIcons.laundry, title: s.emptyLaundryTitle, body: s.emptyLaundryBody),
            )
          else ...[
            // Missing comes first: it's the one thing here that needs you.
            if (missing > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: _MissingCard(count: missing),
                ),
              )
            else if (lost > 0)
              // Nothing to chase, but the lost pieces are still kept here.
              SliverToBoxAdapter(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: Icon(AppIcons.missing, color: context.palette.secondaryText),
                  title: Text(s.lostSection),
                  trailing: Text('$lost', style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText)),
                  onTap: () => MissingScreen.open(context),
                ),
              ),
            if (active.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionTitle(s.atLaundryNow)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverList.separated(
                  itemCount: active.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _LoadCard(batch: active[i]),
                ),
              ),
            ] else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    s.emptyLaundryBody,
                    style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText),
                  ),
                ),
              ),
            if (done.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionTitle(s.history)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: DecoratedSliver(
                  decoration: BoxDecoration(color: context.palette.tile, borderRadius: BorderRadius.circular(22)),
                  sliver: SliverList.separated(
                    itemCount: done.length,
                    separatorBuilder: (_, _) => const Divider(indent: 18),
                    itemBuilder: (context, i) => _HistoryRow(batch: done[i]),
                  ),
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

/// "2 missing", in the app's one color, leading to the Missing screen.
class _MissingCard extends StatelessWidget {
  final int count;

  const _MissingCard({required this.count});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final signal = context.palette.signal;
    return Pressable(
      label: '${s.stampMissing(count)}. ${s.missingSubtitle}',
      onTap: () => MissingScreen.open(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        decoration: BoxDecoration(color: signal.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(22)),
        child: Row(
          children: [
            Icon(AppIcons.warning, size: 28, color: signal),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.stampMissing(count), style: context.text.titleMedium?.copyWith(color: signal)),
                  Text(s.askHint, style: context.text.bodySmall),
                ],
              ),
            ),
            Icon(AppIcons.chevron, size: 16, color: signal),
          ],
        ),
      ),
    );
  }
}

/// A load out now: its name, the clothes in it, and how many are back.
class _LoadCard extends StatelessWidget {
  final LaundryBatch batch;

  const _LoadCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final garments = state.garmentsInBatch(batch);

    return Pressable(
      label: '${s.loadName(batch)}, ${s.backCount(batch.verifiedCount, batch.totalItems)}',
      onTap: () => BatchScreen.open(context, batch.id),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        decoration: BoxDecoration(color: context.palette.tile, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.loadName(batch), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                      Text(s.loadLine(batch), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                    ],
                  ),
                ),
                // A nicknamed load still shows its number.
                if (batch.hasNickname)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.ink.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(s.ticketNo('${batch.number}'), style: context.text.labelMedium?.copyWith(color: context.ink)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _Thumbs(garments: garments),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: batch.progress, minHeight: 4),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.backCount(batch.verifiedCount, batch.totalItems),
                    style: context.text.labelMedium?.copyWith(color: context.ink),
                  ),
                ),
                Icon(AppIcons.chevron, size: 16, color: context.palette.secondaryText),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The clothes in a load as a row of overlapping circles, then a count.
class _Thumbs extends StatelessWidget {
  final List<Garment> garments;

  const _Thumbs({required this.garments});

  static const _size = 46.0;
  static const _step = 34.0;
  static const _shown = 5;

  @override
  Widget build(BuildContext context) {
    final extra = garments.length - _shown;
    final shown = garments.take(_shown).toList();
    final count = shown.length + (extra > 0 ? 1 : 0);
    final ring = context.palette.tile;

    Widget circle(Widget child) => Container(
      width: _size,
      height: _size,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
      child: ClipOval(child: child),
    );

    return ExcludeSemantics(
      child: SizedBox(
        height: _size,
        width: count == 0 ? 0 : _size + _step * (count - 1),
        child: Stack(
          children: [
            for (final (i, g) in shown.indexed)
              Positioned(
                left: _step * i,
                child: circle(GarmentImage(garment: g, iconSize: 18, backdrop: context.colors.surface)),
              ),
            if (extra > 0)
              Positioned(
                left: _step * shown.length,
                child: circle(
                  ColoredBox(
                    color: context.ink,
                    child: Center(
                      child: Text('+$extra', style: context.text.labelMedium?.copyWith(color: context.colors.surface)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A finished load in the history list, with how it ended.
class _HistoryRow extends StatelessWidget {
  final LaundryBatch batch;

  const _HistoryRow({required this.batch});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final missing = AppScope.of(context).stillMissingFrom(batch);

    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        label: '${s.loadName(batch)}, ${s.historySummary(batch.totalItems, missing)}',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => BatchScreen.open(context, batch.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.loadName(batch), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                      Text(s.loadLine(batch), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: missing == 0
                      ? ResultLabel(s.allBack)
                      : ResultLabel(s.stampMissing(missing), missing: true),
                ),
                const SizedBox(width: 6),
                Icon(AppIcons.chevron, size: 14, color: context.palette.tertiaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
