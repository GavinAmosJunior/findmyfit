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

/// Mix and match clean clothes, head to toe, on one screen that never
/// scrolls. Tops and bottoms hang on rails you swipe on their own; shoes
/// stand on a shelf. A hat, a bag and an accessory sit in a small tray
/// above. Shuffle changes everything that isn't locked, settling from
/// head to toe. Turn rows on in Rails; saved fits open from the header.
///
/// It's for ideas only: nothing here changes where clothes are.
class FitShuffleScreen extends StatefulWidget {
  const FitShuffleScreen({super.key});

  @override
  State<FitShuffleScreen> createState() => _FitShuffleScreenState();
}

/// The rows that slide: tops, bottoms, shoes.
enum _Row { top, bottom, shoes }

/// The small things in the tray, head first.
const _extras = [GarmentCategory.hats, GarmentCategory.bags, GarmentCategory.accessories, GarmentCategory.watches];

class _FitShuffleScreenState extends State<FitShuffleScreen> with TickerProviderStateMixin {
  final _rails = <_Row, _RailState>{};
  final _random = Random();
  bool _spinning = false;

  // The tray: what's picked for each extra (null = none), and which are
  // kept when shuffling.
  final _picked = <GarmentCategory, String?>{};
  final _kept = <GarmentCategory>{};

  // When the shelf or tray last appeared, so their pieces play their
  // arrival only then.
  final _arrivedAt = <Object, DateTime>{};
  Set<Object>? _present;

  _RailState _rail(_Row row) => _rails.putIfAbsent(row, () => _RailState(this));

  @override
  void dispose() {
    for (final r in _rails.values) {
      r.dispose();
    }
    super.dispose();
  }

  bool _fresh(Object key) {
    final at = _arrivedAt[key];
    return at != null && DateTime.now().difference(at) < const Duration(milliseconds: 1500);
  }

  void _noteArrivals(Set<Object> now) {
    // The first build is the screen opening, not something arriving.
    if (_present != null) {
      for (final key in now.difference(_present!)) {
        _arrivedAt[key] = DateTime.now();
      }
    }
    _present = now;
  }

  /// The tray's extras that are on and have pieces, with those pieces.
  Map<GarmentCategory, List<Garment>> _trayOf(WardrobeState state) => {
    for (final c in _extras)
      if (state.railOn(c) && state.shuffleOf(c).isNotEmpty) c: state.shuffleOf(c),
  };

  /// What's picked for an extra: a piece, or none. A new extra starts on
  /// its first piece.
  Garment? _pick(GarmentCategory c, List<Garment> pieces) {
    if (!_picked.containsKey(c)) return pieces.first;
    final id = _picked[c];
    if (id == null) return null;
    for (final g in pieces) {
      if (g.id == id) return g;
    }
    return pieces.first;
  }

  List<Garment> _fit(WardrobeState state) {
    final tray = _trayOf(state);
    return [
      for (final MapEntry(key: c, value: pieces) in tray.entries) ?_pick(c, pieces),
      if (state.shuffleTops.isNotEmpty) _rail(_Row.top).current(state.shuffleTops),
      if (state.shuffleBottoms.isNotEmpty) _rail(_Row.bottom).current(state.shuffleBottoms),
      if (state.railOn(GarmentCategory.shoes) && state.shuffleOf(GarmentCategory.shoes).isNotEmpty)
        _rail(_Row.shoes).current(state.shuffleOf(GarmentCategory.shoes)),
    ];
  }

  Future<void> _shuffle() async {
    if (_spinning) return;
    final state = AppScope.read(context);
    final still = MediaQuery.disableAnimationsOf(context);
    HapticFeedback.mediumImpact();
    setState(() => _spinning = true);

    final moves = <Future<void>>[];
    // Head first: the tray flicks through pieces like a reel and lands.
    final tray = _trayOf(state);
    for (final (i, MapEntry(key: c, value: pieces)) in tray.entries.indexed) {
      if (_kept.contains(c)) continue;
      moves.add(
        _spinExtra(
          c,
          pieces,
          still: still,
          delay: Duration(milliseconds: 60 * i),
        ),
      );
    }
    // Then the rails, each a beat after the one above.
    final rows = {
      _Row.top: state.shuffleTops,
      _Row.bottom: state.shuffleBottoms,
      if (state.railOn(GarmentCategory.shoes)) _Row.shoes: state.shuffleOf(GarmentCategory.shoes),
    };
    var order = 0;
    for (final MapEntry(key: row, value: items) in rows.entries) {
      final rail = _rail(row);
      final n = items.length;
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
            duration: Duration(milliseconds: 1000 + 220 * order),
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

  /// One extra flicks through its pieces, slowing down, and lands on one.
  Future<void> _spinExtra(
    GarmentCategory c,
    List<Garment> pieces, {
    required bool still,
    required Duration delay,
  }) async {
    Garment other(String? not) {
      if (pieces.length == 1) return pieces.first;
      Garment g;
      do {
        g = pieces[_random.nextInt(pieces.length)];
      } while (g.id == not);
      return g;
    }

    if (still) {
      setState(() => _picked[c] = other(_picked[c]).id);
      return;
    }
    await Future.delayed(delay);
    const steps = [70, 80, 95, 115, 140, 170, 210];
    for (final ms in steps) {
      if (!mounted) return;
      setState(() => _picked[c] = other(_picked[c]).id);
      await Future.delayed(Duration(milliseconds: ms));
    }
    if (mounted) HapticFeedback.selectionClick();
  }

  // The heart filling in is the feedback; no snackbar over the buttons.
  void _toggleSave(List<Garment> fit) {
    AppScope.read(context).toggleFit([for (final g in fit) g.id]);
    HapticFeedback.lightImpact();
  }

  /// Puts a saved fit back on: rows it needs turn on, the tray takes its
  /// extras, and the rails slide to its pieces.
  void _showFit(SavedFit fit) {
    final state = AppScope.read(context);
    final pieces = fit.itemIds.map(state.garmentById).whereType<Garment>().toList();
    for (final g in pieces) {
      if (WardrobeState.extraRails.contains(g.category) && !state.railOn(g.category)) {
        state.setRail(g.category, true);
      }
    }
    setState(() {
      for (final c in _extras) {
        final match = pieces.where((g) => g.category == c);
        _picked[c] = match.isEmpty ? null : match.first.id;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rows = {
        _Row.top: state.shuffleTops,
        _Row.bottom: state.shuffleBottoms,
        if (state.railOn(GarmentCategory.shoes)) _Row.shoes: state.shuffleOf(GarmentCategory.shoes),
      };
      final targets = <_RailState, int>{};
      for (final MapEntry(key: row, value: items) in rows.entries) {
        final index = items.indexWhere((g) => fit.itemIds.contains(g.id));
        if (index == -1) {
          if (row == _Row.shoes) continue;
          showMessage(context, S.of(context).fitNotReady);
          return;
        }
        final rail = _rail(row);
        final n = items.length;
        final base = rail.page - rail.page % n;
        // The copy of that piece nearest to where the row is now.
        final options = [base - n + index, base + index, base + n + index];
        options.sort((a, b) => (a - rail.page).abs().compareTo((b - rail.page).abs()));
        targets[rail] = options.first;
      }
      HapticFeedback.selectionClick();
      for (final MapEntry(key: rail, value: target) in targets.entries) {
        if (rail.controller.hasClients) {
          rail.controller.animateToPage(
            target,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  /// The Rails menu. Choices apply as it closes, so you watch rows arrive
  /// or fold away instead of missing it behind the sheet.
  Future<void> _openRails() async {
    final state = AppScope.read(context);
    final chosen = {
      for (final c in WardrobeState.extraRails)
        if (state.railOn(c)) c,
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RailsSheet(chosen: chosen),
    );
    if (!mounted) return;
    for (final c in WardrobeState.extraRails) {
      if (state.railOn(c) != chosen.contains(c)) state.setRail(c, chosen.contains(c));
    }
  }

  void _openSaved() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => _SavedFitsSheet(
        onOpen: (fit) {
          Navigator.of(sheet).pop();
          SavedFitSheet.show(context, fit, onShow: () => _showFit(fit));
        },
      ),
    );
  }

  Future<void> _choose(GarmentCategory c, List<Garment> pieces) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ExtraPicker(
        category: c,
        pieces: pieces,
        selected: _pick(c, pieces)?.id,
        kept: _kept.contains(c),
        onPick: (id) => setState(() => _picked[c] = id),
        onKeep: (keep) => setState(() => keep ? _kept.add(c) : _kept.remove(c)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final tops = state.shuffleTops, bottoms = state.shuffleBottoms;
    final ready = tops.isNotEmpty && bottoms.isNotEmpty;
    final shoes = state.railOn(GarmentCategory.shoes) ? state.shuffleOf(GarmentCategory.shoes) : const <Garment>[];
    final tray = _trayOf(state);
    final still = MediaQuery.disableAnimationsOf(context);
    for (final r in _rails.values) {
      r.still = still;
    }
    _noteArrivals({if (shoes.isNotEmpty) 'shoes', if (tray.isNotEmpty) 'tray'});
    final fit = ready ? _fit(state) : const <Garment>[];
    final saved = ready && state.isFitSaved(fit.map((g) => g.id));

    return Scaffold(
      // Shuffle and the heart stay within reach, above the tab bar.
      bottomNavigationBar: ready ? _actionBar(context, s, fit, saved) : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaticTitle(
            title: s.fitShuffle,
            actions: [
              IconButton(
                tooltip: s.savedFits,
                onPressed: _openSaved,
                icon: Badge(
                  isLabelVisible: state.fits.isNotEmpty,
                  backgroundColor: context.ink,
                  textColor: context.colors.surface,
                  label: Text('${state.fits.length}'),
                  child: const Icon(AppIcons.favoriteOutline),
                ),
              ),
              IconButton(tooltip: s.customizeRails, onPressed: _openRails, icon: const Icon(AppIcons.rails)),
            ],
          ),
          Expanded(
            child: !ready
                ? EmptyState(icon: AppIcons.shuffle, title: s.shuffleEmptyTitle, body: s.shuffleEmptyBody)
                : _rows(context, s, tops, bottoms, shoes, tray),
          ),
        ],
      ),
    );
  }

  Widget _actionBar(BuildContext context, S s, List<Garment> fit, bool saved) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
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
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                  child: child,
                ),
                child: Icon(saved ? AppIcons.favorite : AppIcons.favoriteOutline, key: ValueKey(saved)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              // Stays black while the rails spin; a second tap is ignored
              // rather than greying the button out mid-moment.
              child: FilledButton.icon(
                onPressed: _shuffle,
                icon: const Icon(AppIcons.shuffle, size: 20),
                label: Text(s.shuffle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The rows share the screen's height: the tray takes what it needs, the
  /// rails and the shelf split the rest. Nothing scrolls, nothing hides.
  /// When the shelf or tray comes or goes, the others glide to make room.
  Widget _rows(
    BuildContext context,
    S s,
    List<Garment> tops,
    List<Garment> bottoms,
    List<Garment> shoes,
    Map<GarmentCategory, List<Garment>> tray,
  ) {
    final still = MediaQuery.disableAnimationsOf(context);
    final glide = still ? Duration.zero : const Duration(milliseconds: 600);
    void lock(_Row row) {
      HapticFeedback.selectionClick();
      setState(() => _rail(row).locked = !_rail(row).locked);
    }

    void changed(int page, _Row row) {
      if (_spinning) HapticFeedback.selectionClick();
      setState(() => _rail(row).page = page);
    }

    if (shoes.isNotEmpty) _lastShoes = shoes;
    if (tray.isNotEmpty) _lastTray = tray;

    return TweenAnimationBuilder<Offset>(
      // dx: how open the shelf is; dy: how open the tray is.
      tween: Tween(end: Offset(shoes.isNotEmpty ? 1 : 0, tray.isNotEmpty ? 1 : 0)),
      duration: glide,
      curve: Curves.easeOutCubic,
      builder: (context, open, _) {
        final shelfOpen = open.dx, trayOpen = open.dy;
        final shelfShoes = _lastShoes;
        final trayItems = _lastTray;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (trayOpen > 0.001 && trayItems != null)
              ClipRect(
                key: const ValueKey('tray-slot'),
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: trayOpen,
                  child: Opacity(
                    opacity: Curves.easeIn.transform(trayOpen),
                    child: _Tray(
                      tray: trayItems,
                      pick: _pick,
                      kept: _kept,
                      arriving: _fresh('tray'),
                      onChoose: _choose,
                      onKeep: (c) {
                        HapticFeedback.mediumImpact();
                        setState(() => _kept.contains(c) ? _kept.remove(c) : _kept.add(c));
                      },
                    ),
                  ),
                ),
              ),
            Expanded(
              key: const ValueKey('top-slot'),
              flex: 100,
              child: _Rail(
                key: const ValueKey(_Row.top),
                label: s.categoryLabel(GarmentCategory.tops),
                items: tops,
                rail: _rail(_Row.top),
                onLock: () => lock(_Row.top),
                onPageChanged: (p) => changed(p, _Row.top),
              ),
            ),
            Expanded(
              key: const ValueKey('bottom-slot'),
              flex: 100,
              child: _Rail(
                key: const ValueKey(_Row.bottom),
                label: s.categoryLabel(GarmentCategory.bottoms),
                items: bottoms,
                rail: _rail(_Row.bottom),
                onLock: () => lock(_Row.bottom),
                onPageChanged: (p) => changed(p, _Row.bottom),
              ),
            ),
            if ((72 * shelfOpen).round() > 0 && shelfShoes != null)
              Expanded(
                key: const ValueKey('shoes-slot'),
                flex: (72 * shelfOpen).round(),
                child: Opacity(
                  opacity: Curves.easeIn.transform(shelfOpen),
                  child: _Shelf(
                    key: const ValueKey(_Row.shoes),
                    label: s.categoryLabel(GarmentCategory.shoes),
                    items: shelfShoes,
                    rail: _rail(_Row.shoes),
                    arriving: _fresh('shoes'),
                    onLock: () => lock(_Row.shoes),
                    onPageChanged: (p) => changed(p, _Row.shoes),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Kept while the shelf or tray folds away, after they've been turned off.
  List<Garment>? _lastShoes;
  Map<GarmentCategory, List<Garment>>? _lastTray;
}

/// A row's title and its lock.
class _RowHeader extends StatelessWidget {
  final String label;
  final bool locked;
  final VoidCallback onLock;

  const _RowHeader({required this.label, required this.locked, required this.onLock});

  static const height = 40.0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
        child: Row(
          children: [
            Expanded(child: Text(label, style: context.text.titleSmall)),
            IconButton(
              tooltip: locked ? s.unlockRail(label) : s.lockRail(label),
              onPressed: onLock,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  locked ? AppIcons.locked : AppIcons.unlocked,
                  key: ValueKey(locked),
                  size: 20,
                  color: locked ? context.ink : context.palette.secondaryText,
                ),
              ),
            ),
          ],
        ),
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

/// One rail: a rod across the screen with clothes hanging from it. It
/// sizes its pieces to the height it's given.
class _Rail extends StatelessWidget {
  final String label;
  final List<Garment> items;
  final _RailState rail;
  final VoidCallback onLock;
  final ValueChanged<int> onPageChanged;

  const _Rail({
    super.key,
    required this.label,
    required this.items,
    required this.rail,
    required this.onLock,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // A hairline rod; it turns solid ink when the rail is locked.
    final rodColor = rail.locked ? context.ink : palette.separator;

    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight - _RowHeader.height;
        // Smaller hangers and labels when the row is short.
        final roomy = h > 210;
        final hanger = roomy ? 42.0 : 28.0;
        // The name's line, at the phone's text size.
        final label = MediaQuery.textScalerOf(context).scale(18) + 4;
        final card = min(h - hanger - label, box.maxWidth * 0.56 - 28).clamp(24.0, 240.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RowHeader(label: this.label, locked: rail.locked, onLock: onLock),
            Expanded(
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
                            child: _Hanging(garment: items[i % items.length], size: card, hanger: hanger),
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.18),
              child: GarmentImage(garment: garment),
            ),
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
    constraints: BoxConstraints(maxWidth: max(width, 90)),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: context.text.labelMedium?.copyWith(color: context.ink),
    ),
  );
}

/// The shoe shelf: shoes don't hang, they stand on a thin shelf. They slide
/// along it like the rails, and when they stop they land with a small hop
/// instead of a swing.
class _Shelf extends StatelessWidget {
  final String label;
  final List<Garment> items;
  final _RailState rail;
  final bool arriving;
  final VoidCallback onLock;
  final ValueChanged<int> onPageChanged;

  const _Shelf({
    super.key,
    required this.label,
    required this.items,
    required this.rail,
    required this.onLock,
    required this.onPageChanged,
    this.arriving = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 6.0;
        final height = (box.maxHeight - _RowHeader.height - 30 - gap).clamp(24.0, 160.0);
        final width = min(height * 1.45, box.maxWidth * 0.5);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RowHeader(label: label, locked: rail.locked, onLock: onLock),
            Expanded(
              child: Stack(
                children: [
                  // The shelf, under the shoes.
                  Positioned(
                    top: gap + height + 3,
                    left: 0,
                    right: 0,
                    child: _DrawIn(
                      active: arriving,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: rail.locked ? 3 : 2.5,
                        color: rail.locked ? context.ink : context.palette.separator,
                      ),
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
                              // The swing becomes a hop: up as it "swings", down onto
                              // the shelf, with a hint of tilt on the heel.
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
                            child: _Arrive(
                              active: arriving,
                              land: true,
                              index: (i - rail.page + 1).clamp(0, 3),
                              child: Column(
                                children: [
                                  const SizedBox(height: gap),
                                  SizedBox(
                                    width: width,
                                    height: height,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(min(20, height * 0.25)),
                                      // Shoes are wide and low: closer, so they fill the shelf.
                                      child: GarmentImage(garment: items[i % items.length], zoom: 1.4),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _Name(items[i % items.length].name, width: width),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The tray: a hat, a bag and an accessory, each on its own tile. Tap a
/// tile to choose; press and hold to keep it when shuffling. When Shuffle
/// runs they flick through pieces like a reel and land.
class _Tray extends StatelessWidget {
  final Map<GarmentCategory, List<Garment>> tray;
  final Garment? Function(GarmentCategory, List<Garment>) pick;
  final Set<GarmentCategory> kept;
  final bool arriving;
  final void Function(GarmentCategory, List<Garment>) onChoose;
  final ValueChanged<GarmentCategory> onKeep;

  const _Tray({
    required this.tray,
    required this.pick,
    required this.kept,
    required this.arriving,
    required this.onChoose,
    required this.onKeep,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: [
          for (final (i, MapEntry(key: c, value: pieces)) in tray.entries.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _Pop(
                active: arriving,
                index: i,
                child: _TrayTile(
                  title: s.categoryLabel(c),
                  piece: pick(c, pieces),
                  kept: kept.contains(c),
                  semantic: s.choose(s.categoryLabel(c)),
                  onTap: () => onChoose(c, pieces),
                  onHold: () => onKeep(c),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrayTile extends StatelessWidget {
  final String title;
  final Garment? piece;
  final bool kept;
  final String semantic;
  final VoidCallback onTap;
  final VoidCallback onHold;

  const _TrayTile({
    required this.title,
    required this.piece,
    required this.kept,
    required this.semantic,
    required this.onTap,
    required this.onHold,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Semantics(
      button: true,
      label: '$semantic, ${piece?.name ?? s.none}',
      excludeSemantics: true,
      child: GestureDetector(
        onLongPress: onHold,
        child: Pressable(
          label: semantic,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 86,
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 7),
            decoration: BoxDecoration(
              color: context.palette.tile,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kept ? context.ink : Colors.transparent, width: 1.5),
            ),
            // The piece, and its name (or "No hats") under it.
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            switchInCurve: Curves.easeOutBack,
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: ScaleTransition(scale: Tween(begin: 0.7, end: 1.0).animate(anim), child: child),
                            ),
                            child: piece == null
                                ? Icon(
                                    AppIcons.close,
                                    key: const ValueKey('none'),
                                    size: 18,
                                    color: context.palette.tertiaryText,
                                  )
                                : GarmentImage(
                                    key: ValueKey(piece!.id),
                                    garment: piece!,
                                    iconSize: 22,
                                    backdrop: Colors.transparent,
                                  ),
                          ),
                        ),
                      ),
                      if (kept)
                        Positioned(top: -2, right: 0, child: Icon(AppIcons.locked, size: 12, color: context.ink)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  piece?.name ?? s.noneOf(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: piece == null ? context.palette.secondaryText : context.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tray tiles arriving: they pop in, one after another.
class _Pop extends StatelessWidget {
  final bool active;
  final int index;
  final Widget child;

  const _Pop({required this.active, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!active || MediaQuery.disableAnimationsOf(context)) return child;
    final delay = 0.15 + index * 0.07;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ((delay + 0.55) * 1000).round()),
      builder: (context, v, child) {
        final t = ((v * (delay + 0.55) - delay) / 0.55).clamp(0.0, 1.0);
        return Opacity(
          opacity: (t * 3).clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.85 + 0.15 * Curves.easeOutBack.transform(t), child: child),
        );
      },
      child: child,
    );
  }
}

/// Choosing a hat, bag or accessory: none or one of yours, and whether to
/// keep it when shuffling.
class _ExtraPicker extends StatefulWidget {
  final GarmentCategory category;
  final List<Garment> pieces;
  final String? selected;
  final bool kept;
  final ValueChanged<String?> onPick;
  final ValueChanged<bool> onKeep;

  const _ExtraPicker({
    required this.category,
    required this.pieces,
    required this.selected,
    required this.kept,
    required this.onPick,
    required this.onKeep,
  });

  @override
  State<_ExtraPicker> createState() => _ExtraPickerState();
}

class _ExtraPickerState extends State<_ExtraPicker> {
  late String? _selected = widget.selected;
  late bool _kept = widget.kept;

  void _pick(String? id) {
    HapticFeedback.selectionClick();
    setState(() => _selected = id);
    widget.onPick(id);
    // A moment to see the check, then close.
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget tile(String? id, Widget picture, String name) {
      final on = _selected == id;
      return Pressable(
        label: name,
        onTap: () => _pick(id),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: context.palette.tile,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: on ? context.ink : Colors.transparent, width: 2),
                ),
                child: ClipRRect(borderRadius: BorderRadius.circular(16), child: picture),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: context.ink),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.categoryLabel(widget.category), style: context.text.headlineSmall),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
            children: [
              tile(null, Center(child: Icon(AppIcons.close, color: context.palette.tertiaryText)), s.none),
              for (final g in widget.pieces) tile(g.id, GarmentImage(garment: g, iconSize: 26), g.name),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile.adaptive(
              title: Text(s.keepWhenShuffling),
              secondary: Icon(AppIcons.locked, color: context.ink),
              value: _kept,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _kept = v);
                widget.onKeep(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Saved fits, as a sheet of collages. Tap one to open it.
class _SavedFitsSheet extends StatelessWidget {
  final ValueChanged<SavedFit> onOpen;

  const _SavedFitsSheet({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final fits = state.fits;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.savedFits, style: context.text.headlineSmall),
          const SizedBox(height: 14),
          if (fits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                s.savedFitsEmpty,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText),
              ),
            )
          else
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: fits.length,
                itemBuilder: (context, i) {
                  final pieces = fits[i].itemIds.map(state.garmentById).whereType<Garment>().toList();
                  return Pressable(
                    label: pieces.map((g) => g.name).join(', '),
                    onTap: () => onOpen(fits[i]),
                    child: FitCollage(pieces: pieces, radius: 22, tint: fits[i].tint),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
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

class _Arrive extends StatelessWidget {
  final bool active;
  final bool land;
  final int index;
  final Widget child;

  const _Arrive({required this.active, required this.index, required this.child, this.land = false});

  @override
  Widget build(BuildContext context) {
    if (!active || MediaQuery.disableAnimationsOf(context)) return child;
    final delay = 0.18 + index * 0.08;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ((delay + 0.95) * 1000).round()),
      builder: (context, v, child) {
        // Wait for this piece's turn, then play.
        final t = ((v * (delay + 0.95) - delay) / 0.95).clamp(0.0, 1.0);
        final opacity = (t * 4).clamp(0.0, 1.0);
        if (land) {
          // Dropped in from a little above, a small hop on the shelf, still.
          final drop = -22 * (1 - Curves.easeOutCubic.transform((t / 0.45).clamp(0.0, 1.0)));
          final hop = t > 0.45 ? -5 * sin(pi * ((t - 0.45) / 0.35).clamp(0.0, 1.0)) : 0.0;
          return Opacity(
            opacity: opacity,
            child: Transform.translate(offset: Offset(0, drop + hop), child: child),
          );
        }
        // Hung on: lowered onto the rod, then a damped swing to rest.
        final lower = -16 * (1 - Curves.easeOutCubic.transform((t / 0.4).clamp(0.0, 1.0)));
        final swing = -0.25 * exp(-4.2 * t) * cos(2 * pi * 1.5 * t);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, lower),
            child: Transform.rotate(angle: swing, alignment: Alignment.topCenter, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

class _DrawIn extends StatelessWidget {
  final bool active;
  final Widget child;

  const _DrawIn({required this.active, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!active || MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Transform.scale(scaleX: v, alignment: Alignment.centerLeft, child: child),
      child: child,
    );
  }
}

class _RailsSheet extends StatefulWidget {
  /// What's switched on; changed here, applied when the sheet closes.
  final Set<GarmentCategory> chosen;

  const _RailsSheet({required this.chosen});

  @override
  State<_RailsSheet> createState() => _RailsSheetState();
}

class _RailsSheetState extends State<_RailsSheet> {
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
        value: always || widget.chosen.contains(c),
        onChanged: always
            ? null
            : (on) {
                HapticFeedback.selectionClick();
                setState(() => on ? widget.chosen.add(c) : widget.chosen.remove(c));
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
