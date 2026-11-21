import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/garment_image.dart';
import 'closet_screen.dart';

/// Everything in one wardrobe compartment, opened by tapping it. It grows
/// out of the compartment you tapped, the way an album opens in Photos.
class CategoryScreen extends StatelessWidget {
  final GarmentCategory category;

  const CategoryScreen({super.key, required this.category});

  /// Opens from [from], the compartment's place on screen.
  static Future<void> open(BuildContext context, GarmentCategory category, Rect from) {
    final screen = MediaQuery.sizeOf(context);
    final origin = Alignment(
      (from.center.dx / screen.width) * 2 - 1,
      (from.center.dy / screen.height) * 2 - 1,
    );
    final start = (from.width / screen.width).clamp(0.15, 0.6);
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 480),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (_, _, _) => CategoryScreen(category: category),
        transitionsBuilder: (context, anim, _, child) {
          if (MediaQuery.disableAnimationsOf(context)) return FadeTransition(opacity: anim, child: child);
          final grow = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: const Interval(0, 0.6)),
            child: ScaleTransition(
              scale: Tween(begin: start, end: 1.0).animate(grow),
              alignment: origin,
              child: ClipRRect(
                // Rounded while it grows, square once it's the whole screen.
                borderRadius: BorderRadius.circular(28 * (1 - grow.value)),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final pieces = state.garments.where((g) => g.category == category).toList();
    final home = pieces.where((g) => g.status == GarmentStatus.closet).length;

    return Scaffold(
      appBar: AppBar(
        title: BarTitle(s.categoryLabel(category), subtitle: pieces.isEmpty ? null : s.inWardrobe(home, pieces.length)),
      ),
      body: pieces.isEmpty
          ? EmptyState(icon: categoryIcon(category), title: s.nothingHere, body: s.nothingHereBody)
          : LayoutBuilder(
              builder: (context, c) {
                final columns = (c.maxWidth / 190).floor().clamp(2, 5);
                final labelArea = 14 + MediaQuery.textScalerOf(context).scale(40);
                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 12,
                    mainAxisExtent: (c.maxWidth - 32 - 12 * (columns - 1)) / columns + labelArea,
                  ),
                  itemCount: pieces.length,
                  itemBuilder: (context, i) => GarmentTile(garment: pieces[i]),
                );
              },
            ),
    );
  }
}
