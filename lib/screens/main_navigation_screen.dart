import 'dart:ui';
import 'package:flutter/material.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import 'add_garment_modal.dart';
import 'closet_screen.dart';
import 'dirty_hamper_screen.dart';
import 'laundry_checklist_screen.dart';
import 'lost_found_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final WardrobeState state;

  const MainNavigationScreen({super.key, required this.state});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;

        final screens = [
          ClosetScreen(
            state: state,
            onNavigateToTab: _onTabSelected,
          ),
          DirtyHamperScreen(
            state: state,
            onNavigateToTab: _onTabSelected,
          ),
          LaundryChecklistScreen(
            state: state,
            onNavigateToTab: _onTabSelected,
          ),
          LostFoundScreen(
            state: state,
            onNavigateToTab: _onTabSelected,
          ),
        ];

        return Scaffold(
          extendBody: true,
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: _buildFrostedBottomBar(state),
        );
      },
    );
  }

  Widget _buildFrostedBottomBar(WardrobeState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0x180F172A), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.checkroom_rounded,
                  label: 'Closet',
                  badgeCount: state.closetCount,
                  badgeColor: AppColors.secondary,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.shopping_basket_rounded,
                  label: 'Hamper',
                  badgeCount: state.hamperCount,
                  badgeColor: AppColors.tertiary,
                ),
                // Center Quick Add Button
                GestureDetector(
                  onTap: () => AddGarmentModal.show(context, state),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x330058BE),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.local_laundry_service_rounded,
                  label: 'Laundry',
                  badgeCount: state.laundryCount,
                  badgeColor: AppColors.primary,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.qr_code_2_rounded,
                  label: 'Missing',
                  badgeCount: state.missingCount,
                  badgeColor: AppColors.error,
                  showBadgeOnlyIfPositive: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required int badgeCount,
    required Color badgeColor,
    bool showBadgeOnlyIfPositive = false,
  }) {
    final isSelected = _currentIndex == index;
    final showBadge = !showBadgeOnlyIfPositive || badgeCount > 0;

    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
                if (showBadge && badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      constraints: const BoxConstraints(minWidth: 14),
                      child: Text(
                        '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
