import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../theme/app_icons.dart';
import 'garment_image.dart';

/// How pieces sit in a compartment.
enum _Kind { rail, long, shelf, cubby, floor }

/// One compartment: what it holds, where it is (in a 312 × 412 drawing),
/// and how its pieces sit.
typedef _Cell = ({GarmentCategory category, Rect rect, _Kind kind});

const _w = 312.0;
const _h = 412.0;

const List<_Cell> _cells = [
  (category: GarmentCategory.hats, rect: Rect.fromLTWH(4, 4, 152, 64), kind: _Kind.shelf),
  (category: GarmentCategory.bags, rect: Rect.fromLTWH(156, 4, 152, 64), kind: _Kind.shelf),
  (category: GarmentCategory.tops, rect: Rect.fromLTWH(4, 68, 124, 126), kind: _Kind.rail),
  (category: GarmentCategory.bottoms, rect: Rect.fromLTWH(4, 194, 124, 126), kind: _Kind.rail),
  (category: GarmentCategory.accessories, rect: Rect.fromLTWH(128, 68, 64, 126), kind: _Kind.cubby),
  (category: GarmentCategory.delicates, rect: Rect.fromLTWH(128, 194, 64, 126), kind: _Kind.cubby),
  (category: GarmentCategory.outerwear, rect: Rect.fromLTWH(192, 68, 116, 252), kind: _Kind.long),
  (category: GarmentCategory.shoes, rect: Rect.fromLTWH(4, 320, 304, 88), kind: _Kind.floor),
];

/// Where one piece goes in the drawing, in drawing units.
typedef _Slot = ({Rect box, Offset? hook, Garment garment, bool away});

/// Whether a piece is out of the wardrobe: in the hamper, at the laundry or
/// missing. It leaves an empty, dashed hanger behind.
bool _away(Garment g) => g.status != GarmentStatus.closet;

/// The Closet as a real wardrobe: a clean line drawing with your pieces
/// inside, each kind in its own compartment. Pieces that are out (hamper,
/// laundry, missing) leave a dashed hanger. Tap a compartment to see what's
/// in it.
///
/// The doors slide open the first time it shows ([openDoors]).
class WardrobeView extends StatefulWidget {
  final bool openDoors;
  final void Function(GarmentCategory category, Rect globalRect) onOpen;

  const WardrobeView({super.key, required this.onOpen, this.openDoors = true});

  @override
  State<WardrobeView> createState() => _WardrobeViewState();
}

class _WardrobeViewState extends State<WardrobeView> with SingleTickerProviderStateMixin {
  late final _doors = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  GarmentCategory? _pressed;

  @override
  void initState() {
    super.initState();
    if (widget.openDoors) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          _doors.value = 1;
        } else {
          _doors.forward();
        }
      });
    } else {
      _doors.value = 1;
    }
  }

  @override
  void dispose() {
    _doors.dispose();
    super.dispose();
  }

  /// Lays out the pieces in each compartment, home first, then the ones out.
  Map<GarmentCategory, (List<_Slot>, int)> _slots(List<Garment> all) {
    final out = <GarmentCategory, (List<_Slot>, int)>{};
    for (final cell in _cells) {
      final r = cell.rect;
      final pieces = all.where((g) => g.category.compartment == cell.category && g.status != GarmentStatus.lost).toList()
        ..sort((a, b) => (_away(a) ? 1 : 0).compareTo(_away(b) ? 1 : 0));
      final (size, step) = switch (cell.kind) {
        _Kind.rail => (42.0, 46.0),
        _Kind.long => (46.0, 50.0),
        _Kind.shelf => (46.0, 52.0),
        _Kind.cubby => (46.0, 48.0),
        _Kind.floor => (52.0, 60.0),
      };
      // When more don't fit, leave a little room for the stack behind the
      // last piece.
      final room = pieces.length * step > r.width - 14 ? r.width - 24 : r.width - 14;
      final capacity = max(1, (room / step).floor());
      final shown = pieces.take(capacity).toList();
      final slots = <_Slot>[];
      final span = step * (shown.length - 1);
      final more = pieces.length > shown.length;
      for (final (i, g) in shown.indexed) {
        final cx = r.center.dx - span / 2 + step * i - (more ? 5 : 0);
        switch (cell.kind) {
          case _Kind.rail || _Kind.long:
            final rod = r.top + 14;
            // Hung from a hanger like the ones in Fit Shuffle.
            final top = rod + _hangerSize(size) * 0.55;
            final height = cell.kind == _Kind.long ? r.height - 60 : size;
            slots.add((box: Rect.fromLTWH(cx - size / 2, top, size, min(height, size * 2.2)), hook: Offset(cx, rod), garment: g, away: _away(g)));
          case _Kind.shelf:
            slots.add((box: Rect.fromLTWH(cx - size / 2, r.top + 6, size, size), hook: null, garment: g, away: _away(g)));
          case _Kind.cubby:
            final y = r.top + (r.height - size) / 2 - 6;
            slots.add((box: Rect.fromLTWH(cx - size / 2, y, size, size), hook: null, garment: g, away: _away(g)));
          case _Kind.floor:
            // Standing on the shelf, with room for the name below it.
            slots.add((box: Rect.fromLTWH(cx - size / 2, r.top + _shelf - size - 3, size, size), hook: null, garment: g, away: _away(g)));
        }
      }
      out[cell.category] = (slots, pieces.length - shown.length);
    }
    return out;
  }

  /// The hanger's size for a piece of [size].
  static double _hangerSize(double size) => size * 0.8;

  /// How far down the shoe compartment its shelf runs.
  static const _shelf = 62.0;

  void _open(BuildContext cellContext, GarmentCategory c) {
    final box = cellContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    HapticFeedback.selectionClick();
    widget.onOpen(c, box.localToGlobal(Offset.zero) & box.size);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final slots = _slots(state.garments);
    final palette = context.palette;

    return AspectRatio(
      aspectRatio: _w / _h,
      child: LayoutBuilder(
        builder: (context, c) {
          final k = c.maxWidth / _w;
          Rect px(Rect r) => Rect.fromLTWH(r.left * k, r.top * k, r.width * k, r.height * k);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // The frame, panels, rods and hangers.
              Positioned.fill(
                child: CustomPaint(
                  // The same grays as Fit Shuffle's rails and hangers.
                  painter: _WardrobePainter(
                    k: k,
                    slots: slots,
                    pressed: _pressed,
                    ink: palette.separator,
                    tile: context.colors.surface,
                    card: palette.tile,
                    faint: palette.tertiaryText,
                    press: context.ink.withValues(alpha: 0.06),
                  ),
                ),
              ),
              // Hangers: the same as the ones on Fit Shuffle's rails.
              for (final MapEntry(value: (list, _)) in slots.entries)
                for (final slot in list)
                  if (slot.hook != null)
                    Positioned(
                      left: (slot.hook!.dx - _hangerSize(slot.box.width) / 2) * k,
                      top: (slot.hook!.dy - _hangerSize(slot.box.width) * 0.16) * k,
                      child: IgnorePointer(
                        child: Icon(
                          AppIcons.closet,
                          size: _hangerSize(slot.box.width) * k,
                          color: palette.tertiaryText.withValues(alpha: slot.away ? 0.5 : 1),
                        ),
                      ),
                    ),
              // The pieces themselves.
              for (final MapEntry(value: (list, _)) in slots.entries)
                for (final slot in list)
                  if (!slot.away)
                    Positioned.fromRect(
                      rect: px(slot.box),
                      child: IgnorePointer(
                        // On a gray tile, like the cards in Fit Shuffle.
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(slot.box.width * 0.2 * k),
                          child: GarmentImage(garment: slot.garment, iconSize: 14 * k),
                        ),
                      ),
                    ),
              // Each compartment's name, count, and anything that didn't fit.
              for (final cell in _cells)
                Positioned.fromRect(
                  rect: px(cell.rect),
                  child: Builder(
                    builder: (cellContext) {
                      final all = state.garments
                          .where((g) => g.category.compartment == cell.category && g.status != GarmentStatus.lost)
                          .toList();
                      final away = all.where(_away).length;
                      return Semantics(
                        button: true,
                        label: '${s.categoryLabel(cell.category)}, ${s.items(all.length)}',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) => setState(() => _pressed = cell.category),
                          onTapCancel: () => setState(() => _pressed = null),
                          onTapUp: (_) => setState(() => _pressed = null),
                          onTap: () => _open(cellContext, cell.category),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(7 * k, 0, 7 * k, 4 * k),
                            child: MediaQuery.withClampedTextScaling(
                              maxScaleFactor: 1.15,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          s.categoryLabel(cell.category),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.text.labelSmall?.copyWith(fontSize: 9.5 * k.clamp(1.0, 1.3)),
                                        ),
                                      ),
                                      Text(
                                        away > 0 ? '${all.length - away}/${all.length}' : '${all.length}',
                                        style: context.text.labelSmall?.copyWith(
                                          fontSize: 9.5 * k.clamp(1.0, 1.3),
                                          color: context.ink,
                                          fontWeight: FontWeight.w700,
                                          fontFeatures: const [ui.FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // Sliding doors that glide apart the first time, into the
              // sides of the wardrobe, like pocket doors. Solid the whole
              // way: they disappear behind the frame, never fade.
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10 * k),
                    child: AnimatedBuilder(
                      animation: _doors,
                      builder: (context, _) {
                        final t = Curves.easeInOutCubic.transform(_doors.value);
                        if (t >= 1) return const SizedBox.shrink();
                        final half = c.maxWidth / 2;
                        Widget door(bool left) => Positioned(
                          left: left ? 2 * k - t * half : null,
                          right: left ? null : 2 * k - t * half,
                          top: 2 * k,
                          bottom: 2 * k,
                          width: half - 2 * k,
                          child: _Door(handleOnRight: left, k: k),
                        );
                        return Stack(children: [door(true), door(false)]);
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Door extends StatelessWidget {
  final bool handleOnRight;
  final double k;

  const _Door({required this.handleOnRight, required this.k});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.tile,
        border: Border.all(color: context.palette.separator, width: 2),
        borderRadius: BorderRadius.circular(8 * k),
      ),
      child: Align(
        alignment: handleOnRight ? const Alignment(0.82, -0.1) : const Alignment(-0.82, -0.1),
        child: Container(
          width: 4 * k,
          height: 56 * k,
          decoration: BoxDecoration(color: context.palette.tertiaryText, borderRadius: BorderRadius.circular(2 * k)),
        ),
      ),
    );
  }
}

class _WardrobePainter extends CustomPainter {
  final double k;
  final Map<GarmentCategory, (List<_Slot>, int)> slots;
  final GarmentCategory? pressed;
  final Color ink, tile, card, faint, press;

  _WardrobePainter({
    required this.k,
    required this.slots,
    required this.pressed,
    required this.ink,
    required this.tile,
    required this.card,
    required this.faint,
    required this.press,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(k);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / k.clamp(0.8, 1.6) * 1.1
      ..strokeCap = StrokeCap.round;

    // The body.
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(2, 2, _w - 4, _h - 4), const Radius.circular(10));
    canvas.drawRRect(body, Paint()..color = tile);
    if (pressed != null) {
      final cell = _cells.firstWhere((c) => c.category == pressed);
      canvas.drawRect(cell.rect, Paint()..color = press);
    }
    canvas.drawRRect(body, line..strokeWidth = 2.4);

    // Panels between the compartments.
    line.strokeWidth = 1.8;
    canvas.drawLine(const Offset(4, 68), const Offset(_w - 4, 68), line);
    canvas.drawLine(const Offset(156, 4), const Offset(156, 68), line);
    canvas.drawLine(const Offset(128, 68), const Offset(128, 320), line);
    canvas.drawLine(const Offset(192, 68), const Offset(192, 320), line);
    canvas.drawLine(const Offset(4, 194), const Offset(192, 194), line);
    canvas.drawLine(const Offset(4, 320), const Offset(_w - 4, 320), line);

    // Rods, and the shoe shelf.
    final rod = Paint()
      ..color = ink
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final cell in _cells) {
      final r = cell.rect;
      if (cell.kind == _Kind.rail || cell.kind == _Kind.long) {
        canvas.drawLine(Offset(r.left + 7, r.top + 14), Offset(r.right - 7, r.top + 14), rod);
      }
      if (cell.kind == _Kind.floor) {
        canvas.drawLine(
          Offset(r.left + 10, r.top + _WardrobeViewState._shelf),
          Offset(r.right - 10, r.top + _WardrobeViewState._shelf),
          rod..strokeWidth = 2.5,
        );
      }
    }

    // When more don't fit: a stack of cards peeking out behind the last
    // piece, the way Photos shows a stack. The count is in the label.
    for (final (list, more) in slots.values) {
      if (more == 0 || list.isEmpty) continue;
      final last = list.last.box;
      for (final (i, shift) in [(2, 7.0), (1, 3.5)]) {
        final peek = Rect.fromCenter(
          center: last.center + Offset(shift, 0),
          width: last.width * (1 - 0.06 * i),
          height: last.height * (1 - 0.06 * i),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(peek, Radius.circular(last.width * 0.2)),
          Paint()..color = Color.lerp(card, ink, i == 2 ? 0.9 : 0.45)!,
        );
      }
    }

    // Dashed outlines where a piece is out.
    for (final (list, _) in slots.values) {
      for (final slot in list) {
        if (slot.away) {
          final box = slot.box.deflate(slot.box.width * 0.18);
          final outline = Path()..addRRect(RRect.fromRectAndRadius(box, const Radius.circular(5)));
          canvas.drawPath(_dashed(outline, 3, 3), Paint()
            ..color = faint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
        }
      }
    }
  }

  static Path _dashed(Path source, double on, double off) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        out.addPath(metric.extractPath(d, min(d + on, metric.length)), Offset.zero);
        d += on + off;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_WardrobePainter old) =>
      old.k != k || old.slots != slots || old.pressed != pressed || old.ink != ink || old.tile != tile;
}
