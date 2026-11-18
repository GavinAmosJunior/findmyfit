import 'package:flutter/material.dart';
import '../models/garment.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../widgets/garment_card.dart';
import 'add_garment_modal.dart';

class ClosetScreen extends StatefulWidget {
  final WardrobeState state;
  final Function(int tabIndex)? onNavigateToTab;

  const ClosetScreen({
    super.key,
    required this.state,
    this.onNavigateToTab,
  });

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  // Filter status: null = All, or specific GarmentStatus
  GarmentStatus? _statusFilter;
  // Category filter: null = All, or specific GarmentCategory
  GarmentCategory? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    // Filter garments
    final filteredGarments = state.garments.where((g) {
      if (_statusFilter != null && g.status != _statusFilter) {
        return false;
      }
      if (_categoryFilter != null && g.category != _categoryFilter) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.checkroom_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'FindMyFit',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              AddGarmentModal.show(context, widget.state),
                          icon: const Icon(Icons.add_circle_rounded,
                              color: AppColors.primary, size: 28),
                          tooltip: 'Add Garment',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Top Status Filter Horizontal Scroll Bar
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildStatusTab(
                      label: 'All Clothes',
                      count: state.totalGarments,
                      isSelected: _statusFilter == null,
                      onTap: () => setState(() => _statusFilter = null),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusTab(
                      label: 'In Closet',
                      count: state.closetCount,
                      dotColor: AppColors.secondary,
                      isSelected: _statusFilter == GarmentStatus.closet,
                      onTap: () => setState(
                          () => _statusFilter = GarmentStatus.closet),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusTab(
                      label: 'In Hampers',
                      count: state.hamperCount,
                      dotColor: AppColors.tertiary,
                      isSelected: _statusFilter == GarmentStatus.dirtyHamper,
                      onTap: () => setState(
                          () => _statusFilter = GarmentStatus.dirtyHamper),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusTab(
                      label: 'At Laundry',
                      count: state.laundryCount,
                      dotColor: AppColors.primary,
                      isSelected: _statusFilter == GarmentStatus.inLaundry,
                      onTap: () => setState(
                          () => _statusFilter = GarmentStatus.inLaundry),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusTab(
                      label: 'Missing',
                      count: state.missingCount,
                      dotColor: AppColors.error,
                      isSelected: _statusFilter == GarmentStatus.missing,
                      onTap: () => setState(
                          () => _statusFilter = GarmentStatus.missing),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Wardrobe Balance / Concentric Progress Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildWardrobeBalanceCard(state),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // Snap Garment Hero Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildHeroBanner(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Category Filter Pills
            SliverToBoxAdapter(
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildCategoryPill(
                      label: 'All',
                      isSelected: _categoryFilter == null,
                      onTap: () => setState(() => _categoryFilter = null),
                    ),
                    ...GarmentCategory.values.map(
                      (cat) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _buildCategoryPill(
                          label: cat.displayName,
                          isSelected: _categoryFilter == cat,
                          onTap: () => setState(() => _categoryFilter = cat),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // Garments 2-column Grid or Empty State
            if (filteredGarments.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.checkroom_rounded,
                            size: 36,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.garments.isEmpty
                              ? 'Your Digital Closet is Ready!'
                              : 'No garments found in this view',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          state.garments.isEmpty
                              ? 'Upload photos of your clothes to track where they are in your wardrobe cycle (Closet, Dirty Hamper, Laundry).'
                              : 'Try selecting a different status or category filter.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (state.garments.isEmpty)
                          ElevatedButton.icon(
                            onPressed: () =>
                                AddGarmentModal.show(context, state),
                            icon: const Icon(Icons.add_a_photo_rounded,
                                size: 16, color: Colors.white),
                            label: const Text(
                              'Take Photo & Add Garment',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              elevation: 0,
                            ),
                          )
                        else
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _statusFilter = null;
                                _categoryFilter = null;
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reset Filters'),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    // Compute a dynamic aspect ratio based on available width.
                    // Each card is (availableWidth / 2 - crossAxisSpacing/2) wide.
                    // The card has: AspectRatio(1.15) image + ~110px of body content.
                    final cardWidth =
                        (constraints.crossAxisExtent - 12) / 2; // 12 = spacing
                    final imageHeight = cardWidth / 1.15;
                    // Body: name(~20) + subtitle(~18) + spacers(~18) + pill(~22) + button(~34) + padding(~18) = ~130
                    const bodyHeight = 132.0;
                    final totalHeight = imageHeight + bodyHeight;
                    final aspectRatio = cardWidth / totalHeight;

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: aspectRatio.clamp(0.45, 0.75),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final garment = filteredGarments[index];
                          return GarmentCard(
                            garment: garment,
                            onFavoriteToggle: () =>
                                state.toggleFavorite(garment.id),
                            onQuickStatusAction: () {
                              if (garment.status == GarmentStatus.closet) {
                                state.moveToHamper(garment.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${garment.name} moved to Hamper!'),
                                    duration: const Duration(seconds: 2),
                                    action: SnackBarAction(
                                      label: 'View Hamper',
                                      onPressed: () =>
                                          widget.onNavigateToTab?.call(1),
                                    ),
                                  ),
                                );
                              } else if (garment.status ==
                                  GarmentStatus.dirtyHamper) {
                                state.moveToCloset(garment.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${garment.name} put away clean in Closet!'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } else if (garment.status ==
                                  GarmentStatus.missing) {
                                state.resolveMissingItem(garment.id,
                                    foundInCloset: true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${garment.name} restored to Closet!'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            onTap: () =>
                                _showGarmentDetailSheet(context, garment),
                          );
                        },
                        childCount: filteredGarments.length,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTab({
    required String label,
    required int count,
    Color? dotColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x330058BE),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.25)
                    : Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWardrobeBalanceCard(WardrobeState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x120F172A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WARDROBE BALANCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.outline,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Active Wardrobe Cycle',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.eco_rounded, size: 14, color: AppColors.onSecondaryContainer),
                    SizedBox(width: 4),
                    Text(
                      'Optimal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Segmented Progress Bar
          Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                if (state.closetPercent > 0)
                  Flexible(
                    flex: state.closetCount,
                    child: Container(color: AppColors.secondary),
                  ),
                if (state.hamperPercent > 0)
                  Flexible(
                    flex: state.hamperCount,
                    child: Container(color: AppColors.tertiary),
                  ),
                if (state.laundryPercent > 0)
                  Flexible(
                    flex: state.laundryCount,
                    child: Container(color: AppColors.primary),
                  ),
                if (state.missingPercent > 0)
                  Flexible(
                    flex: state.missingCount,
                    child: Container(color: AppColors.error),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3 Metric Boxes
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  icon: Icons.checkroom_rounded,
                  color: AppColors.secondary,
                  title: 'Fresh',
                  percent: '${state.closetPercent.toStringAsFixed(0)}%',
                  subtitle: '${state.closetCount} items',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricBox(
                  icon: Icons.shopping_basket_rounded,
                  color: AppColors.tertiary,
                  title: 'Hamper',
                  percent: '${state.hamperPercent.toStringAsFixed(0)}%',
                  subtitle: '${state.hamperCount} items',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricBox(
                  icon: Icons.local_laundry_service_rounded,
                  color: AppColors.primary,
                  title: 'Laundry',
                  percent: '${state.laundryPercent.toStringAsFixed(0)}%',
                  subtitle: '${state.laundryCount} items',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox({
    required IconData icon,
    required Color color,
    required String title,
    required String percent,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            percent,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return GestureDetector(
      onTap: () => AddGarmentModal.show(context, widget.state),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x330058BE),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 13, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'AI Care Scanner',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add New Garment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Upload clothes to track closet, dirty hamper, and laundry cycles.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_a_photo_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.onSurface : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _showGarmentDetailSheet(BuildContext context, Garment garment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          garment.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${garment.brand ?? 'Everyday'} · ${garment.category.displayName}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      garment.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: garment.isFavorite
                          ? const Color(0xFFE11D48)
                          : AppColors.onSurfaceVariant,
                    ),
                    onPressed: () {
                      widget.state.toggleFavorite(garment.id);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Change Cycle Status:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.checkroom_rounded,
                        size: 16, color: AppColors.secondary),
                    label: const Text('In Closet (Clean)'),
                    onPressed: () {
                      widget.state.moveToCloset(garment.id);
                      Navigator.pop(ctx);
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.shopping_basket_rounded,
                        size: 16, color: AppColors.tertiary),
                    label: const Text('In Hamper (Dirty)'),
                    onPressed: () {
                      widget.state.moveToHamper(garment.id);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error),
                title: const Text('Remove Garment from Wardrobe',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  widget.state.removeGarment(garment.id);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${garment.name} removed.')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
