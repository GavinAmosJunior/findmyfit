import 'package:flutter/material.dart';
import '../models/garment.dart';
import '../theme/app_theme.dart';

class StatusPill extends StatelessWidget {
  final GarmentStatus status;
  final bool isCompact;

  const StatusPill({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textColor;
    IconData icon;
    String label;

    switch (status) {
      case GarmentStatus.closet:
        bg = AppColors.secondaryContainer;
        textColor = AppColors.onSecondaryContainer;
        icon = Icons.checkroom_rounded;
        label = isCompact ? 'Closet' : 'In Closet (Clean)';
        break;
      case GarmentStatus.dirtyHamper:
        bg = AppColors.tertiaryContainer;
        textColor = AppColors.onTertiaryContainer;
        icon = Icons.shopping_basket_rounded;
        label = isCompact ? 'Hamper' : 'In Hamper (Dirty)';
        break;
      case GarmentStatus.inLaundry:
        bg = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1E40AF);
        icon = Icons.local_laundry_service_rounded;
        label = isCompact ? 'Laundry' : 'At Laundry';
        break;
      case GarmentStatus.missing:
        bg = AppColors.errorContainer;
        textColor = AppColors.onErrorContainer;
        icon = Icons.warning_amber_rounded;
        label = 'Missing';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: textColor.withOpacity(0.2), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 12 : 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
