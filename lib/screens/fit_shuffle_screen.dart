import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../models/saved_fit.dart';
import '../state/app_scope.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';
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

  // Each hanger is a damped pendulum whose hook is pulled along by the
  // rail, so it swings *because* the rail speeds up and slows down: it
  // leans back as the rail starts, swings forward as it slows, and is
  // already settling when it stops. One continuous motion, no hand-off.
  // Natural period ~0.6 s (stiffness 110), damping ratio 0.22.
  static const _stiffness = 110.0;
  static final _damping = 2 * 0.22 * sqrt(_stiffness);

  // Swing per unit of rail acceleration (pages/s²), and limits so a fast
  // shuffle reads as life, not as wobble: about 7° at a typical slow-down,
  // 12° at most.
  static const _drive = 0.33;
  static const _maxAccel = 45.0;
  static const _maxAngle = 0.21;

  _RailState(TickerProvider vsync) {
    _ticker = vsync.createTicker(_tick);
    controller.addListener(_wake);
  }

  final controller = PageController(viewportFraction: 0.56, initialPage: _start);

  /// The hangers' swing angle, in radians, around the hook.
  final swing = ValueNotifier<double>(0);
  int page = _start;
  bool locked = false;

  /// Reduce Motion: no swing at all.
  bool still = false;

  late final Ticker _ticker;
  double _angularVelocity = 0;
  double? _lastPage;
  double _pageVelocity = 0;
  Duration? _lastTime;

  Garment current(List<Garment> items) => items[page % items.length];

  // The rail moved: start simulating if we aren't already.
  void _wake() {
    if (still || _ticker.isActive) return;
    _lastTime = null;
    _lastPage = null;
    _pageVelocity = 0;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    if (!controller.hasClients || !controller.position.haveDimensions) return;
    final p = controller.page!;
    final dt = _lastTime == null ? 0.0 : (elapsed - _lastTime!).inMicroseconds / 1e6;
    _lastTime = elapsed;
    // First frame, or a long hitch: just take a reading.
    if (dt <= 0 || dt > 0.1) {
      _lastPage = p;
      return;
    }
    final v = (p - (_lastPage ?? p)) / dt;
    _lastPage = p;
    // Frame timing is noisy, so smooth the speed before taking its change.
    final smoothed = _pageVelocity + (v - _pageVelocity) * 0.5;
    final accel = ((smoothed - _pageVelocity) / dt).clamp(-_maxAccel, _maxAccel);
    _pageVelocity = smoothed;

    // Rail pulled toward later pages slides clothes left; their bottoms
    // lag to the right, which is a counter-clockwise (negative) turn.
    final angle = swing.value;
    final torque = -_stiffness * angle - _damping * _angularVelocity - _drive * accel;
    _angularVelocity += torque * dt;
    swing.value = (angle + _angularVelocity * dt).clamp(-_maxAngle, _maxAngle);

    if (swing.value.abs() < 0.0005 && _angularVelocity.abs() < 0.005 && v.abs() < 0.001) {
      swing.value = 0;
      _angularVelocity = 0;
      _ticker.stop();
    }
  }

  void dispose() {
    _ticker.dispose();
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
    final still = MediaQuery.disableAnimationsOf(context);
    for (final r in _rails) {
      r.still = still;
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          LargeTitle(title: s.fitShuffle),
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
                    minimumSize: const Size(54, 54),
                    backgroundColor: context.palette.tile,
                    foregroundColor: context.ink,
                  ),
                  // The heart filling in is the feedback.
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Icon(saved ? AppIcons.favorite : AppIcons.favoriteOutline, key: ValueKey(saved)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  // Stays black while the rails spin; a second tap is
                  // ignored rather than greying the button out mid-moment.
                  child: FilledButton.icon(
                    onPressed: () => _shuffle(lists),
                    icon: const Icon(AppIcons.shuffle, size: 20),
                    label: Text(s.shuffle),
                  ),
                ),
              ],
            ),
          ),
          if (fits.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionTitle(s.savedFits),
            SizedBox(
              height: 148,
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
    // A hairline rod; it turns solid ink when the rail is locked.
    final rodColor = rail.locked ? context.ink : palette.separator;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
          child: Row(
            children: [
              Expanded(child: Text(label, style: context.text.titleMedium)),
              IconButton(
                tooltip: rail.locked ? s.unlockRail(label) : s.lockRail(label),
                onPressed: onLock,
                icon: Icon(
                  rail.locked ? AppIcons.locked : AppIcons.unlocked,
                  color: rail.locked ? context.ink : palette.secondaryText,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: _hanger + cardSize + 44,
          child: Stack(
            children: [
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: rail.locked ? 2.5 : 2,
                  color: rodColor,
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
            ],
          ),
        ),
      ],
    );
  }
}

/// A garment on a hanger, on its gray tile, with its name under it.
class _Hanging extends StatelessWidget {
  final Garment garment;
  final double size;

  const _Hanging({required this.garment, required this.size});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(AppIcons.closet, size: _Rail._hanger, color: context.palette.tertiaryText),
        Transform.translate(
          offset: const Offset(0, -8),
          child: SizedBox.square(
            dimension: size,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: GarmentImage(garment: garment),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size),
          child: Text(
            garment.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.text.titleSmall,
          ),
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
      // The outfit laid out on one tile: top over bottom.
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: context.palette.tile, borderRadius: BorderRadius.circular(22)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final g in pieces.take(2))
              SizedBox.square(dimension: 64, child: GarmentImage(garment: g, iconSize: 24)),
          ],
        ),
      ),
    );
  }
}
