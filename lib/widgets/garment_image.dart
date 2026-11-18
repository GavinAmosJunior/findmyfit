import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/garment.dart';

class GarmentImage extends StatelessWidget {
  final Garment garment;
  final BoxFit fit;

  const GarmentImage({
    super.key,
    required this.garment,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = garment.imageUrl;

    if (imagePath == null || imagePath.isEmpty) {
      return _buildFallback();
    }

    // Check if network URL
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }

    // On Web, local filesystem File doesn't exist in dart:io the same way
    if (kIsWeb) {
      return Image.network(
        imagePath,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }

    // On Android / iOS / Desktop, load from local device file storage.
    // Do NOT use existsSync() as a gate — some Android versions return false
    // even for valid paths. Instead, always attempt Image.file() and rely
    // entirely on errorBuilder to catch genuine failures.
    return Image.file(
      File(imagePath),
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _buildFallback(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        // While loading, show a lightweight placeholder matching the card bg
        return Container(color: Colors.transparent);
      },
    );
  }

  Widget _buildFallback() {
    IconData icon;
    switch (garment.category) {
      case GarmentCategory.tops:
        icon = Icons.dry_cleaning_rounded;
        break;
      case GarmentCategory.bottoms:
        icon = Icons.view_column_rounded;
        break;
      case GarmentCategory.outerwear:
        icon = Icons.layers_rounded;
        break;
      case GarmentCategory.delicates:
        icon = Icons.spa_rounded;
        break;
    }

    return Center(
      child: Icon(
        icon,
        size: 36,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }
}
