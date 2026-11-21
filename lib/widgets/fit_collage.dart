import 'package:flutter/material.dart';

import '../models/garment.dart';
import '../services/image_store.dart';
import '../theme/app_theme.dart';
import 'garment_image.dart';

/// A saved outfit laid out like a flat-lay photo: the top and bottom big
/// on the left, the hat, bag, accessory and shoes around them on the
/// right. With no extras, the top and bottom stand centered.
class FitCollage extends StatelessWidget {
  final List<Garment> pieces;

  /// Corner radius of the board.
  final double radius;

  const FitCollage({super.key, required this.pieces, this.radius = 24});

  /// Where each kind of piece sits, as fractions of the board:
  /// left, top, width, height.
  static (double, double, double, double)? _slot(GarmentCategory c, bool extras) {
    if (c.isUpper) return extras ? (0.03, 0.03, 0.56, 0.44) : (0.17, 0.02, 0.66, 0.48);
    switch (c) {
      case GarmentCategory.bottoms:
        return extras ? (0.07, 0.44, 0.5, 0.54) : (0.2, 0.47, 0.6, 0.51);
      case GarmentCategory.hats:
        return (0.62, 0.05, 0.33, 0.21);
      case GarmentCategory.bags:
        return (0.6, 0.29, 0.37, 0.29);
      case GarmentCategory.accessories:
        return (0.66, 0.59, 0.26, 0.14);
      case GarmentCategory.shoes:
        return (0.56, 0.74, 0.42, 0.23);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final extras = pieces.any((g) => !g.category.isUpper && g.category != GarmentCategory.bottoms);
    // Bottom-most first, so the top overlaps the waist like a real flat-lay.
    final ordered = [...pieces]..sort((a, b) => _depth(a.category).compareTo(_depth(b.category)));

    return AspectRatio(
      aspectRatio: 0.8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF16203A), Color(0xFF1C1C1E)]
                : const [Color(0xFFE9F0FD), Color(0xFFF5F5F7)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              for (final g in ordered)
                if (_slot(g.category, extras) case (final x, final y, final w, final h))
                  Positioned(
                    left: c.maxWidth * x,
                    top: c.maxHeight * y,
                    width: c.maxWidth * w,
                    height: c.maxHeight * h,
                    child: _Piece(garment: g),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  static int _depth(GarmentCategory c) => switch (c) {
        GarmentCategory.bottoms => 0,
        GarmentCategory.shoes => 1,
        GarmentCategory.bags => 2,
        GarmentCategory.accessories => 3,
        GarmentCategory.hats => 4,
        _ => 5,
      };
}

/// One piece on the board: a cutout floats on it; a plain photo shows as a
/// small rounded print.
class _Piece extends StatelessWidget {
  final Garment garment;

  const _Piece({required this.garment});

  @override
  Widget build(BuildContext context) {
    final cutout = ImageStore.isCutout(garment.imageUrl);
    final image = GarmentImage(garment: garment, iconSize: 22, backdrop: Colors.transparent);
    if (cutout) return image;
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: garment.imageUrl == null ? ColoredBox(color: context.palette.tile, child: image) : image,
        ),
      ),
    );
  }
}
