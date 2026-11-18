import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../models/saved_fit.dart';
import '../state/app_scope.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/care_label.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/garment_image.dart';
import '../widgets/pressable.dart';

/// Mix and match clean clothes. Tops and bottoms hang on two rails you can
/// swipe on their own; Shuffle slides the unlocked rails like hangers
/// pushed along a rod, and "Wear this fit" sends both pieces to the hamper.
class FitShuffleScreen extends StatefulWidget {
  const FitShuffleScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FitShuffleScreen()));

  @override
  State<FitShuffleScreen> createState() => _FitShuffleScreenState();
}

class _RailState {
  // Rails loop: start far from zero so you can swipe either way.
  static const _start = 6000;

  final controller = PageController(viewportFraction: 0.56, initialPage: _start);
  int page = _start;
  bool locked = false;

  Garment current(List<Garment> items) => items[page % items.length];
}

class _FitShuffleScreenState extends State<FitShuffleScreen> {
  final _rails = [_RailState(), _RailState()];
  final _random = Random();
  bool _spinning = false;

  @override
  void dispose() {
    for (final r in _rails) {
      r.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _shuffle(List<List<Garment>> lists) async {
    if (_spinning) return;
    final still = MediaQuery.disableAnimationsOf(context);
    HapticFeedback.mediumImpact();
    setState(() => _spinning = true);

    final moves = <Future<void>>[];
    for (final (i, rail) in _rails.indexed) {
      final n = lists[i].length;
      if (rail.locked || n < 2 || !rail.controller.hasClients) continue;
      // A couple of full turns, then land on a different piece.
      final loops = n < 5 ? 2 : 1;
      final target = rail.page + loops * n + 1 + _random.nextInt(n - 1);
      if (still) {
        rail.controller.jumpToPage(target);
      } else {
        moves.add(rail.controller.animateToPage(
          target,
          // The lower rail settles a beat later, like a second hand on the rod.
          duration: Duration(milliseconds: 1100 + 260 * i),
          curve: Curves.easeOutCubic,
        ));
      }
    }
    await Future.wait(moves);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _spinning = false);
  }

  void _wear(List<Garment> fit) {
    final state = AppScope.read(context);
    final s = S.of(context);
    final before = [for (final g in fit) (g.id, state.markWorn(g.id))];
    HapticFeedback.mediumImpact();
    showMessage(
      context,
      s.woreFit,
      actionLabel: s.undo,
      onAction: () {
        for (final (id, snapshot) in before) {
          if (snapshot != null) state.undoMarkWorn(id, snapshot);
        }
      },
    );
  }

  // The heart filling in is the feedback; no snackbar over the buttons.
  void _toggleSave(List<Garment> fit) {
    AppScope.read(context).toggleFit([for (final g in fit) g.id]);
    HapticFeedback.lightImpact();
  }

  /// Slides both rails to a saved fit, if its pieces are clean.
  void _showFit(SavedFit fit, List<List<Garment>> lists) {
    final targets = <int>[];
    for (final (i, items) in lists.indexed) {
      final index = items.indexWhere((g) => fit.itemIds.contains(g.id));
      if (index == -1) {
        showMessage(context, S.of(context).fitNotReady);
        return;
      }
      final rail = _rails[i];
      final base = rail.page - rail.page % items.length;
      // Pick the copy of that piece nearest to where the rail is now.
      final options = [base - items.length + index, base + index, base + items.length + index];
      options.sort((a, b) => (a - rail.page).abs().compareTo((b - rail.page).abs()));
      targets.add(options.first);
    }
    HapticFeedback.selectionClick();
    for (final (i, target) in targets.indexed) {
      _rails[i].controller.animateToPage(target, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final lists = [state.shuffleTops, state.shuffleBottoms];
    final ready = lists.every((l) => l.isNotEmpty);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(s.fitShuffle)),
          if (!ready)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: AppIcons.shuffle, title: s.shuffleEmptyTitle, body: s.shuffleEmptyBody),
            )
          else
            SliverToBoxAdapter(child: _body(context, s, lists)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, S s, List<List<Garment>> lists) {
    final state = AppScope.of(context);
    final fit = [for (final (i, rail) in _rails.indexed) rail.current(lists[i])];
    final saved = state.isFitSaved(fit.map((g) => g.id));
    final fits = state.fits;
    final mq = MediaQuery.of(context);
    // Both rails and the Shuffle button should fit on one screen: about
    // 560pt go to the title, rail headers, hangers, labels and buttons.
    final free = mq.size.height - mq.padding.top - mq.padding.bottom - 560;
    final card = min(mq.size.width * 0.56 - 28, free / 2).clamp(96.0, 240.0);

    return Padding(
      padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, rail) in _rails.indexed)
            _Rail(
              label: i == 0 ? s.categoryLabel(GarmentCategory.tops) : s.categoryLabel(GarmentCategory.bottoms),
              items: lists[i],
              rail: rail,
              cardSize: card,
              onLock: () {
                HapticFeedback.selectionClick();
                setState(() => rail.locked = !rail.locked);
              },
              onPageChanged: (page) {
                if (_spinning) HapticFeedback.selectionClick();
                setState(() => rail.page = page);
              },
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: saved ? s.unsaveFit : s.saveFit,
                  onPressed: () => _toggleSave(fit),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    backgroundColor: context.colors.primary.withValues(alpha: 0.10),
                    foregroundColor: context.colors.primary,
                  ),
                  icon: Icon(
                    saved ? AppIcons.favorite : AppIcons.favoriteOutline,
                    color: saved ? context.palette.thread : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _spinning ? null : () => _shuffle(lists),
                    icon: const Icon(AppIcons.shuffle),
                    label: Text(s.shuffle),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: _spinning ? null : () => _wear(fit),
              child: Text(s.wearThisFit),
            ),
          ),
          if (fits.isNotEmpty) ...[
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(s.savedFits.toUpperCase(), style: context.text.labelMedium?.copyWith(letterSpacing: 1.2)),
            ),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: fits.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _SavedFitTile(fit: fits[i], onTap: () => _showFit(fits[i], lists)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One rail: a rod across the screen with clothes hanging from it.
class _Rail extends StatelessWidget {
  final String label;
  final List<Garment> items;
  final _RailState rail;
  final double cardSize;
  final VoidCallback onLock;
  final ValueChanged<int> onPageChanged;

  const _Rail({
    required this.label,
    required this.items,
    required this.rail,
    required this.cardSize,
    required this.onLock,
    required this.onPageChanged,
  });

  static const _hanger = 46.0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final palette = context.palette;
    final rodColor = rail.locked ? palette.thread : palette.tertiaryText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(label.toUpperCase(), style: context.text.labelMedium?.copyWith(letterSpacing: 1.2)),
              ),
              IconButton(
                tooltip: rail.locked ? s.unlockRail(label) : s.lockRail(label),
                onPressed: onLock,
                icon: Icon(rail.locked ? AppIcons.locked : AppIcons.unlocked,
                    color: rail.locked ? palette.thread : palette.tertiaryText),
              ),
            ],
          ),
        ),
        SizedBox(
          height: _hanger + cardSize + 44,
          child: Stack(
            children: [
              // The rod. Red thread when the rail is locked.
              Positioned(
                top: 5,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: rodColor,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 3, offset: const Offset(0, 2))],
                  ),
                ),
              ),
              PageView.builder(
                controller: rail.controller,
                onPageChanged: onPageChanged,
                physics: rail.locked || items.length == 1 ? const NeverScrollableScrollPhysics() : null,
                clipBehavior: Clip.none,
                // One piece on a rail just hangs there; no copies beside it.
                itemBuilder: (context, i) => items.length == 1 && i != rail.page
                    ? const SizedBox.shrink()
                    : AnimatedBuilder(
                  animation: rail.controller,
                  builder: (context, child) {
                    final c = rail.controller;
                    final page = c.hasClients && c.position.haveDimensions ? c.page! : rail.page.toDouble();
                    final d = i - page;
                    // Hangers off to the side are smaller, fainter and tilted,
                    // as if pushed along the rod.
                    return Opacity(
                      opacity: (1 - d.abs() * 0.5).clamp(0.35, 1.0),
                      child: Transform.rotate(
                        angle: (d * 0.09).clamp(-0.16, 0.16),
                        alignment: Alignment.topCenter,
                        child: Transform.scale(
                          scale: (1 - d.abs() * 0.16).clamp(0.8, 1.0),
                          alignment: Alignment.topCenter,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _Hanging(garment: items[i % items.length], size: cardSize),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A garment on a hanger, with its woven name label.
class _Hanging extends StatelessWidget {
  final Garment garment;
  final double size;

  const _Hanging({required this.garment, required this.size});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(AppIcons.closet, size: _Rail._hanger, color: context.palette.secondaryText),
        Transform.translate(
          offset: const Offset(0, -8),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(16), child: GarmentImage(garment: garment)),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size),
          child: WovenLabel(garment.name),
        ),
      ],
    );
  }
}

class _SavedFitTile extends StatelessWidget {
  final SavedFit fit;
  final VoidCallback onTap;

  const _SavedFitTile({required this.fit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pieces = fit.itemIds.map(state.garmentById).whereType<Garment>().toList();
    return Pressable(
      label: pieces.map((g) => g.name).join(', '),
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: context.palette.card, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            for (final g in pieces.take(2)) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox.square(dimension: 54, child: GarmentImage(garment: g, iconSize: 22)),
              ),
              if (g != pieces.take(2).last) const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}
