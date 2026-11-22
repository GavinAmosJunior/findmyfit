import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../services/samples.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// The welcome's film: an iPhone running FindMyFit, filmed the way Apple
/// films its apps: close on the one thing that matters, one fingertip,
/// one slow camera move, then rest.
///
/// Four chapters, one per welcome page, in the order you'd use the app:
/// add your clothes, pick an outfit, wear it, check what comes back from
/// the laundry. The screens are drawn from the app's own pieces.

/// How long each chapter plays, in seconds. It plays once and rests on
/// its last frame.
const filmSeconds = 3.6;

// The phone's screen, in iPhone points, and the film's frame.
const _sw = 390.0, _sh = 844.0;
const _fw = 340.0, _fh = 420.0;

/// Progress of [t] through [a]..[b], 0 before and 1 after, eased.
double _seg(double t, double a, double b, [Curve curve = Curves.easeInOutCubic]) =>
    curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

/// 0 → 1 → 0 as [x] goes 0 → 1.
double _bump(double x) => math.sin(math.pi * x.clamp(0.0, 1.0));

String _art(String name) => 'assets/samples/$name.png';

/// Runs a clock while [active], in seconds since it started.
class FilmClock extends StatefulWidget {
  final bool active;

  /// Shown when motion is reduced.
  final double still;

  /// When it stops by itself, in seconds; null runs on.
  final double? until;
  final Widget Function(BuildContext context, double seconds) builder;

  const FilmClock({super.key, required this.active, required this.still, this.until, required this.builder});

  @override
  State<FilmClock> createState() => _FilmClockState();
}

class _FilmClockState extends State<FilmClock> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((e) {
    setState(() => _seconds = e.inMicroseconds / 1e6);
    final until = widget.until;
    if (until != null && _seconds >= until) _ticker.stop();
  });
  double _seconds = 0;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(FilmClock old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    final run = widget.active && !_reduced;
    if (run && !_ticker.isActive) {
      _seconds = 0;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _reduced ? widget.still : _seconds);
}

/// Where the camera is: how close, and which point of the screen sits in
/// the middle of the frame.
typedef _Shot = ({double zoom, Offset focus});

/// The camera between [shots] (time, shot), eased.
_Shot _camera(double t, List<(double, _Shot)> shots) {
  if (t <= shots.first.$1) return shots.first.$2;
  for (var i = 1; i < shots.length; i++) {
    final (t1, b) = shots[i];
    if (t <= t1) {
      final (t0, a) = shots[i - 1];
      final k = Curves.easeInOutCubic.transform((t - t0) / (t1 - t0));
      return (zoom: a.zoom + (b.zoom - a.zoom) * k, focus: Offset.lerp(a.focus, b.focus, k)!);
    }
  }
  return shots.last.$2;
}

/// The film for [chapter] at [t] (0..1 through the chapter).
class AppFilm extends StatelessWidget {
  final int chapter;
  final double t;

  const AppFilm({super.key, required this.chapter, required this.t});

  @override
  Widget build(BuildContext context) {
    final (screen, shot) = switch (chapter) {
      0 => _add(context, t),
      1 => _shuffle(context, t),
      2 => _wear(context, t),
      _ => _check(context, t),
    };
    // Zoom 1 fits the screen's width to the frame; the focus sits in
    // the middle, kept inside the screen.
    final scale = _fw / _sw * shot.zoom;
    final halfH = _fh / 2 / scale, halfW = _fw / 2 / scale;
    final center = Offset(
      shot.focus.dx.clamp(halfW, _sw - halfW),
      shot.focus.dy.clamp(halfH, _sh - halfH),
    );
    final fade = math.min(_seg(t, 0, 0.05, Curves.linear), 1 - _seg(t, 0.95, 1, Curves.linear));

    return LayoutBuilder(
      builder: (context, c) {
        final w = math.min(c.maxWidth, _fw);
        return SizedBox(
          width: w,
          height: w * _fh / _fw,
          child: FittedBox(
            child: SizedBox(
              width: _fw,
              height: _fh,
              // A soft gray stage, the way Apple shows a phone on its pages.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: ColoredBox(
                  color: context.colors.surface,
                  child: Opacity(
                    opacity: fade,
                    child: OverflowBox(
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      alignment: Alignment.topLeft,
                      child: Transform(
                        transform: Matrix4.identity()
                          ..translateByDouble(_fw / 2, _fh / 2, 0, 1)
                          ..scaleByDouble(scale, scale, 1, 1)
                          ..translateByDouble(-center.dx, -center.dy, 0, 1),
                        child: SizedBox(width: _sw, height: _sh, child: ColoredBox(color: context.colors.surface, child: screen)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- add

  /// Tap +, the camera opens on a shirt lying on the floor, the shutter
  /// blinks, and the shirt lifts off its background while its name is
  /// typed.
  (Widget, _Shot) _add(BuildContext context, double t) {
    const card = Offset(_sw / 2, 380);
    final shot = _camera(t, [
      (0.0, (zoom: 1.0, focus: card)),
      (1.0, (zoom: 1.08, focus: card)),
    ]);
    final lift = _seg(t, 0.2, 0.5, Curves.easeOutCubic);
    final typed = _seg(t, 0.55, 0.8, Curves.linear);

    final s = S.of(context);
    final screen = _AddScreen(s: s, lift: lift, name: Samples.name('shirt', s), typed: typed);
    return (screen, shot);
  }

  // --------------------------------------------------------- shuffle

  /// Fit Shuffle: the rails slide into a new outfit at each tap.
  (Widget, _Shot) _shuffle(BuildContext context, double t) {
    const button = Offset(_sw / 2 + 30, _sh - 140);
    final shot = _camera(t, [
      (0.0, (zoom: 1.0, focus: const Offset(_sw / 2, 520))),
      (1.0, (zoom: 1.05, focus: const Offset(_sw / 2, 520))),
    ]);
    final taps = [0.3];
    // After the slide the pieces swing on their hangers and settle.
    double swing(double from) {
      final secs = (t - from) * filmSeconds;
      return secs <= 0 ? 0 : 0.14 * math.exp(-3.5 * secs) * math.sin(11 * secs);
    }
    var top = 0.0, bottom = 0.0;
    for (final (i, at) in taps.indexed) {
      top += _seg(t, at + 0.02, at + 0.12) * (i + 1);
      bottom += _seg(t, at + 0.08, at + 0.18);
    }
    final press = taps.map((a) => _bump(_seg(t, a - 0.02, a + 0.04, Curves.linear))).reduce(math.max);
    final s = S.of(context);
    final screen = Stack(
      children: [
        _FitsScreen(s: s, top: top, bottom: bottom, press: press, swingTop: swing(0.4), swingBottom: swing(0.46)),
        _FingerAt(t: t, taps: [for (final a in taps) (a, button)]),
      ],
    );
    return (screen, shot);
  }

  // ------------------------------------------------------------ wear

  /// Wore it on the white tee: it drops out of the closet and the Hamper
  /// tab counts one more.
  (Widget, _Shot) _wear(BuildContext context, double t) {
    final wore = _ClosetScreen.woreButton(0);
    final hamperTab = _TabBar.tabCenter(2);
    final shot = _camera(t, [
      (0.4, (zoom: 1.0, focus: wore + const Offset(0, 120))),
      (0.75, (zoom: 1.0, focus: hamperTab - const Offset(0, 120))),
    ]);
    final s = S.of(context);
    final screen = Stack(
      children: [
        _ClosetScreen(
          s: s,
          wornPress: _bump(_seg(t, 0.18, 0.26, Curves.linear)),
          worn: t > 0.22,
          gone: _seg(t, 0.28, 0.48, Curves.easeInCubic),
          hamperCount: t > 0.8 ? 3 : 2,
          hamperPop: _bump(_seg(t, 0.8, 0.92, Curves.linear)),
        ),
        _FingerAt(t: t, taps: [(0.22, wore)]),
      ],
    );
    return (screen, shot);
  }

  // ----------------------------------------------------------- check

  /// A load back from the laundromat: tick, tick, Finish check, and the
  /// hoodie that didn't come back is marked missing.
  (Widget, _Shot) _check(BuildContext context, double t) {
    final rows = [for (var i = 0; i < 3; i++) _LoadScreen.check(i)];
    final shot = _camera(t, [
      (0.0, (zoom: 1.0, focus: const Offset(_sw / 2, 300))),
      (1.0, (zoom: 1.05, focus: const Offset(_sw / 2, 300))),
    ]);
    final s = S.of(context);
    final screen = Stack(
      children: [
        _LoadScreen(
          s: s,
          ticks: [_seg(t, 0.18, 0.26, Curves.easeOutBack), _seg(t, 0.38, 0.46, Curves.easeOutBack)],
          finishPress: 0,
          missing: _seg(t, 0.62, 0.76),
          ask: 0,
        ),
        _FingerAt(t: t, taps: [(0.2, rows[0]), (0.4, rows[1])]),
      ],
    );
    return (screen, shot);
  }
}

/// and lifts away.
class _FingerAt extends StatelessWidget {
  final double t;
  final List<(double, Offset)> taps;

  const _FingerAt({required this.t, required this.taps});

  @override
  Widget build(BuildContext context) {
    // The tap that's next or happening.
    final i = taps.indexWhere((tap) => t < tap.$1 + 0.06);
    if (i == -1) return const SizedBox();
    final (at, point) = taps[i];
    final from = i == 0 ? point + const Offset(60, 160) : taps[i - 1].$2;
    final arrive = _seg(t, at - 0.1, at - 0.02);
    final press = _bump(_seg(t, at - 0.02, at + 0.04, Curves.linear));
    final shown = math.min(_seg(t, at - 0.14, at - 0.08), 1 - _seg(t, at + 0.03, at + 0.06));
    final p = Offset.lerp(from, point, arrive)!;
    return Positioned(
      left: p.dx - 22,
      top: p.dy - 22,
      child: IgnorePointer(
        child: Opacity(
          opacity: i == 0 ? shown : math.max(shown, 1 - _seg(t, at - 0.12, at - 0.1)),
          child: Transform.scale(
            scale: 1 - 0.18 * press,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withValues(alpha: 0.35 + 0.2 * press),
                border: Border.all(color: Colors.white.withValues(alpha: 0.95), width: 3),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- screens

/// A garment on its gray tile.
class _Tile extends StatelessWidget {
  final String art;
  final double size;
  final Color? color;

  const _Tile(this.art, {required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color ?? context.palette.tile, borderRadius: BorderRadius.circular(size * 0.14)),
      padding: EdgeInsets.all(size * 0.1),
      child: Image.asset(_art(art)),
    );
  }
}

class _LargeTitle extends StatelessWidget {
  final String text;

  const _LargeTitle(this.text);

  @override
  Widget build(BuildContext context) =>
      Positioned(left: 20, top: 104, child: Text(text, style: context.text.displaySmall));
}

/// The floating tab bar with its round + button.
class _TabBar extends StatelessWidget {
  final S s;
  final int selected;
  final int hamperCount;
  final double hamperPop;

  const _TabBar({required this.s, this.selected = 0, this.hamperCount = 0, this.hamperPop = 0});

  static const _top = _sh - 34 - 64;
  static const _barWidth = _sw - 32 - 64 - 12;

  static Offset tabCenter(int i) => Offset(16 + _barWidth / 8 * (2 * i + 1), _top + 32);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (s.closet, AppIcons.closet, AppIcons.closetFill),
      (s.fits, AppIcons.fits, AppIcons.fitsFill),
      (s.hamper, AppIcons.hamper, AppIcons.hamperFill),
      (s.laundry, AppIcons.laundry, AppIcons.laundryFill),
    ];
    return Positioned(
      left: 16,
      right: 16,
      top: _top,
      child: Row(
        children: [
          Container(
            width: _barWidth,
            height: 64,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                for (final (i, (label, icon, fill)) in tabs.indexed)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              i == selected ? fill : icon,
                              size: 24,
                              color: i == selected ? context.ink : context.palette.secondaryText,
                            ),
                            if (i == 2 && hamperCount > 0)
                              Positioned(
                                right: -10,
                                top: -6,
                                child: Transform.scale(
                                  scale: 1 + 0.35 * hamperPop,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: context.ink,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Text(
                                      '$hamperCount',
                                      style: context.text.labelSmall?.copyWith(
                                        color: context.colors.surface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: context.text.labelSmall?.copyWith(
                            fontSize: 10.5,
                            color: i == selected ? context.ink : context.palette.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: context.ink, shape: BoxShape.circle),
            child: Icon(AppIcons.add, color: context.colors.surface, size: 28),
          ),
        ],
      ),
    );
  }
}

/// Closet: a grid of pieces, each with its Wore it button.
class _ClosetScreen extends StatelessWidget {
  final S s;
  final double wornPress;
  final bool worn;
  final double gone;
  final int hamperCount;
  final double hamperPop;

  const _ClosetScreen({
    required this.s,
    this.wornPress = 0,
    this.worn = false,
    this.gone = 0,
    this.hamperCount = 2,
    this.hamperPop = 0,
  });

  static const _pieces = ['tee', 'jeans', 'coat', 'sneakers', 'cap', 'tote'];
  static const _tile = (_sw - 32 - 12) / 2, _top = 168.0, _row = _tile + 56;

  static Offset _cell(int i) => Offset(16 + (i % 2) * (_tile + 12), _top + (i ~/ 2) * _row);
  static Offset woreButton(int i) => _cell(i) + const Offset(_tile - 28, _tile - 28);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _LargeTitle(s.closet),
        for (final (i, art) in _pieces.indexed)
          Positioned(
            left: _cell(i).dx,
            top: _cell(i).dy + (i == 0 ? 120 * gone : 0),
            child: Opacity(
              opacity: i == 0 ? 1 - gone : 1,
              child: Transform.scale(
                scale: i == 0 ? 1 - 0.6 * gone : 1,
                child: SizedBox(
                  width: _tile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          _Tile(art, size: _tile),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Transform.scale(
                              scale: i == 0 ? 1 + 0.2 * wornPress : 1,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: i == 0 && worn ? context.ink : context.colors.surface,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
                                ),
                                child: Icon(
                                  AppIcons.wore,
                                  size: 20,
                                  color: i == 0 && worn ? context.colors.surface : context.ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(Samples.name(art, s), style: context.text.titleSmall),
                      Text(s.statusLabel(GarmentStatus.closet), style: context.text.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          ),
        _TabBar(s: s, hamperCount: hamperCount, hamperPop: hamperPop),
      ],
    );
  }
}

/// Floorboards under the photographed shirt.
class _Floor extends StatelessWidget {
  const _Floor();

  @override
  Widget build(BuildContext context) {
    const boards = [
      Color(0xFFB99674),
      Color(0xFFAE8B69),
      Color(0xFFC19E7C),
      Color(0xFFA9865F),
      Color(0xFFB7936F),
      Color(0xFFAE8B69),
    ];
    return Column(
      children: [
        for (final c in boards)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: c,
                border: const Border(bottom: BorderSide(color: Color(0x33000000), width: 1.5)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Add clothes: the photo losing its background, and the name typed in.
class _AddScreen extends StatelessWidget {
  final S s;
  final double lift;
  final String name;
  final double typed;

  const _AddScreen({required this.s, required this.lift, required this.name, required this.typed});

  @override
  Widget build(BuildContext context) {
    final shown = name.substring(0, (name.length * typed).round());
    return Container(
      width: _sw,
      height: _sh,
      color: context.colors.surface,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 64,
            child: Text(s.addClothes, textAlign: TextAlign.center, style: context.text.titleMedium),
          ),
          Positioned(
            left: 20,
            top: 110,
            child: Container(
              width: _sw - 40,
              height: 380,
              decoration: BoxDecoration(color: context.palette.tile, borderRadius: BorderRadius.circular(28)),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Opacity(opacity: 1 - lift, child: const _Floor()),
                  ),
                  Transform.translate(
                    offset: Offset(0, 96 - 6 * lift),
                    child: Opacity(
                      opacity: lift,
                      child: Container(
                        width: 160,
                        height: 18,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 18, spreadRadius: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, -12 * lift),
                    child: Transform.scale(scale: 0.95 + 0.1 * lift, child: Image.asset(_art('shirt'), width: 230)),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 512,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: context.palette.tile,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.ink, width: typed > 0 ? 1.5 : 0),
              ),
              child: Row(
                children: [
                  Text(
                    shown.isEmpty ? s.name : shown,
                    style: context.text.bodyLarge?.copyWith(
                      color: shown.isEmpty ? context.palette.secondaryText : null,
                    ),
                  ),
                  if (typed > 0 && typed < 1) Container(width: 2, height: 22, color: context.ink),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 60,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: context.palette.tile, borderRadius: BorderRadius.circular(27)),
                    child: Text(s.add, style: context.text.labelLarge),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: context.ink, borderRadius: BorderRadius.circular(27)),
                    child: Text(s.addAndNext, style: context.text.labelLarge?.copyWith(color: context.colors.surface)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fit Shuffle: tops over bottoms on hanging rails, and the Shuffle button.
class _FitsScreen extends StatelessWidget {
  final S s;
  final double top;
  final double bottom;
  final double press;
  final double swingTop;
  final double swingBottom;

  const _FitsScreen({
    required this.s,
    required this.top,
    required this.bottom,
    required this.press,
    this.swingTop = 0,
    this.swingBottom = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _LargeTitle(s.fitShuffle),
        Positioned(
          left: 0,
          right: 0,
          top: 190,
          child: _Rail(items: const ['tee', 'shirt', 'coat', 'hoodie', 'blouse'], position: top, swing: swingTop),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 420,
          child: _Rail(items: const ['jeans', 'chinos'], position: bottom, swing: swingBottom),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: _sh - 172,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: context.palette.tile, shape: BoxShape.circle),
                child: Icon(AppIcons.favoriteOutline, color: context.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Transform.scale(
                  scale: 1 - 0.05 * press,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(color: context.ink, borderRadius: BorderRadius.circular(28)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.shuffle, color: context.colors.surface, size: 20),
                        const SizedBox(width: 8),
                        Text(s.shuffle, style: context.text.labelLarge?.copyWith(color: context.colors.surface)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _TabBar(s: s, selected: 1),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  final List<String> items;
  final double position;
  final double swing;

  const _Rail({required this.items, required this.position, this.swing = 0});

  @override
  Widget build(BuildContext context) {
    const size = 170.0, gap = 200.0;
    final base = position.floor();
    return SizedBox(
      height: 210,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(left: 0, right: 0, top: 8, child: Container(height: 2, color: context.palette.separator)),
          Positioned(
            left: _sw / 2 - 18,
            top: 0,
            child: Icon(AppIcons.closet, size: 36, color: context.palette.tertiaryText),
          ),
          for (var k = base - 2; k <= base + 3; k++)
            Builder(
              builder: (context) {
                final off = k - position;
                final away = off.abs().clamp(0.0, 1.0);
                return Positioned(
                  left: _sw / 2 + off * gap - size / 2,
                  top: 30,
                  child: Opacity(
                    opacity: 1 - 0.6 * away,
                    child: Transform.rotate(
                      alignment: Alignment.topCenter,
                      angle: (off * 0.09).clamp(-0.16, 0.16) + swing * (off.abs() < 0.5 ? 1 : 0.7),
                      child: Transform.scale(
                        scale: 1 - 0.15 * away,
                        child: _Tile(items[k % items.length], size: size),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// A load back from the laundromat, being checked in.
class _LoadScreen extends StatelessWidget {
  final S s;
  final List<double> ticks;
  final double finishPress;
  final double missing;
  final double ask;

  const _LoadScreen({
    required this.s,
    required this.ticks,
    required this.finishPress,
    required this.missing,
    required this.ask,
  });

  static const _rowsTop = 232.0, _rowH = 84.0;
  static const _pieces = ['shirt', 'chinos', 'hoodie'];

  static Offset check(int i) => Offset(_sw - 44, _rowsTop + i * _rowH + _rowH / 2);

  @override
  Widget build(BuildContext context) {
    final back = ticks.where((x) => x > 0.5).length;
    return Stack(
      children: [
        _LargeTitle(s.loadNo(1)),
        Positioned(
          left: 20,
          top: 152,
          child: Text(
            '${s.sampleLaundromat} · ${s.backCount(back, 3)}',
            style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText),
          ),
        ),
        for (final (i, art) in _pieces.indexed)
          Positioned(
            left: 16,
            right: 16,
            top: _rowsTop + i * _rowH,
            height: _rowH - 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: context.palette.tile, borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  _Tile(art, size: 56, color: context.colors.surface),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Samples.name(art, s), style: context.text.titleSmall),
                        if (i == 2 && missing > 0)
                          Opacity(
                            opacity: missing,
                            child: Text(
                              s.statusLabel(GarmentStatus.missing),
                              style: context.text.bodySmall?.copyWith(color: context.palette.signal),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: i == 2 ? 1 - missing : 1,
                          child: Icon(AppIcons.unchecked, size: 30, color: context.palette.tertiaryText),
                        ),
                        if (i < 2)
                          Transform.scale(
                            scale: ticks[i],
                            child: Icon(AppIcons.checked, size: 30, color: context.ink),
                          ),
                        if (i == 2)
                          Opacity(
                            opacity: missing,
                            child: Icon(AppIcons.warning, size: 26, color: context.palette.signal),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: _rowsTop + 3 * _rowH + 18,
          child: Center(
            child: Transform.scale(
              scale: ask,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  color: context.palette.signal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.chat, size: 20, color: context.palette.signal),
                    const SizedBox(width: 8),
                    Text(s.askLaundromat, style: context.text.labelLarge?.copyWith(color: context.palette.signal)),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: _sh - 138,
          child: Opacity(
            opacity: 1 - _seg(missing, 0.6, 1),
            child: Transform.scale(
              scale: 1 - 0.05 * finishPress,
              child: Container(
                height: 56,
                decoration: BoxDecoration(color: context.ink, borderRadius: BorderRadius.circular(28)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.checkAll, color: context.colors.surface, size: 20),
                    const SizedBox(width: 8),
                    Text(s.finishReturn, style: context.text.labelLarge?.copyWith(color: context.colors.surface)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
