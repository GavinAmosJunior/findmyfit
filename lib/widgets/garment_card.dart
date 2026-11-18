import 'package:flutter/material.dart';
import '../models/garment.dart';
import '../theme/app_theme.dart';
import 'garment_image.dart';
import 'status_pill.dart';

class GarmentCard extends StatelessWidget {
  final Garment garment;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onQuickStatusAction;
  final VoidCallback? onTap;

  const GarmentCard({
    super.key,
    required this.garment,
    this.onFavoriteToggle,
    this.onQuickStatusAction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x120F172A), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / Graphic Area with category and favorite overlay
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.15,
                  child: Container(
                    color: Color(garment.fallbackColor ?? 0xFFE2E8F0),
                    child: GarmentImage(garment: garment),
                  ),
                ),
                // Category Chip Overlay
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      garment.category.displayName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ),
                // Favorite Heart Overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onFavoriteToggle,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        garment.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: garment.isFavorite
                            ? const Color(0xFFE11D48)
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    garment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    garment.fabricNotes ?? 'Everyday wear',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Status Pill
                  StatusPill(status: garment.status, isCompact: true),
                  const SizedBox(height: 8),
                  // Quick Action button depending on status
                  _buildQuickActionButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildQuickActionButton(BuildContext context) {
    if (garment.status == GarmentStatus.closet) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onQuickStatusAction,
          icon: const Icon(Icons.shopping_basket_outlined, size: 13),
          label: const Text(
            'Mark Dirty',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.tertiary,
            side: BorderSide(color: AppColors.tertiary.withOpacity(0.3)),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    } else if (garment.status == GarmentStatus.dirtyHamper) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          onPressed: onQuickStatusAction,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.secondaryContainer.withOpacity(0.7),
            foregroundColor: AppColors.onSecondaryContainer,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            visualDensity: VisualDensity.compact,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.checkroom_rounded, size: 13),
              SizedBox(width: 4),
              Text(
                'Move to Closet',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    } else if (garment.status == GarmentStatus.missing) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onQuickStatusAction,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            visualDensity: VisualDensity.compact,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_rounded, size: 13),
              SizedBox(width: 4),
              Text(
                'Found at Home',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        child: const Text(
          'In Active Wash Batch',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF2563EB),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
  }
}
