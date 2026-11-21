import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import 'garment_image.dart';

/// How pieces sit in a compartment.
enum _Kind { rail, long, shelf, cubby, floor }

/// One compartment: what it holds, where it is (in a 312 × 400 drawing),
/// and how its pieces sit.
typedef _Cell = ({GarmentCategory category, Rect rect, _Kind kind});

const _w = 312.0;
const _h = 400.0;

const List<_Cell> _cells = [
  (category: GarmentCategory.hats, rect: Rect.fromLTWH(4, 4, 152, 64), kind: _Kind.shelf),
  (category: GarmentCategory.bags, rect: Rect.fromLTWH(156, 4, 152, 64), kind: _Kind.shelf),
  (category: GarmentCategory.tops, rect: Rect.fromLTWH(4, 68, 124, 126), kind: _Kind.rail),
  (category: GarmentCategory.bottoms, rect: Rect.fromLTWH(4, 194, 124, 126), kind: _Kind.rail),
  (category: GarmentCategory.accessories, rect: Rect.fromLTWH(128, 68, 64, 126), kind: _Kind.cubby),
  (category: GarmentCategory.delicates, rect: Rect.fromLTWH(128, 194, 64, 126), kind: _Kind.cubby),
  (category: GarmentCategory.outerwear, rect: Rect.fromLTWH(192, 68, 116, 252), kind: _Kind.long),
  (category: GarmentCategory.shoes, rect: Rect.fromLTWH(4, 320, 304, 76), kind: _Kind.floor),
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
      final pieces = all.where((g) => g.category == cell.category).toList()
        ..sort((a, b) => (_away(a) ? 1 : 0).compareTo(_away(b) ? 1 : 0));
      final (size, step) = switch (cell.kind) {
        _Kind.rail => (42.0, 46.0),
        _Kind.long => (46.0, 50.0),
        _Kind.shelf => (46.0, 52.0),
        _Kind.cubby => (46.0, 48.0),
        _Kind.floor => (52.0, 60.0),
      };
      // Leave room at the end for a "+2" when more don't fit.
      final room = pieces.length * step > r.width - 14 ? r.width - 30 : r.width - 14;
      final capacity = max(1, (room / step).floor());
      final shown = pieces.take(capacity).toList();
      final slots = <_Slot>[];
      final span = step * (shown.length - 1);
      final more = pieces.length > shown.length;
      for (final (i, g) in shown.indexed) {
        final cx = r.center.dx - span / 2 + step * i - (more ? 8 : 0);
        switch (cell.kind) {
          case _Kind.rail || _Kind.long:
            final rod = r.top + 14;
            final top = rod + 9;
            final height = cell.kind == _Kind.long ? r.height - 50 : size;
            slots.add((box: Rect.fromLTWH(cx - size / 2, top, size, min(height, size * 2.2)), hook: Offset(cx, rod), garment: g, away: _away(g)));
          case _Kind.shelf:
            slots.add((box: Rect.fromLTWH(cx - size / 2, r.top + 6, size, size), hook: null, garment: g, away: _away(g)));
          case _Kind.cubby:
            final y = r.top + (r.height - size) / 2 - 6;
            slots.add((box: Rect.fromLTWH(cx - size / 2, y, size, size), hook: null, garment: g, away: _away(g)));
          case _Kind.floor:
            slots.add((box: Rect.fromLTWH(cx - size / 2, r.top + 60 - size - 3, size, size), hook: null, garment: g, away: _away(g)));
        }
      }
      out[cell.category] = (slots, pieces.length - shown.length);
    }
    return out;
  }

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
                    faint: palette.tertiaryText,
                    press: context.ink.withValues(alpha: 0.06),
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
              // "+2" beside the last piece, when more don't fit.
              for (final cell in _cells)
                if (slots[cell.category]!.$2 > 0)
                  Positioned(
                    left: (min(slots[cell.category]!.$1.last.box.right + 2, cell.rect.right - 26)) * k,
                    top: (slots[cell.category]!.$1.last.box.center.dy - 9) * k,
                    child: IgnorePointer(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 5 * k, vertical: 2 * k),
                        decoration: BoxDecoration(color: context.ink, borderRadius: BorderRadius.circular(99)),
                        child: Text(
                          '+${slots[cell.category]!.$2}',
                          style: context.text.labelSmall?.copyWith(fontSize: 9 * k.clamp(1.0, 1.3), color: context.colors.surface),
                        ),
                      ),
                    ),
                  ),
              // Each compartment's name, count, and anything that didn't fit.
              for (final cell in _cells)
                Positioned.fromRect(
                  rect: px(cell.rect),
                  child: Builder(
                    builder: (cellContext) {
                      final all = state.garments.where((g) => g.category == cell.category).toList();
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
              // Two doors that swing open on their hinges the first time,
              // turning toward you until they're edge-on and gone. Solid
              // the whole way; they shade a little as they turn from the light.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _doors,
                    builder: (context, _) {
                      final t = Curves.easeInOutCubic.transform(_doors.value);
                      if (t >= 1) return const SizedBox.shrink();
                      final half = c.maxWidth / 2;
                      final angle = t * pi / 2;
                      Widget door(bool left) => Positioned(
                        left: left ? 2 * k : null,
                        right: left ? null : 2 * k,
                        top: 2 * k,
                        bottom: 2 * k,
                        width: half - 2 * k,
                        child: Transform(
                          alignment: left ? Alignment.centerLeft : Alignment.centerRight,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateY(left ? angle : -angle),
                          child: _Door(handleOnRight: left, k: k, shade: sin(angle) * 0.22),
                        ),
                      );
                      return Stack(clipBehavior: Clip.none, children: [door(true), door(false)]);
                    },
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

  /// How much the door darkens as it turns away from the light.
  final double shade;

  const _Door({required this.handleOnRight, required this.k, this.shade = 0});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(Colors.black.withValues(alpha: shade), context.palette.tile),
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
  final Color ink, tile, faint, press;

  _WardrobePainter({
    required this.k,
    required this.slots,
    required this.pressed,
    required this.ink,
    required this.tile,
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
        canvas.drawLine(Offset(r.left + 10, r.top + 60), Offset(r.right - 10, r.top + 60), rod..strokeWidth = 2.5);
      }
    }

    // Hangers, and dashed outlines where a piece is out.
    final hanger = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round;
    for (final (list, _) in slots.values) {
      for (final slot in list) {
        final hook = slot.hook;
        if (hook != null) {
          final w = slot.box.width * 0.42;
          final path = Path()
            ..moveTo(hook.dx + 2.2, hook.dy - 2.5)
            ..quadraticBezierTo(hook.dx + 2.8, hook.dy + 0.5, hook.dx, hook.dy + 1.2)
            ..lineTo(hook.dx, hook.dy + 3)
            ..lineTo(hook.dx - w, hook.dy + 9)
            ..lineTo(hook.dx + w, hook.dy + 9)
            ..close();
          hanger.color = faint;
          canvas.drawPath(slot.away ? _dashed(path, 2, 2) : path, hanger);
        }
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
