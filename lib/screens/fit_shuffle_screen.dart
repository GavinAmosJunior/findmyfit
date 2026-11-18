import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../models/saved_fit.dart';
import '../state/app_scope.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/tags.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/store_sign.dart';
import '../widgets/garment_image.dart';
import '../widgets/pressable.dart';

/// Mix and match clean clothes. Tops and bottoms hang on two rails you can
/// swipe on their own; Shuffle slides the unlocked rails like hangers
/// pushed along a rod. It's for ideas only: nothing here changes where
/// clothes are (closet, hamper, laundry).
class FitShuffleScreen extends StatefulWidget {
  const FitShuffleScreen({super.key});

  @override
  State<FitShuffleScreen> createState() => _FitShuffleScreenState();
}

class _RailState {
  // Rails loop: start far from zero so you can swipe either way.
  static const _start = 6000;

  // A hanger on a rod: a swing and a half-size swing back, settled in
  // about 1.5 s. Natural period ~0.6 s (stiffness 110), damping ratio 0.22.
  static final _pendulum = SpringDescription.withDampingRatio(mass: 1, stiffness: 110, ratio: 0.22);

  // Angular push per page/second of rail speed, and the cap: about 8°
  // of swing at most, so it reads as life, not as wobble.
  static const _pushPerSpeed = 0.3;
  static const _maxPush = 1.6;

  _RailState(TickerProvider vsync) : swing = AnimationController.unbounded(vsync: vsync);

  final controller = PageController(viewportFraction: 0.56, initialPage: _start);

  /// The hangers' swing angle, in radians, around the hook.
  final AnimationController swing;
  int page = _start;
  bool locked = false;

  // Fastest the rail moved during the current scroll, in pages/second,
  // signed by direction.
  double _peakSpeed = 0;
  double? _lastPage;
  Duration? _lastTime;

  Garment current(List<Garment> items) => items[page % items.length];

  void trackSpeed() {
    if (!controller.hasClients || !controller.position.haveDimensions) return;
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final p = controller.page!;
    if (_lastPage != null && _lastTime != null && now > _lastTime!) {
      final v = (p - _lastPage!) / ((now - _lastTime!).inMicroseconds / 1e6);
      if (v.abs() > _peakSpeed.abs()) _peakSpeed = v;
    }
    _lastPage = p;
    _lastTime = now;
  }

  /// The rail stopped: the hangers keep going a little, then swing back.
  /// Moving toward later pages slides clothes left, so their bottoms
  /// carry on left, which is a clockwise (positive) turn about the hook.
  void settle({required bool still}) {
    final push = (_peakSpeed * _pushPerSpeed).clamp(-_maxPush, _maxPush);
    _peakSpeed = 0;
    _lastPage = null;
    _lastTime = null;
    if (still || push.abs() < 0.15) return;
    swing.animateWith(SpringSimulation(_pendulum, swing.value, 0, push + swing.velocity));
  }

  void dispose() {
    controller.dispose();
    swing.dispose();
  }
}

class _FitShuffleScreenState extends State<FitShuffleScreen> with TickerProviderStateMixin {
  late final _rails = [_RailState(this), _RailState(this)];
  final _random = Random();
  bool _spinning = false;

  @override
  void dispose() {
    for (final r in _rails) {
      r.dispose();
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
        moves.add(
          rail.controller.animateToPage(
            target,
            // The lower rail settles a beat later, like a second hand on the rod.
            duration: Duration(milliseconds: 1100 + 260 * i),
            curve: Curves.easeOutCubic,
          ),
        );
      }
    }
    await Future.wait(moves);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _spinning = false);
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
      _rails[i].controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
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
          StoreSign(title: s.fitShuffle, color: SignColors.red),
          // Breathing room under the checker strip.
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
    // 500pt go to the title, rail headers, hangers, labels and buttons.
    final free = mq.size.height - mq.padding.top - mq.padding.bottom - 500;
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
                    backgroundColor: context.palette.missing.background,
                    foregroundColor: context.palette.signal,
                  ),
                  icon: Icon(
                    saved ? AppIcons.favorite : AppIcons.favoriteOutline,
                    color: saved ? context.palette.signal : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  // Stays red while the rails spin; a second tap is ignored
                  // rather than greying the button out mid-moment.
                  child: FilledButton.icon(
                    onPressed: () => _shuffle(lists),
                    style: FilledButton.styleFrom(
                      backgroundColor: SignColors.red,
                      foregroundColor: Colors.white,
                      textStyle: context.text.headlineSmall?.copyWith(fontSize: 18, letterSpacing: 1.4),
                    ),
                    icon: const Icon(AppIcons.shuffle),
                    label: Text(s.shuffle.toUpperCase()),
                  ),
                ),
              ],
            ),
          ),
          // The laundromat floor under the rails.
          const SizedBox(height: 18),
          const CheckerStrip(height: 24),
          if (fits.isNotEmpty) ...[
            const SizedBox(height: 20),
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
    final rodColor = rail.locked ? palette.signal : palette.steel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
          child: Row(
            children: [
              Expanded(child: Text(label.toUpperCase(), style: context.text.labelMedium?.copyWith(letterSpacing: 1.2))),
              IconButton(
                tooltip: rail.locked ? s.unlockRail(label) : s.lockRail(label),
                onPressed: onLock,
                icon: Icon(
                  rail.locked ? AppIcons.locked : AppIcons.unlocked,
                  color: rail.locked ? palette.signal : palette.tertiaryText,
                ),
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
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 3, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
              ),
              NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollUpdateNotification) rail.trackSpeed();
                  if (n is ScrollEndNotification) rail.settle(still: MediaQuery.disableAnimationsOf(context));
                  return false;
                },
                child: PageView.builder(
                  controller: rail.controller,
                  onPageChanged: onPageChanged,
                  physics: rail.locked || items.length == 1 ? const NeverScrollableScrollPhysics() : null,
                  clipBehavior: Clip.none,
                  // One piece on a rail just hangs there; no copies beside it.
                  itemBuilder: (context, i) => items.length == 1 && i != rail.page
                      ? const SizedBox.shrink()
                      : AnimatedBuilder(
                          animation: Listenable.merge([rail.controller, rail.swing]),
                          builder: (context, child) {
                            final c = rail.controller;
                            final page = c.hasClients && c.position.haveDimensions ? c.page! : rail.page.toDouble();
                            final d = i - page;
                            // Hangers off to the side are smaller, fainter and tilted,
                            // as if pushed along the rod. All of them swing together
                            // when the rail stops; the side ones a little less.
                            final swing = rail.swing.value * (d.abs() < 0.5 ? 1.0 : 0.7);
                            return Opacity(
                              opacity: (1 - d.abs() * 0.5).clamp(0.35, 1.0),
                              child: Transform.rotate(
                                angle: (d * 0.09).clamp(-0.16, 0.16) + swing,
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
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GarmentImage(garment: garment),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size),
          child: HangTag(garment.name),
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
