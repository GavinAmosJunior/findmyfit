import 'package:flutter/material.dart';
import '../models/laundry_batch.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../widgets/garment_image.dart';

class LaundryChecklistScreen extends StatefulWidget {
  final WardrobeState state;
  final Function(int tabIndex)? onNavigateToTab;

  const LaundryChecklistScreen({
    super.key,
    required this.state,
    this.onNavigateToTab,
  });

  @override
  State<LaundryChecklistScreen> createState() => _LaundryChecklistScreenState();
}

class _LaundryChecklistScreenState extends State<LaundryChecklistScreen> {
  String? _selectedBatchId;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final activeBatches = state.activeBatches;

    // Default to the first active batch if not selected or invalid
    if (activeBatches.isNotEmpty) {
      if (_selectedBatchId == null ||
          !activeBatches.any((b) => b.id == _selectedBatchId)) {
        _selectedBatchId = activeBatches.first.id;
      }
    } else {
      _selectedBatchId = null;
    }

    final currentBatch = activeBatches.cast<LaundryBatch?>().firstWhere(
          (b) => b?.id == _selectedBatchId,
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: activeBatches.isEmpty
            ? _buildNoBatchesView(context)
            : Stack(
                children: [
                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Laundry Return',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.6,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Batches Horizontal Scroll Switcher
                              SizedBox(
                                height: 38,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: activeBatches.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final batch = activeBatches[index];
                                    final isSelected =
                                        batch.id == _selectedBatchId;
                                    return ChoiceChip(
                                      avatar: Icon(
                                        Icons.local_laundry_service_rounded,
                                        size: 14,
                                        color: isSelected
                                          ? Colors.white
                                          : AppColors.primary,
                                      ),
                                      label: Text(
                                        '${batch.name} (${batch.totalItems})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.onSurface,
                                        ),
                                      ),
                                      selected: isSelected,
                                      selectedColor: AppColors.primary,
                                      backgroundColor:
                                          AppColors.surfaceContainerLow,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedBatchId = batch.id;
                                          });
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (currentBatch != null) ...[
                        // Verification Overview Card
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child:
                                _buildVerificationCard(context, currentBatch),
                          ),
                        ),

                        // Section title
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Items in This Batch (${currentBatch.totalItems})',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const Text(
                                  'Tap circle to check off',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Garment Cross-Check List
                        _buildGarmentChecklist(state, currentBatch),

                        // Generous bottom spacer so items scroll completely clear of the floating button
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 190),
                        ),
                      ],
                    ],
                  ),

                  // Floating "Complete Return" action card anchored above bottom navigation bar
                  if (currentBatch != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 84, // Floats cleanly above bottom nav bar
                      child: _buildFloatingActionCard(context, currentBatch),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildNoBatchesView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_laundry_service_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Batches Currently at Laundry',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When clothes accumulate in your dirty hamper, dump the bin into laundry to start tracking returned items here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => widget.onNavigateToTab?.call(1),
              icon: const Icon(Icons.shopping_basket_rounded, size: 16),
              label: const Text('Go to Dirty Hamper'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCard(BuildContext context, LaundryBatch batch) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x120F172A), width: 1),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${batch.verifiedCount}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'of ${batch.totalItems} verified',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: batch.verifiedCount == batch.totalItems
                      ? AppColors.secondaryContainer
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  batch.verifiedCount == batch.totalItems
                      ? 'All Returned!'
                      : '${batch.pendingCount} Pending · ${batch.missingCount} Missing',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: batch.verifiedCount == batch.totalItems
                        ? AppColors.onSecondaryContainer
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: batch.progress,
                backgroundColor: AppColors.surfaceContainer,
                color: batch.verifiedCount == batch.totalItems
                    ? AppColors.secondary
                    : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Verify All Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Batch: ${batch.batchCode}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.outline,
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    widget.state.verifyAllBatchItems(batch.id),
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text(
                  'Verify All Items',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGarmentChecklist(WardrobeState state, LaundryBatch batch) {
    // Find the garments belonging to this batch
    final batchGarments = state.garments
        .where((g) => batch.itemIds.contains(g.id))
        .toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final garment = batchGarments[index];
            final isVerified = batch.isItemVerified(garment.id);
            final isMissing = batch.isItemMissing(garment.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMissing
                      ? AppColors.errorContainer.withOpacity(0.4)
                      : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isMissing
                        ? AppColors.error.withOpacity(0.3)
                        : isVerified
                            ? AppColors.secondaryContainer
                            : const Color(0x120F172A),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 54,
                            height: 54,
                            color: Color(garment.fallbackColor ?? 0xFFE2E8F0),
                            child: GarmentImage(garment: garment),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title & Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                garment.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${garment.fabricNotes ?? 'Everyday'} · ${garment.washNotes ?? 'Normal Wash'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (isVerified)
                                const Row(
                                  children: [
                                    Icon(Icons.check_rounded,
                                        size: 13,
                                        color: AppColors.secondary),
                                    SizedBox(width: 4),
                                    Text(
                                      'Checked & Returned',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                )
                              else if (isMissing)
                                const Row(
                                  children: [
                                    Icon(Icons.warning_rounded,
                                        size: 13,
                                        color: AppColors.error),
                                    SizedBox(width: 4),
                                    Text(
                                      'Flagged as Missing',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                const Text(
                                  'Tap circle to check off',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.outline,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Check Circle Toggle
                        GestureDetector(
                          onTap: () => widget.state
                              .toggleBatchItemVerification(
                                  batch.id, garment.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isVerified
                                  ? AppColors.secondary
                                  : isMissing
                                      ? AppColors.surfaceContainerLow
                                      : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isVerified
                                    ? AppColors.secondary
                                    : isMissing
                                        ? AppColors.error
                                        : const Color(0x3A000000),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              isVerified
                                  ? Icons.check_rounded
                                  : isMissing
                                      ? Icons.close_rounded
                                      : Icons.radio_button_unchecked_rounded,
                              color: isVerified
                                  ? Colors.white
                                  : isMissing
                                      ? AppColors.error
                                      : const Color(0x44000000),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Quick Flag Missing Toggle row
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isMissing)
                            TextButton.icon(
                              onPressed: () => widget.state
                                  .toggleBatchItemVerification(
                                      batch.id, garment.id),
                              icon: const Icon(Icons.undo_rounded, size: 14),
                              label: const Text('Undo (Mark Received)'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                          else
                            TextButton.icon(
                              onPressed: () => widget.state
                                  .flagBatchItemMissing(batch.id, garment.id),
                              icon: const Icon(Icons.flag_outlined, size: 14),
                              label: const Text('Flag as Missing'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: batchGarments.length,
        ),
      ),
    );
  }

  Widget _buildFloatingActionCard(
      BuildContext context, LaundryBatch batch) {
    final verified = batch.verifiedCount;
    final missing = batch.totalItems - verified;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x180F172A), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _confirmCompleteReturn(context, batch),
              icon: const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
              label: const Text(
                'Complete Return',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$verified returned to Closet ${missing > 0 ? '· $missing unverified will move to Lost & Found' : '· 100% matched!'}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCompleteReturn(BuildContext context, LaundryBatch batch) {
    final verifiedCount = batch.verifiedCount;
    final missingCount = batch.totalItems - verifiedCount;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Complete Return?'),
        content: Text(
          '$verifiedCount clothes will return to your digital Closet as clean.\n\n'
          '${missingCount > 0 ? '$missingCount clothes are not verified and will move to Missing (Lost & Found).' : 'All clothes safely verified!'}',
          style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Checking'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.state.completeLaundryReturn(batch.id);
              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.secondary,
                  content: Text(
                    'Return finalized! $verifiedCount items returned to Closet.',
                  ),
                  action: missingCount > 0
                      ? SnackBarAction(
                          label: 'View Missing',
                          textColor: Colors.white,
                          onPressed: () => widget.onNavigateToTab?.call(3),
                        )
                      : null,
                ),
              );

              // If there are missing items, navigate to missing tab, else to closet
              if (missingCount > 0) {
                widget.onNavigateToTab?.call(3);
              } else {
                widget.onNavigateToTab?.call(0);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Finalize Return'),
          ),
        ],
      ),
    );
  }
}
