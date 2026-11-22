import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../services/samples.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// Little looping films for the welcome, one per idea, drawn with the same
/// tiles and sample clothes as the app itself: a photo losing its
/// background, rails shuffling into a fit, a worn piece dropping into the
/// hamper, and a load being checked back in.
///
/// Each plays only while its page is showing, and holds one telling frame
/// when the phone asks for reduced motion.

/// The canvas every scene is drawn on; scaled to fit the page.
const _w = 320.0, _h = 300.0;

/// Progress of [t] through [a]..[b], 0 before and 1 after, eased.
double _seg(double t, double a, double b, [Curve curve = Curves.easeInOutCubic]) =>
    curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

/// Up and back down: 0 → 1 → 0 as [x] goes 0 → 1.
double _bump(double x) => math.sin(math.pi * x.clamp(0.0, 1.0));

String _art(String name) => 'assets/samples/$name.png';

/// Runs a scene's clock while [active], in seconds since it became active.
class SceneClock extends StatefulWidget {
  final bool active;

  /// The moment shown, in seconds, when motion is reduced.
  final double still;
  final Widget Function(BuildContext context, double seconds) builder;

  const SceneClock({super.key, required this.active, required this.still, required this.builder});

  @override
  State<SceneClock> createState() => _SceneClockState();
}

class _SceneClockState extends State<SceneClock> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((elapsed) => setState(() => _seconds = elapsed.inMicroseconds / 1e6));
  double _seconds = 0;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(SceneClock old) {
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
  Widget build(BuildContext context) {
    final seconds = _reduced ? widget.still : _seconds;
    return LayoutBuilder(
      builder: (context, c) {
        final width = math.min(c.maxWidth, _w);
        return SizedBox(
          width: width,
          height: width * _h / _w,
          child: FittedBox(child: SizedBox(width: _w, height: _h, child: widget.builder(context, seconds))),
        );
      },
    );
  }
}

/// A garment on its gray tile, the way the app shows every piece.
class _Tile extends StatelessWidget {
  final String art;
  final double size;
  final Color? color;

  const _Tile(this.art, {this.size = 110, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color ?? context.palette.tile, borderRadius: BorderRadius.circular(size * 0.18)),
      padding: EdgeInsets.all(size * 0.09),
      child: Image.asset(_art(art)),
    );
  }
}

/// A fingertip, for showing where to tap.
class _Finger extends StatelessWidget {
  final double press;

  const _Finger({this.press = 0});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 1 - 0.18 * press,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.ink.withValues(alpha: 0.16 + 0.14 * press),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3))],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- scan

/// A photo of a shirt on the floor: the shutter blinks, the floor melts
/// away and the shirt rises onto its tile.
class ScanScene extends StatelessWidget {
  final bool active;

  const ScanScene({super.key, required this.active});

  static const _period = 4.6;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SceneClock(
      active: active,
      still: _period * 0.8,
      builder: (context, secs) {
        final t = (secs % _period) / _period;
        final shown = math.min(_seg(t, 0, 0.06), 1 - _seg(t, 0.93, 1));
        final aim = _seg(t, 0.02, 0.2, Curves.easeOutCubic);
        final flash = _bump(_seg(t, 0.22, 0.3, Curves.linear));
        final lift = _seg(t, 0.34, 0.62, Curves.easeOutCubic);
        final chip = _seg(t, 0.62, 0.72, Curves.easeOutBack);
        const card = Size(220, 270);

        return Opacity(
          opacity: shown,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The photo: a shirt on a wooden floor.
              Container(
                width: card.width,
                height: card.height,
                decoration: BoxDecoration(
                  color: context.palette.tile,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.10 * lift), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Opacity(opacity: 1 - lift, child: const _Floor()),
              ),
              // A soft shadow on the tile as the shirt rises off it.
              Transform.translate(
                offset: const Offset(0, 92),
                child: Opacity(
                  opacity: lift,
                  child: Container(
                    width: 130 - 20 * lift,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 16, spreadRadius: 2),
                      ],
                    ),
                  ),
                ),
              ),
              // The shirt lifting out.
              Transform.translate(
                offset: Offset(0, -12 * lift),
                child: Transform.scale(
                  scale: 0.92 + 0.12 * lift,
                  child: Image.asset(_art('shirt'), width: 176),
                ),
              ),
              // Viewfinder corners, closing in to aim.
              Opacity(
                opacity: 1 - lift,
                child: SizedBox(
                  width: card.width - 36 + 30 * (1 - aim),
                  height: card.height - 36 + 30 * (1 - aim),
                  child: const CustomPaint(painter: _Corners()),
                ),
              ),
              // The shutter.
              IgnorePointer(
                child: Container(
                  width: card.width,
                  height: card.height,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85 * flash),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                child: Transform.scale(
                  scale: chip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: context.ink, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.cutoutOn, size: 16, color: context.colors.surface),
                        const SizedBox(width: 6),
                        Text(s.sceneCutoutChip,
                            style: context.text.labelMedium?.copyWith(color: context.colors.surface)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Floorboards behind the photographed shirt.
class _Floor extends StatelessWidget {
  const _Floor();

  @override
  Widget build(BuildContext context) {
    const boards = [Color(0xFFB99674), Color(0xFFAE8B69), Color(0xFFC19E7C), Color(0xFFA9865F), Color(0xFFB7936F)];
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

class _Corners extends CustomPainter {
  const _Corners();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 26.0;
    final w = size.width, h = size.height;
    for (final (x, y, dx, dy) in [(0.0, 0.0, 1, 1), (w, 0.0, -1, 1), (0.0, h, 1, -1), (w, h, -1, -1)]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * l)
          ..lineTo(x, y)
          ..lineTo(x + dx * l, y),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_Corners old) => false;
}

// ---------------------------------------------------------------- shuffle

/// Two rails, tops over bottoms, sliding into a new fit each time the
/// Shuffle button is pressed.
class ShuffleScene extends StatelessWidget {
  final bool active;

  const ShuffleScene({super.key, required this.active});

  static const _period = 2.6;
  static const _tops = ['tee', 'shirt', 'coat', 'hoodie', 'blouse'];
  static const _bottoms = ['jeans', 'chinos'];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SceneClock(
      active: active,
      still: 0.9,
      builder: (context, secs) {
        final cycle = (secs / _period).floor();
        final t = (secs % _period) / _period;
        final press = _bump(_seg(t, 0.0, 0.16, Curves.linear));
        final top = cycle + _seg(t, 0.08, 0.52, Curves.easeOutBack);
        final bottom = cycle + _seg(t, 0.2, 0.66, Curves.easeOutBack);

        return Column(
          children: [
            _Rail(items: _tops, position: top),
            const SizedBox(height: 6),
            _Rail(items: _bottoms, position: bottom),
            const SizedBox(height: 12),
            Transform.scale(
              scale: 1 - 0.06 * press,
              child: Container(
                width: 200,
                height: 44,
                decoration: BoxDecoration(color: context.ink, borderRadius: BorderRadius.circular(22)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.shuffle, size: 18, color: context.colors.surface),
                    const SizedBox(width: 8),
                    Text(s.shuffle, style: context.text.labelLarge?.copyWith(color: context.colors.surface)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Rail extends StatelessWidget {
  final List<String> items;
  final double position;

  const _Rail({required this.items, required this.position});

  @override
  Widget build(BuildContext context) {
    const size = 100.0, gap = 122.0;
    final base = position.floor();
    return SizedBox(
      width: _w,
      height: 118,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(left: 0, right: 0, top: 6, child: Container(height: 2, color: context.palette.separator)),
          Positioned(
            left: _w / 2 - 14,
            top: 0,
            child: Icon(AppIcons.closet, size: 28, color: context.palette.tertiaryText),
          ),
          for (var k = base - 2; k <= base + 3; k++)
            Builder(builder: (context) {
              final off = k - position;
              final away = off.abs().clamp(0.0, 1.0);
              return Positioned(
                left: _w / 2 + off * gap - size / 2,
                top: 16,
                child: Opacity(
                  opacity: 1 - 0.6 * away,
                  child: Transform.scale(scale: 1 - 0.14 * away, child: _Tile(items[k % items.length], size: size)),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- hamper

/// A finger taps Wore it on a tee; the tee drops into the hamper and the
/// hamper's count goes up.
class HamperScene extends StatelessWidget {
  final bool active;

  const HamperScene({super.key, required this.active});

  static const _period = 4.2;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SceneClock(
      active: active,
      still: _period * 0.36,
      builder: (context, secs) {
        final t = (secs % _period) / _period;
        final appear = _seg(t, 0, 0.08);
        final reach = _seg(t, 0.08, 0.3, Curves.easeInOutCubic);
        final press = _bump(_seg(t, 0.3, 0.4, Curves.linear));
        final pressed = t > 0.34;
        final drop = _seg(t, 0.44, 0.72, Curves.easeInCubic);
        final landed = t > 0.72;
        final pop = _bump(_seg(t, 0.72, 0.84, Curves.linear));
        final fingerAway = _seg(t, 0.42, 0.56);

        const tile = 150.0;
        const tileLeft = (_w - tile) / 2, tileTop = 12.0;
        const button = Offset(tileLeft + tile - 26, tileTop + tile - 26);
        const hamper = Offset(_w / 2, 250);
        final start = const Offset(_w - 40, _h - 20);
        final finger = Offset.lerp(start, button, reach)! + Offset(0, 40 * fingerAway);

        // The tee falls along a gentle curve and shrinks into the hamper.
        final from = const Offset(_w / 2, tileTop + tile / 2);
        final fly = Offset(
          from.dx + (hamper.dx - from.dx) * drop,
          from.dy + (hamper.dy - from.dy) * drop - 40 * _bump(drop),
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // The hamper and how many pieces are in it.
            Positioned(
              left: hamper.dx - 34,
              top: hamper.dy - 34,
              child: Transform.scale(
                scale: 1 + 0.12 * pop,
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(child: Icon(AppIcons.hamperFill, size: 56, color: context.ink)),
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.ink, width: 2),
                          ),
                          child: Text(
                            landed ? '3' : '2',
                            style: context.text.labelMedium?.copyWith(color: context.ink, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: hamper.dy + 32,
              child: Text(s.hamper, textAlign: TextAlign.center, style: context.text.labelMedium),
            ),
            // The tee with its Wore it button.
            Positioned(
              left: fly.dx - tile / 2,
              top: fly.dy - tile / 2,
              child: Opacity(
                opacity: appear * (1 - _seg(t, 0.66, 0.74)),
                child: Transform.scale(
                  scale: 1 - 0.8 * drop,
                  child: SizedBox(
                    width: tile,
                    height: tile,
                    child: Stack(
                      children: [
                        const _Tile('tee', size: tile),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Transform.scale(
                            scale: 1 + 0.15 * press,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: pressed ? context.ink : context.colors.surface,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
                              ),
                              child: Icon(AppIcons.wore, size: 19, color: pressed ? context.colors.surface : context.ink),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: finger.dx - 19,
              top: finger.dy - 19,
              child: Opacity(
                opacity: _seg(t, 0.06, 0.14) * (1 - fingerAway),
                child: _Finger(press: press),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ check

/// A load back from the laundromat: two pieces get ticked, Finish check is
/// pressed, and the one that didn't come back turns up missing, with a
/// message ready for the laundromat.
class CheckScene extends StatelessWidget {
  final bool active;

  const CheckScene({super.key, required this.active});

  static const _period = 5.6;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SceneClock(
      active: active,
      still: _period * 0.8,
      builder: (context, secs) {
        final t = (secs % _period) / _period;
        final shown = math.min(_seg(t, 0, 0.05), 1 - _seg(t, 0.94, 1));
        final ticks = [_seg(t, 0.12, 0.2, Curves.easeOutBack), _seg(t, 0.28, 0.36, Curves.easeOutBack)];
        final finish = _bump(_seg(t, 0.44, 0.52, Curves.linear));
        final missing = _seg(t, 0.52, 0.6);
        final ask = _seg(t, 0.64, 0.74, Curves.easeOutBack);
        final back = (ticks[0] > 0.5 ? 1 : 0) + (ticks[1] > 0.5 ? 1 : 0);
        final rows = [
          ('shirt', Samples.name('shirt', s)),
          ('chinos', Samples.name('chinos', s)),
          ('hoodie', Samples.name('hoodie', s)),
        ];

        return Opacity(
          opacity: shown,
          child: Column(
            children: [
              Container(
                width: 290,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                decoration: BoxDecoration(color: context.palette.tile, borderRadius: BorderRadius.circular(22)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(AppIcons.laundry, size: 18, color: context.ink),
                        const SizedBox(width: 8),
                        Text(s.loadNo(1), style: context.text.titleSmall),
                        const Spacer(),
                        Text(s.backCount(back, 3), style: context.text.labelMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final (i, (art, name)) in rows.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            _Tile(art, size: 44, color: context.colors.surface),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: context.text.titleSmall?.copyWith(fontSize: 14)),
                                  if (i == 2)
                                    SizedBox(
                                      height: 16 * missing,
                                      child: Opacity(
                                        opacity: missing,
                                        child: Text(
                                          s.statusLabel(GarmentStatus.missing),
                                          style: context.text.labelSmall?.copyWith(color: context.palette.signal),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (i < 2)
                              _Check(on: ticks[i])
                            else
                              Opacity(
                                opacity: 1 - missing,
                                child: const _Check(on: 0),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: 1 - _seg(t, 0.56, 0.64),
                      child: Transform.scale(
                        scale: 1 - 0.06 * finish,
                        child: _Pill(label: s.finishReturn, icon: AppIcons.checkAll, filled: true),
                      ),
                    ),
                    Transform.scale(
                      scale: ask,
                      child: _Pill(label: s.askLaundromat, icon: AppIcons.chat, filled: false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Check extends StatelessWidget {
  final double on;

  const _Check({required this.on});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(AppIcons.unchecked, size: 28, color: context.palette.tertiaryText),
          Transform.scale(scale: on, child: Icon(AppIcons.checked, size: 28, color: context.ink)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;

  const _Pill({required this.label, required this.icon, required this.filled});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? context.colors.surface : context.palette.signal;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: filled ? context.ink : context.palette.signal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Text(label, style: context.text.labelLarge?.copyWith(color: fg)),
        ],
      ),
    );
  }
}
