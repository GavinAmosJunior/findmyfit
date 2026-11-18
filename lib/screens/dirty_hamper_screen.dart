import 'package:flutter/material.dart';
import '../models/garment.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../widgets/garment_image.dart';

class DirtyHamperScreen extends StatefulWidget {
  final WardrobeState state;
  final Function(int tabIndex)? onNavigateToTab;

  const DirtyHamperScreen({
    super.key,
    required this.state,
    this.onNavigateToTab,
  });

  @override
  State<DirtyHamperScreen> createState() => _DirtyHamperScreenState();
}

class _DirtyHamperScreenState extends State<DirtyHamperScreen> {
  final Set<String> _selectedItemIds = {};
  final String _batchName = 'Weekly Wash';

  @override
  void initState() {
    super.initState();
    _selectAllHamperItems();
  }

  void _selectAllHamperItems() {
    final hamperItems = widget.state.garments
        .where((g) => g.status == GarmentStatus.dirtyHamper)
        .map((g) => g.id);
    _selectedItemIds.clear();
    _selectedItemIds.addAll(hamperItems);
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedItemIds.contains(id)) {
        _selectedItemIds.remove(id);
      } else {
        _selectedItemIds.add(id);
      }
    });
  }

  void _dumpHamperToLaundry() {
    if (_selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one garment to send to laundry.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final nameController = TextEditingController(text: _batchName);
        final laundromatController =
            TextEditingController(text: 'Sparkle Clean Laundromat');

        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_laundry_service_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Send to Laundry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dumping ${_selectedItemIds.length} dirty garments into a new laundry batch.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Batch Name',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'e.g. Weekly Wash #2',
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Laundromat / Service',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: laundromatController,
                decoration: InputDecoration(
                  hintText: 'e.g. Local Laundromat',
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: () {
                final batch = widget.state.dumpHamperToLaundry(
                  batchName: nameController.text,
                  laundromatName: laundromatController.text,
                  selectedItemIds: _selectedItemIds.toList(),
                );
                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.primary,
                    content: Text(
                        'Batch "${batch.name}" created! Items are now At Laundry.'),
                    action: SnackBarAction(
                      label: 'View Batches',
                      textColor: Colors.white,
                      onPressed: () => widget.onNavigateToTab?.call(2),
                    ),
                  ),
                );

                // Auto navigate to Laundry return tab
                widget.onNavigateToTab?.call(2);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Confirm & Send'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final hamperItems = state.garments
        .where((g) => g.status == GarmentStatus.dirtyHamper)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          'Dirty Hamper',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${hamperItems.length} items',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (hamperItems.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_selectedItemIds.length == hamperItems.length) {
                              _selectedItemIds.clear();
                            } else {
                              _selectedItemIds.clear();
                              _selectedItemIds
                                  .addAll(hamperItems.map((g) => g.id));
                            }
                          });
                        },
                        icon: Icon(
                          _selectedItemIds.length == hamperItems.length
                              ? Icons.deselect_rounded
                              : Icons.select_all_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          _selectedItemIds.length == hamperItems.length
                              ? 'Deselect'
                              : 'Select All',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Summary Action Card: "Dump into Laundry"
            if (hamperItems.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: const Color(0x120F172A), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_laundry_service_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Accumulated Bin',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              Text(
                                '${_selectedItemIds.length} of ${hamperItems.length} selected for wash',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _selectedItemIds.isEmpty
                              ? null
                              : _dumpHamperToLaundry,
                          icon: const Icon(Icons.arrow_forward_rounded,
                              size: 16, color: Colors.white),
                          label: const Text(
                            'Dump to Laundry',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Empty Hamper State
            if (hamperItems.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.checkroom_rounded,
                            size: 40,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your Dirty Hamper is Empty!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'When your clothes get dirty, tap "Mark Dirty" on any closet garment to drop it into this bin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => widget.onNavigateToTab?.call(0),
                          icon: const Icon(Icons.checkroom_rounded, size: 16),
                          label: const Text('Browse Digital Closet'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              // Hamper Garment List
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = hamperItems[index];
                      final isSelected = _selectedItemIds.contains(item.id);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => _toggleSelect(item.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : const Color(0x120F172A),
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x06000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: 58,
                                    height: 58,
                                    color: Color(
                                        item.fallbackColor ?? 0xFFE2E8F0),
                                    child: GarmentImage(garment: item),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Garment Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.brand ?? 'Everyday'} · ${item.category.displayName}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.washNotes ?? 'Normal Wash',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.tertiary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Checkbox toggle
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.surfaceContainerLow,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : const Color(0x33000000),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: hamperItems.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
