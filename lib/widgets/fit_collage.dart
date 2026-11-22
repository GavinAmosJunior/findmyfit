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

  /// A saved fit's color, from [tints]; null for the app's own board.
  final int? tint;

  /// No board behind the pieces, for laying them on something else.
  final bool plain;

  const FitCollage({super.key, required this.pieces, this.radius = 24, this.tint, this.plain = false});

  /// Soft board colors a saved fit can wear: sky, peach, mint, lilac, sand.
  static const tints = [
    [Color(0xFFE6EEFC), Color(0xFFF5F7FB)],
    [Color(0xFFFCE6DA), Color(0xFFFFF7F2)],
    [Color(0xFFDDF2E5), Color(0xFFF4FBF7)],
    [Color(0xFFEAE3FA), Color(0xFFF8F6FD)],
    [Color(0xFFF1EADD), Color(0xFFFBF8F3)],
  ];

  /// Where each kind of piece sits, as fractions of the board:
  /// left, top, width, height.
  static (double, double, double, double)? _slot(GarmentCategory c, bool extras) {
    // The top overlaps the waist of the bottoms, like a real flat-lay;
    // the rest stand in a column on the right.
    if (c.isUpper) return extras ? (0.04, 0.04, 0.6, 0.48) : (0.15, 0.03, 0.7, 0.5);
    switch (c) {
      case GarmentCategory.bottoms:
        return extras ? (0.08, 0.38, 0.54, 0.58) : (0.19, 0.4, 0.62, 0.57);
      case GarmentCategory.hats:
        return (0.63, 0.06, 0.34, 0.22);
      case GarmentCategory.bags:
        return (0.61, 0.3, 0.37, 0.28);
      case GarmentCategory.accessories:
        return (0.6, 0.5, 0.22, 0.17);
      case GarmentCategory.watches:
        return (0.79, 0.5, 0.2, 0.17);
      case GarmentCategory.shoes:
        return (0.58, 0.68, 0.4, 0.28);
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
          gradient: plain
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: tint != null
                      ? tints[tint! % tints.length]
                      : dark
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
        GarmentCategory.accessories || GarmentCategory.watches => 3,
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
    // Small, wide pieces come closer so they hold their own on the board.
    final zoom = switch (garment.category) {
      GarmentCategory.shoes || GarmentCategory.accessories || GarmentCategory.watches => 1.25,
      _ => 1.0,
    };
    final image = GarmentImage(garment: garment, iconSize: 22, backdrop: Colors.transparent, zoom: zoom);
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
