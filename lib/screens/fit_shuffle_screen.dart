import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../models/saved_fit.dart';
import '../state/app_scope.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/fit_collage.dart';
import '../widgets/garment_image.dart';
import '../widgets/pressable.dart';
import 'saved_fit_sheet.dart';

/// Mix and match clean clothes, head to toe. Tops and bottoms hang on two
/// rails you can swipe on their own. Turn on more in Rails: a slim row of
/// hooks for a hat, a bag and an accessory, and a shelf for shoes. Shuffle
/// slides everything unlocked, and it settles from head to toe.
///
/// It's for ideas only: nothing here changes where clothes are.
class FitShuffleScreen extends StatefulWidget {
  const FitShuffleScreen({super.key});

  @override
  State<FitShuffleScreen> createState() => _FitShuffleScreenState();
}

/// The rows, head to toe.
enum _Row {
  hat(GarmentCategory.hats),
  bag(GarmentCategory.bags),
  accessory(GarmentCategory.accessories),
  top(GarmentCategory.tops),
  bottom(GarmentCategory.bottoms),
  shoes(GarmentCategory.shoes);

  const _Row(this.category);
  final GarmentCategory category;

  /// Small pieces on hooks, where "none" is a choice too.
  bool get onHook => this == hat || this == bag || this == accessory;
}

class _RailState {
  // Rails loop: start far from zero so you can swipe either way. 5040 is a
  // multiple of every count up to 10, so a row starts on its first item.
  static const _start = 5040;

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

  _RailState(TickerProvider vsync, {double viewportFraction = 0.56, int skip = 0})
    : controller = PageController(viewportFraction: viewportFraction, initialPage: _start + skip),
      page = _start + skip {
    _ticker = vsync.createTicker(_tick);
    controller.addListener(_wake);
  }

  final PageController controller;

  /// The hangers' swing angle, in radians, around the hook.
  final swing = ValueNotifier<double>(0);
  int page;
  bool locked = false;

  /// Reduce Motion: no swing at all.
  bool still = false;

  late final Ticker _ticker;
  double _angularVelocity = 0;
  double? _lastPage;
  double _pageVelocity = 0;
  Duration? _lastTime;

  T current<T>(List<T> items) => items[page % items.length];

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
  final _rails = <_Row, _RailState>{};
  final _random = Random();
  bool _spinning = false;

  _RailState _rail(_Row row) =>
      // Hooks begin on a piece, one past "none".
      _rails.putIfAbsent(row, () => _RailState(this, viewportFraction: row.onHook ? 1.0 : 0.56, skip: row.onHook ? 1 : 0));

  @override
  void dispose() {
    for (final r in _rails.values) {
      r.dispose();
    }
    super.dispose();
  }

  /// What each shown row holds. Rows on hooks start with "none" (null).
  Map<_Row, List<Garment?>> _rows(WardrobeState state) {
    final rows = <_Row, List<Garment?>>{};
    for (final row in _Row.values) {
      final List<Garment> pieces = switch (row) {
        _Row.top => state.shuffleTops,
        _Row.bottom => state.shuffleBottoms,
        _ => state.railOn(row.category) ? state.shuffleOf(row.category) : const [],
      };
      if (row == _Row.top || row == _Row.bottom || pieces.isNotEmpty) {
        rows[row] = row.onHook ? [null, ...pieces] : pieces;
      }
    }
    return rows;
  }

  Future<void> _shuffle(Map<_Row, List<Garment?>> rows) async {
    if (_spinning) return;
    final still = MediaQuery.disableAnimationsOf(context);
    HapticFeedback.mediumImpact();
    setState(() => _spinning = true);

    final moves = <Future<void>>[];
    var order = 0;
    for (final MapEntry(key: row, value: items) in rows.entries) {
      final rail = _rail(row);
      final n = items.length;
      final pieces = row.onHook ? n - 1 : n;
      if (rail.locked || pieces < 1 || (!row.onHook && n < 2) || !rail.controller.hasClients) continue;
      // A couple of full turns, then land on a different piece. Hooks
      // never land on "none": that's yours to choose by swiping.
      final loops = n < 5 ? 2 : 1;
      final now = rail.page % n;
      int land;
      if (row.onHook) {
        final options = [for (var k = 1; k < n; k++) if (k != now || pieces == 1) k];
        land = options[_random.nextInt(options.length)];
      } else {
        land = (now + 1 + _random.nextInt(n - 1)) % n;
      }
      final delta = (land - now) % n;
      final target = rail.page + loops * n + (delta == 0 ? n : delta);
      if (still) {
        rail.controller.jumpToPage(target);
      } else {
        moves.add(
          rail.controller.animateToPage(
            target,
            // Head to toe: each row settles a beat after the one above.
            duration: Duration(milliseconds: 1000 + 200 * order),
            curve: Curves.easeOutCubic,
          ),
        );
      }
      order++;
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

  /// Slides every row to a saved fit, turning on any row it needs.
  void _showFit(SavedFit fit) {
    final state = AppScope.read(context);
    final pieces = fit.itemIds.map(state.garmentById).whereType<Garment>().toList();
    for (final g in pieces) {
      if (WardrobeState.extraRails.contains(g.category) && !state.railOn(g.category)) {
        state.setRail(g.category, true);
      }
    }
    // Let new rows build before moving them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rows = _rows(state);
      final targets = <_RailState, int>{};
      for (final MapEntry(key: row, value: items) in rows.entries) {
        var index = items.indexWhere((g) => g != null && fit.itemIds.contains(g.id));
        if (index == -1) {
          if (row.onHook) {
            index = 0; // This fit had nothing here.
          } else if (row == _Row.shoes) {
            continue;
          } else {
            showMessage(context, S.of(context).fitNotReady);
            return;
          }
        }
        final rail = _rail(row);
        final n = items.length;
        final base = rail.page - rail.page % n;
        // Pick the copy of that piece nearest to where the row is now.
        final options = [base - n + index, base + index, base + n + index];
        options.sort((a, b) => (a - rail.page).abs().compareTo((b - rail.page).abs()));
        targets[rail] = options.first;
      }
      HapticFeedback.selectionClick();
      for (final MapEntry(key: rail, value: target) in targets.entries) {
        if (!rail.controller.hasClients) continue;
        rail.controller.animateToPage(target, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
      }
    });
  }

  void _openRails() {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const _RailsSheet());
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final rows = _rows(state);
    final ready = rows[_Row.top]!.isNotEmpty && rows[_Row.bottom]!.isNotEmpty;
    final still = MediaQuery.disableAnimationsOf(context);
    for (final row in rows.keys) {
      _rail(row).still = still;
    }

    final layout = _Layout.of(context, rows);

    return Scaffold(
      // Shuffle and the heart stay within reach at the bottom, however many
      // rows are on.
      bottomNavigationBar: ready ? _actionBar(context, s, rows) : null,
      body: CustomScrollView(
        slivers: [
          LargeTitle(
            title: s.fitShuffle,
            actions: [
              IconButton(tooltip: s.customizeRails, onPressed: _openRails, icon: const Icon(AppIcons.rails)),
            ],
          ),
          if (!ready)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: AppIcons.shuffle, title: s.shuffleEmptyTitle, body: s.shuffleEmptyBody),
            )
          else
            SliverToBoxAdapter(child: _body(context, s, rows, layout)),
        ],
      ),
    );
  }

  List<Garment> _fit(Map<_Row, List<Garment?>> rows) => [
    for (final MapEntry(key: row, value: items) in rows.entries)
      if (items.isNotEmpty) ?_rail(row).current(items),
  ];

  Widget _actionBar(BuildContext context, S s, Map<_Row, List<Garment?>> rows) {
    final fit = _fit(rows);
    final saved = AppScope.of(context).isFitSaved(fit.map((g) => g.id));
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
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
              // Stays black while the rails spin; a second tap is ignored
              // rather than greying the button out mid-moment.
              child: FilledButton.icon(
                onPressed: () => _shuffle(rows),
                icon: const Icon(AppIcons.shuffle, size: 20),
                label: Text(s.shuffle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, S s, Map<_Row, List<Garment?>> rows, _Layout layout) {
    final state = AppScope.of(context);
    final fits = state.fits;
    final hooks = [for (final row in rows.keys) if (row.onHook) row];
    final hasShoes = rows.containsKey(_Row.shoes);
    final card = layout.card;

    void lock(_Row row) {
      HapticFeedback.selectionClick();
      setState(() => _rail(row).locked = !_rail(row).locked);
    }

    void changed(int page, _Row row) {
      if (_spinning) HapticFeedback.selectionClick();
      setState(() => _rail(row).page = page);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hooks.isNotEmpty)
            _HookRow(
              // Keys keep each row tied to its own controller when rows
              // come and go above it.
              key: const ValueKey('hooks'),
              label: s.extras,
              hooks: [
                for (final row in hooks)
                  (
                    title: s.categoryLabel(row.category),
                    items: rows[row]!,
                    rail: _rail(row),
                    onLock: () => lock(row),
                    onPageChanged: (p) => changed(p, row),
                  ),
              ],
              size: layout.hook,
            ),
          for (final row in [_Row.top, _Row.bottom])
            _Rail(
              key: ValueKey(row),
              label: row == _Row.top ? s.categoryLabel(GarmentCategory.tops) : s.categoryLabel(GarmentCategory.bottoms),
              items: rows[row]!.cast<Garment>(),
              rail: _rail(row),
              cardSize: card,
              compact: layout.compact,
              onLock: () => lock(row),
              onPageChanged: (p) => changed(p, row),
            ),
          if (hasShoes)
            _Shelf(
              key: const ValueKey(_Row.shoes),
              label: s.categoryLabel(GarmentCategory.shoes),
              items: rows[_Row.shoes]!.cast<Garment>(),
              rail: _rail(_Row.shoes),
              height: card * 0.6,
              compact: layout.compact,
              onLock: () => lock(_Row.shoes),
              onPageChanged: (p) => changed(p, _Row.shoes),
            ),
          if (fits.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionTitle(s.savedFits),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: fits.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _SavedFitTile(
                  fit: fits[i],
                  onTap: () => SavedFitSheet.show(context, fits[i], onShow: () => _showFit(fits[i])),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sizes for the rows, so that a whole outfit, head to toe, fits on one
/// screen between the title and the Shuffle bar. With extras on, rows get
/// compact: smaller hangers, tighter headers.
class _Layout {
  final double card;
  final double hook;
  final bool compact;

  const _Layout(this.card, this.hook, this.compact);

  static _Layout of(BuildContext context, Map<_Row, List<Garment?>> rows) {
    final mq = MediaQuery.of(context);
    final hasHooks = rows.keys.any((r) => r.onHook);
    final hasShoes = rows.containsKey(_Row.shoes);
    final compact = hasHooks || hasShoes;
    final header = compact ? _RowHeader.compactHeight : _RowHeader.height;
    final rail = header + _Rail.hangerFor(compact) - 8 + _Rail.labelFor(compact);
    final used = 112 + mq.padding.top // the large title
        + 72 + mq.padding.bottom // the Shuffle bar and the tab bar
        + 2 * rail
        + (hasShoes ? header + 40 : 0)
        + (hasHooks ? 96 : 0)
        + 8;
    final units = 2 + (hasShoes ? 0.6 : 0) + (hasHooks ? 0.45 : 0);
    final card = min(mq.size.width * 0.56 - 28, (mq.size.height - used) / units).clamp(72.0, 240.0);
    return _Layout(card, max(card * 0.45, 52), compact);
  }
}

/// A row's title and its lock.
class _RowHeader extends StatelessWidget {
  final String label;
  final bool locked;
  final VoidCallback onLock;

  final bool compact;

  const _RowHeader({required this.label, required this.locked, required this.onLock, this.compact = false});

  static const height = 52.0;
  static const compactHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 0 : 4, 8, 0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: compact ? context.text.titleSmall : context.text.titleMedium)),
          IconButton(
            tooltip: locked ? s.unlockRail(label) : s.lockRail(label),
            onPressed: onLock,
            icon: Icon(locked ? AppIcons.locked : AppIcons.unlocked, color: locked ? context.ink : context.palette.secondaryText),
          ),
        ],
      ),
    );
  }
}

/// How far a piece sits from the middle of its row, in pages.
double _offset(_RailState rail, int i) {
  final c = rail.controller;
  final page = c.hasClients && c.position.haveDimensions ? c.page! : rail.page.toDouble();
  return i - page;
}

/// One rail: a rod across the screen with clothes hanging from it.
class _Rail extends StatelessWidget {
  final String label;
  final List<Garment> items;
  final _RailState rail;
  final double cardSize;
  final bool compact;
  final VoidCallback onLock;
  final ValueChanged<int> onPageChanged;

  const _Rail({
    super.key,
    required this.label,
    required this.items,
    required this.rail,
    required this.cardSize,
    required this.onLock,
    required this.onPageChanged,
    this.compact = false,
  });

  static double hangerFor(bool compact) => compact ? 30 : 46;
  static double labelFor(bool compact) => compact ? 30 : 44;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // A hairline rod; it turns solid ink when the rail is locked.
    final rodColor = rail.locked ? context.ink : palette.separator;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RowHeader(label: label, locked: rail.locked, onLock: onLock, compact: compact),
        SizedBox(
          height: hangerFor(compact) + cardSize + labelFor(compact),
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
                          final d = _offset(rail, i);
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
                        child: _Hanging(garment: items[i % items.length], size: cardSize, hanger: hangerFor(compact)),
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
  final double hanger;

  const _Hanging({required this.garment, required this.size, required this.hanger});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(AppIcons.closet, size: hanger, color: context.palette.tertiaryText),
        Transform.translate(
          offset: const Offset(0, -8),
          child: SizedBox.square(
            dimension: size,
            child: ClipRRect(borderRadius: BorderRadius.circular(24), child: GarmentImage(garment: garment)),
          ),
        ),
        _Name(garment.name, width: size),
      ],
    );
  }
}

class _Name extends StatelessWidget {
  final String text;
  final double width;

  const _Name(this.text, {required this.width});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: width),
    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: context.text.titleSmall),
  );
}

/// The shoe shelf: shoes don't hang, they stand on a thin shelf. They slide
/// along it like the rails, and when they stop they land with a small hop
/// instead of a swing.
class _Shelf extends StatelessWidget {
  final String label;
  final List<Garment> items;
  final _RailState rail;
  final double height;
  final bool compact;
  final VoidCallback onLock;
  final ValueChanged<int> onPageChanged;

  const _Shelf({
    super.key,
    required this.label,
    required this.items,
    required this.rail,
    required this.height,
    required this.onLock,
    required this.onPageChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = height * 1.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RowHeader(label: label, locked: rail.locked, onLock: onLock, compact: compact),
        SizedBox(
          height: height + 40,
          child: Stack(
            children: [
              // The shelf, under the shoes.
              Positioned(
                top: height + 4,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: rail.locked ? 3 : 2.5,
                  color: rail.locked ? context.ink : context.palette.separator,
                ),
              ),
              PageView.builder(
                controller: rail.controller,
                onPageChanged: onPageChanged,
                physics: rail.locked || items.length == 1 ? const NeverScrollableScrollPhysics() : null,
                clipBehavior: Clip.none,
                itemBuilder: (context, i) => items.length == 1 && i != rail.page
                    ? const SizedBox.shrink()
                    : AnimatedBuilder(
                        animation: Listenable.merge([rail.controller, rail.swing]),
                        builder: (context, child) {
                          final d = _offset(rail, i);
                          // The swing becomes a hop: up as it "swings", down
                          // onto the shelf, with a hint of tilt on the heel.
                          final hop = rail.swing.value.abs() * 60 * (d.abs() < 0.5 ? 1.0 : 0.6);
                          return Opacity(
                            opacity: (1 - d.abs() * 0.5).clamp(0.35, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, -hop),
                              child: Transform.rotate(
                                angle: rail.swing.value * 0.35,
                                alignment: Alignment.bottomCenter,
                                child: Transform.scale(
                                  scale: (1 - d.abs() * 0.16).clamp(0.8, 1.0),
                                  alignment: Alignment.bottomCenter,
                                  child: child,
                                ),
                              ),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            SizedBox(
                              width: width,
                              height: height,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: GarmentImage(garment: items[i % items.length]),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Name(items[i % items.length].name, width: width),
                          ],
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

typedef _Hook = ({
  String title,
  List<Garment?> items,
  _RailState rail,
  VoidCallback onLock,
  ValueChanged<int> onPageChanged,
});

/// A slim row of hooks for the small things: a hat, a bag, an accessory.
/// Each hook swipes on its own, can be left empty, and swings like the
/// hangers. Tap a piece to lock it.
class _HookRow extends StatelessWidget {
  final String label;
  final List<_Hook> hooks;
  final double size;

  const _HookRow({super.key, required this.label, required this.hooks, required this.size});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Text(label, style: context.text.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final hook in hooks) Expanded(child: _HookSlot(key: ValueKey(hook.title), hook: hook, size: size)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Divider(indent: 20, endIndent: 20),
      ],
    );
  }
}

class _HookSlot extends StatelessWidget {
  final _Hook hook;
  final double size;

  const _HookSlot({super.key, required this.hook, required this.size});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final rail = hook.rail;
    final items = hook.items;
    final piece = rail.current(items);
    final ink = rail.locked ? context.ink : context.palette.tertiaryText;

    return Column(
      children: [
        // The hook: a small peg with a stem.
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: ink)),
        Container(width: 2, height: 8, color: ink),
        SizedBox(
          height: size,
          child: PageView.builder(
            controller: rail.controller,
            onPageChanged: hook.onPageChanged,
            physics: rail.locked ? const NeverScrollableScrollPhysics() : null,
            itemBuilder: (context, i) {
              final g = items[i % items.length];
              return AnimatedBuilder(
                animation: rail.swing,
                builder: (context, child) =>
                    Transform.rotate(angle: rail.swing.value, alignment: Alignment.topCenter, child: child),
                child: Center(
                  child: Semantics(
                    button: true,
                    toggled: rail.locked,
                    label: g?.name ?? s.noneOf(hook.title),
                    child: GestureDetector(
                      onTap: hook.onLock,
                      child: SizedBox.square(
                        dimension: size,
                        child: g == null
                            ? DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: context.palette.separator, width: 1.5),
                                ),
                                child: Icon(AppIcons.close, size: 18, color: context.palette.tertiaryText),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: GarmentImage(garment: g, iconSize: 20),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (rail.locked) ...[Icon(AppIcons.locked, size: 11, color: context.ink), const SizedBox(width: 3)],
            Flexible(
              child: Text(
                piece?.name ?? s.noneOf(hook.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall,
              ),
            ),
          ],
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
      child: SizedBox(width: 120, child: FitCollage(pieces: pieces, radius: 20)),
    );
  }
}

/// Which rows Fit Shuffle shows. Tops and bottoms always; the rest when
/// you want a full outfit.
class _RailsSheet extends StatelessWidget {
  const _RailsSheet();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);

    Widget row(GarmentCategory c, {bool always = false}) {
      final count = c == GarmentCategory.tops ? state.shuffleTops.length : state.shuffleOf(c).length;
      return SwitchListTile.adaptive(
        secondary: Icon(categoryIcon(c), color: context.ink),
        title: Text(s.categoryLabel(c)),
        subtitle: Text(s.items(count)),
        value: always || state.railOn(c),
        onChanged: always
            ? null
            : (on) {
                HapticFeedback.selectionClick();
                state.setRail(c, on);
              },
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(s.railsTitle, style: context.text.headlineSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(s.railsHint, style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    row(GarmentCategory.tops, always: true),
                    const Divider(indent: 18),
                    row(GarmentCategory.bottoms, always: true),
                    for (final c in WardrobeState.extraRails) ...[const Divider(indent: 18), row(c)],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
