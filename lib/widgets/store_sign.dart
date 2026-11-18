import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Ink or white letters, whichever reads on a sign color.
Color onSignColor(Color sign) => sign == SignColors.mustard ? SignColors.ink : Colors.white;

/// The paint for a sign. An ink sign would vanish into the dark background,
/// so in dark mode it becomes a lighter charcoal board.
Color signFill(BuildContext context, Color sign) =>
    sign == SignColors.ink && Theme.of(context).brightness == Brightness.dark ? const Color(0xFF30343B) : sign;

/// The laundromat checkerboard: two rows of black and white floor tiles.
///
/// Tiles are snapped to whole device pixels and drawn without
/// anti-aliasing, so every edge is sharp and every tile the same size.
class CheckerStrip extends StatelessWidget {
  /// Height of the whole strip; each tile is half of it.
  final double height;

  const CheckerStrip({super.key, this.height = 12});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _CheckerPainter(
            tile: height / 2,
            dpr: MediaQuery.devicePixelRatioOf(context),
            a: dark ? const Color(0xFF34383F) : SignColors.ink,
            b: dark ? const Color(0xFF121417) : SignColors.chalk,
          ),
        ),
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  final double tile;
  final double dpr;
  final Color a;
  final Color b;

  _CheckerPainter({required this.tile, required this.dpr, required this.a, required this.b});

  @override
  void paint(Canvas canvas, Size size) {
    // Work in physical pixels so tile edges land exactly on pixel edges.
    final px = (tile * dpr).roundToDouble().clamp(1.0, double.infinity);
    final unit = px / dpr;
    canvas.drawRect(Offset.zero & size, Paint()..color = b);
    final paint = Paint()
      ..color = a
      ..isAntiAlias = false;
    for (var row = 0; row < 2; row++) {
      for (var col = row; col * unit < size.width; col += 2) {
        canvas.drawRect(Rect.fromLTWH(col * unit, row * unit, unit, unit), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => old.tile != tile || old.dpr != dpr || old.a != a || old.b != b;
}

/// A tab's title as a laundromat sign board: tall Anton letters on a
/// painted color with the checkerboard under it. It collapses to a slim
/// bar on scroll, like a large title.
class StoreSign extends StatelessWidget {
  final String title;
  final Color color;
  final List<Widget>? actions;

  const StoreSign({super.key, required this.title, required this.color, this.actions});

  static const _checker = 12.0;

  @override
  Widget build(BuildContext context) {
    final onSign = onSignColor(color);
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: onSign)),
      ),
      child: SliverAppBar(
        pinned: true,
        expandedHeight: 128,
        backgroundColor: signFill(context, color),
        foregroundColor: onSign,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: onSign == Colors.white ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        actions: actions,
        flexibleSpace: FlexibleSpaceBar(
          titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: _checker + 12),
          expandedTitleScale: 1.55,
          title: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(color: onSign, fontSize: 24, letterSpacing: 1.6, height: 1),
          ),
        ),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(_checker), child: CheckerStrip(height: _checker)),
      ),
    );
  }
}

/// The same sign, as a regular top bar for screens pushed on top of a tab
/// (the add form, the return check, Settings): sign color, letters, back or
/// close button, and the checkerboard under it.
class SignBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Color color;
  final Widget? leading;
  final List<Widget>? actions;

  const SignBar({super.key, required this.title, required this.color, this.subtitle, this.leading, this.actions});

  static const _checker = 12.0;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (subtitle == null ? 0 : 8) + _checker);

  @override
  Widget build(BuildContext context) {
    final onSign = onSignColor(color);
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: onSign)),
      ),
      child: AppBar(
        backgroundColor: signFill(context, color),
        foregroundColor: onSign,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: onSign == Colors.white ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        toolbarHeight: kToolbarHeight + (subtitle == null ? 0 : 8),
        leading: leading,
        actions: actions,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(color: onSign, fontSize: 21, letterSpacing: 1.3, height: 1.1),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: onSign.withValues(alpha: 0.85)),
              ),
          ],
        ),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(_checker), child: CheckerStrip(height: _checker)),
      ),
    );
  }
}

/// The top of a bottom sheet as a small sign: a painted band with the
/// handle and the title in sign letters, then the checkerboard. Use with
/// `showDragHandle: false` and an anti-aliased clip on the sheet.
class SheetSign extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color color;

  const SheetSign({super.key, required this.title, required this.color, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final onSign = onSignColor(color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: signFill(context, color),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: onSign.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.headlineSmall?.copyWith(color: onSign, fontSize: 24, letterSpacing: 1.3, height: 1.1),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(subtitle!, style: TextStyle(fontSize: 13, color: onSign.withValues(alpha: 0.85))),
                ),
            ],
          ),
        ),
        const CheckerStrip(),
      ],
    );
  }
}
