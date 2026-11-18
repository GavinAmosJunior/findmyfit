import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/garment.dart';
import '../theme/app_theme.dart';

IconData categoryIcon(GarmentCategory category) {
  switch (category) {
    case GarmentCategory.tops:
      return Icons.dry_cleaning_rounded;
    case GarmentCategory.bottoms:
      return Icons.view_column_rounded;
    case GarmentCategory.outerwear:
      return Icons.layers_rounded;
    case GarmentCategory.delicates:
      return Icons.spa_rounded;
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
    Widget error(BuildContext _, Object _, StackTrace? _) => fallback;

    if (ref == null || ref.isEmpty) return fallback;
    if (ref.startsWith('data:')) {
      final bytes = _bytes(ref);
      if (bytes == null) return fallback;
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: error);
    }
    if (ref.startsWith('http')) {
      return Image.network(ref, fit: BoxFit.cover, errorBuilder: error);
    }
    if (kIsWeb) return fallback; // Old blob: URLs don't survive a reload.
    return Image.file(File(ref), fit: BoxFit.cover, errorBuilder: error);
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
