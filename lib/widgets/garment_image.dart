import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/garment.dart';
import '../services/image_store.dart';
import '../theme/app_theme.dart';
import '../theme/app_icons.dart';

IconData categoryIcon(GarmentCategory category) {
  switch (category) {
    case GarmentCategory.tops:
      return AppIcons.tops;
    case GarmentCategory.bottoms:
      return AppIcons.bottoms;
    case GarmentCategory.outerwear:
      return AppIcons.outerwear;
    case GarmentCategory.delicates:
      return AppIcons.delicates;
    case GarmentCategory.shoes:
      return AppIcons.shoes;
    case GarmentCategory.hats:
      return AppIcons.hats;
    case GarmentCategory.bags:
      return AppIcons.bags;
    case GarmentCategory.accessories:
      return AppIcons.accessories;
  }
}

/// Shows a garment's photo, or a colored tile with its category icon.
class GarmentImage extends StatelessWidget {
  final Garment garment;
  final double iconSize;

  /// What a cutout or a missing photo sits on. Defaults to the gray tile;
  /// rows that are already on a tile pass the page color so the piece
  /// stands out.
  final Color? backdrop;

  const GarmentImage({super.key, required this.garment, this.iconSize = 34, this.backdrop});

  // Decoding a data: URL is costly, so keep recent results.
  static final _cache = <String, Uint8List>{};

  static Uint8List? _bytes(String url) {
    final hit = _cache[url];
    if (hit != null) return hit;
    try {
      final bytes = UriData.parse(url).contentAsBytes();
      if (_cache.length > 150) _cache.remove(_cache.keys.first);
      return _cache[url] = bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = garment.imageUrl;
    final fallback = _Fallback(garment: garment, iconSize: iconSize, backdrop: backdrop);
    if (ref == null || ref.isEmpty) return fallback;

    final photo = _photo(ref, fallback);
    if (!ImageStore.isCutout(ref)) return photo;

    // A cutout floats whole on the gray tile, like a product shot,
    // instead of being cropped to fill it.
    return ColoredBox(
      color: backdrop ?? context.palette.tile,
      child: LayoutBuilder(
        builder: (context, c) => Padding(
          padding: EdgeInsets.all(c.biggest.shortestSide.isFinite ? c.biggest.shortestSide * 0.08 : 0),
          child: photo,
        ),
      ),
    );
  }

  Widget _photo(String ref, Widget fallback) {
    final fit = ImageStore.isCutout(ref) ? BoxFit.contain : BoxFit.cover;
    // Decode photos at the size they're shown, not their full resolution,
    // so a grid of thumbnails stays light on memory and scrolls smoothly.
    return LayoutBuilder(builder: (context, constraints) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final side = constraints.biggest.longestSide;
      final cache = side.isFinite ? (side * dpr).round() : null;
      Widget error(BuildContext _, Object _, StackTrace? _) => fallback;

      if (ref.startsWith('data:')) {
        final bytes = _bytes(ref);
        if (bytes == null) return fallback;
        return Image.memory(bytes, fit: fit, cacheWidth: cache, gaplessPlayback: true, errorBuilder: error);
      }
      if (ref.startsWith('http')) {
        return Image.network(ref, fit: fit, cacheWidth: cache, errorBuilder: error);
      }
      if (kIsWeb) return fallback; // Old blob: URLs don't survive a reload.
      return Image.file(File(ref), fit: fit, cacheWidth: cache, errorBuilder: error);
    });
  }
}

/// No photo: the category's outline on the gray tile.
class _Fallback extends StatelessWidget {
  final Garment garment;
  final double iconSize;
  final Color? backdrop;

  const _Fallback({required this.garment, required this.iconSize, this.backdrop});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backdrop ?? context.palette.tile,
      child: Center(
        child: Icon(categoryIcon(garment.category), size: iconSize, color: context.palette.tertiaryText),
      ),
    );
  }
}
