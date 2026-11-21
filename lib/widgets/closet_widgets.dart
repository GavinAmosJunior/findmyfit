import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../models/laundry_batch.dart';
import '../screens/batch_screen.dart';
import '../screens/home_shell.dart';
import '../state/app_scope.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'garment_image.dart';
import 'pressable.dart';

/// The glanceable cards at the top of the Closet: what's at the laundry,
/// and an outfit for today. Each shows only when it has something to say;
/// two sit side by side, one takes the full width.
class ClosetWidgets extends StatefulWidget {
  const ClosetWidgets({super.key});

  @override
  State<ClosetWidgets> createState() => _ClosetWidgetsState();
}

class _ClosetWidgetsState extends State<ClosetWidgets> {
  // How many times "another fit" was tapped today.
  int _turn = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final loads = state.activeBatches;
    final tops = state.shuffleTops;
    final bottoms = state.shuffleBottoms;

    final cards = <Widget>[
      if (loads.isNotEmpty) _LaundryCard(load: loads.first, others: loads.length - 1),
      if (tops.isNotEmpty && bottoms.isNotEmpty)
        _FitCard(
          wide: loads.isEmpty,
          fit: _pick(tops, bottoms),
          onAnother: () {
            HapticFeedback.selectionClick();
            setState(() => _turn++);
          },
        ),
    ];
    if (cards.isEmpty) return const SizedBox(height: 4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, card) in cards.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: card),
            ],
          ],
        ),
      ),
    );
  }

  /// The same pick all day, until "another" is tapped; a new one tomorrow.
  (Garment, Garment) _pick(List<Garment> tops, List<Garment> bottoms) {
    final now = DateTime.now();
    final random = Random(now.year * 10000 + now.month * 100 + now.day + _turn * 7919);
    return (tops[random.nextInt(tops.length)], bottoms[random.nextInt(bottoms.length)]);
  }
}

/// The card's frame: a gray tile with a small titled header.
class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  const _Card({required this.icon, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
      decoration: BoxDecoration(color: context.palette.tile, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Icon(icon, size: 16, color: context.ink),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium?.copyWith(color: context.ink)),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The load out now: its name, how many are back, and a progress line.
/// Opens the return check, or the Laundry tab when several loads are out.
class _LaundryCard extends StatelessWidget {
  final LaundryBatch load;
  final int others;

  const _LaundryCard({required this.load, required this.others});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final garments = AppScope.of(context).garmentsInBatch(load);
    void open() {
      if (others == 0) {
        BatchScreen.open(context, load.id);
      } else {
        HomeShellState.maybeOf(context)?.goTo(HomeShellState.laundryTab);
      }
    }

    return Pressable(
      label: '${s.atTheLaundry}: ${s.loadName(load)}, ${s.backCount(load.verifiedCount, load.totalItems)}',
      onTap: open,
      child: _Card(
        icon: AppIcons.laundry,
        title: s.atTheLaundry,
        trailing: others > 0
            ? Text(s.moreLoads(others), style: context.text.labelMedium)
            : Icon(AppIcons.chevron, size: 14, color: context.palette.secondaryText),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _Faces(garments: garments),
            const Spacer(),
            const SizedBox(height: 10),
            Text(s.loadName(load), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
            Text(s.backCount(load.verifiedCount, load.totalItems), style: context.text.bodySmall),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: load.progress, minHeight: 4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Up to three pieces of a load as overlapping circles, then a count.
class _Faces extends StatelessWidget {
  final List<Garment> garments;

  const _Faces({required this.garments});

  static const _size = 38.0;
  static const _step = 26.0;

  @override
  Widget build(BuildContext context) {
    final shown = garments.take(3).toList();
    final extra = garments.length - shown.length;
    final count = shown.length + (extra > 0 ? 1 : 0);
    Widget circle(Widget child) => Container(
      width: _size,
      height: _size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: context.palette.tile, shape: BoxShape.circle),
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
                child: circle(GarmentImage(garment: g, iconSize: 16, backdrop: context.colors.surface)),
              ),
            if (extra > 0)
              Positioned(
                left: _step * shown.length,
                child: circle(
                  ColoredBox(
                    color: context.ink,
                    child: Center(
                      child: Text('+$extra', style: context.text.labelSmall?.copyWith(color: context.colors.surface)),
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

/// A top and a bottom from your clean clothes, laid side by side. Tapping
/// shows another pair. On its own ([wide]) the names sit beside the
/// pictures, so the card stays short.
class _FitCard extends StatelessWidget {
  final (Garment, Garment) fit;
  final VoidCallback onAnother;
  final bool wide;

  const _FitCard({required this.fit, required this.onAnother, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (top, bottom) = fit;
    final still = MediaQuery.disableAnimationsOf(context);

    Widget piece(Garment g) => AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GarmentImage(garment: g, iconSize: 26, backdrop: context.colors.surface),
      ),
    );

    final pair = wide
        ? Row(
            key: ValueKey('${top.id}/${bottom.id}'),
            children: [
              SizedBox(width: 92, child: piece(top)),
              const SizedBox(width: 6),
              SizedBox(width: 92, child: piece(bottom)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(top.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                    const SizedBox(height: 2),
                    Text(bottom.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                  ],
                ),
              ),
            ],
          )
        : Column(
            key: ValueKey('${top.id}/${bottom.id}'),
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: piece(top)),
                  const SizedBox(width: 6),
                  Expanded(child: piece(bottom)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${top.name} · ${bottom.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall,
              ),
            ],
          );

    return Pressable(
      label: '${s.todaysFit}: ${top.name}, ${bottom.name}. ${s.anotherFit}',
      onTap: onAnother,
      child: _Card(
        icon: AppIcons.fits,
        title: s.todaysFit,
        trailing: Icon(AppIcons.rotate, size: 16, color: context.palette.secondaryText),
        child: AnimatedSwitcher(
          duration: still ? Duration.zero : const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOut,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(anim), child: child),
          ),
          child: pair,
        ),
      ),
    );
  }
}
