import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A strip of black-and-white floor tiles, the laundromat checkerboard.
class CheckerStrip extends StatelessWidget {
  final double height;

  const CheckerStrip({super.key, this.height = 10});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _CheckerPainter(
            tile: height / (height > 14 ? 2 : 1),
            a: dark ? const Color(0xFF2C3036) : SignColors.ink,
            b: dark ? const Color(0xFF121417) : SignColors.chalk,
          ),
        ),
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  final double tile;
  final Color a;
  final Color b;

  _CheckerPainter({required this.tile, required this.a, required this.b});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = b);
    final paint = Paint()..color = a;
    for (var row = 0; row * tile < size.height; row++) {
      for (var col = row.isEven ? 0 : 1; col * tile < size.width; col += 2) {
        canvas.drawRect(Rect.fromLTWH(col * tile, row * tile, tile, tile), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => old.tile != tile || old.a != a || old.b != b;
}

/// A tab's title as a laundromat sign board: tall Anton letters on a
/// painted color, a trim line and the checkerboard under it. It collapses
/// to a slim bar on scroll, like a large title.
class StoreSign extends StatelessWidget {
  final String title;
  final Color color;
  final List<Widget>? actions;

  const StoreSign({super.key, required this.title, required this.color, this.actions});

  static const _checker = 10.0;
  static const _trim = 3.0;

  @override
  Widget build(BuildContext context) {
    // Mustard is light, so it takes ink letters; every other sign is white.
    final onSign = color == SignColors.mustard ? SignColors.ink : Colors.white;
    final trim = color == SignColors.mustard ? SignColors.ink : SignColors.mustard;
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: onSign)),
      ),
      child: SliverAppBar(
        pinned: true,
        expandedHeight: 128,
        backgroundColor: color,
        foregroundColor: onSign,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: onSign == Colors.white ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        actions: actions,
        flexibleSpace: FlexibleSpaceBar(
          titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: _checker + _trim + 12),
          expandedTitleScale: 1.55,
          title: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(color: onSign, fontSize: 24, letterSpacing: 1.6, height: 1),
          ),
          background: Align(
            alignment: Alignment.bottomCenter,
            child: Container(height: _trim, margin: const EdgeInsets.only(bottom: _checker), color: trim),
          ),
        ),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(_checker), child: CheckerStrip(height: _checker)),
      ),
    );
  }
}
