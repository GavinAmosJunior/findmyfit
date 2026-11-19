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
  }
}

/// Shows a garment's photo, or a colored tile with its category icon.
class GarmentImage extends StatelessWidget {
  final Garment garment;
  final double iconSize;

  const GarmentImage({super.key, required this.garment, this.iconSize = 34});

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
    final fallback = _Fallback(garment: garment, iconSize: iconSize);
    if (ref == null || ref.isEmpty) return fallback;

    final photo = _photo(ref, fallback);
    if (!ImageStore.isCutout(ref)) return photo;

    // A cutout floats whole on a quiet backdrop instead of being cropped
    // to fill the tile.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? const Color(0xFF26282C) : const Color(0xFFF1F0EC),
      child: LayoutBuilder(
        builder: (context, c) => Padding(
          padding: EdgeInsets.all(c.biggest.shortestSide.isFinite ? c.biggest.shortestSide * 0.04 : 0),
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

class _Fallback extends StatelessWidget {
  final Garment garment;
  final double iconSize;

  const _Fallback({required this.garment, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    final seed = garment.fallbackColor ?? garmentSwatches[garment.name.hashCode.abs() % garmentSwatches.length];
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = Color(seed);
    return ColoredBox(
      color: dark ? Color.lerp(base, Colors.black, 0.35)! : base,
      child: Center(
        child: Icon(categoryIcon(garment.category), size: iconSize, color: Colors.white.withValues(alpha: 0.9)),
      ),
    );
  }
}
