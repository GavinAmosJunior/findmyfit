import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'closet_screen.dart';
import 'fit_shuffle_screen.dart';
import 'garment_form_screen.dart';
import 'hamper_screen.dart';
import 'laundry_screen.dart';

/// Lets screens outside the shell (pushed routes) switch tabs.
final homeShellKey = GlobalKey<HomeShellState>();

/// The four top-level sections. Tabs only navigate; the one action that
/// belongs everywhere, adding clothes, is a separate round button beside
/// the tab bar rather than a tab. Missing lives inside Laundry, and its
/// count is the Laundry tab's badge.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  static const closetTab = 0;
  static const fitsTab = 1;
  static const hamperTab = 2;
  static const laundryTab = 3;

  int _index = 0;

  // Each tab has its own messenger, so a message appears inside that tab
  // and pushes its buttons up instead of covering them.
  final _messengers = List.generate(4, (_) => GlobalKey<ScaffoldMessengerState>());

  void goTo(int index) => setState(() => _index = index);

  static HomeShellState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>() ?? homeShellKey.currentState;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final missing = state.countOf(GarmentStatus.missing);

    final body = IndexedStack(
      index: _index,
      children: [
        for (final (i, screen) in const [ClosetScreen(), FitShuffleScreen(), HamperScreen(), LaundryScreen()].indexed)
          ScaffoldMessenger(key: _messengers[i], child: screen),
      ],
    );

    final tabs = [
      (s.closet, AppIcons.closet, AppIcons.closetFill),
      (s.fits, AppIcons.fits, AppIcons.fitsFill),
      (s.hamper, AppIcons.hamper, AppIcons.hamperFill),
      (s.laundry, AppIcons.laundry, AppIcons.laundryFill),
    ];

    // Content scrolls under the floating tab bar.
    return Scaffold(
      extendBody: true,
      // extendBody only grows `padding`; buttons, messages and SafeArea
      // inside each tab look at `viewPadding`, so count the bar there too
      // or they would sit underneath it.
      body: Builder(
        builder: (context) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(viewPadding: mq.viewPadding.copyWith(bottom: mq.padding.bottom)),
            child: body,
          );
        },
      ),
      bottomNavigationBar: AppTabBar(
        currentIndex: _index,
        onTap: goTo,
        addLabel: s.addClothes,
        onAdd: () => GarmentFormScreen.openAdd(context, messenger: _messengers[_index].currentState),
        items: [
          for (final (i, (label, icon, selectedIcon)) in tabs.indexed)
            AppTabItem(
              label: label,
              icon: icon,
              selectedIcon: selectedIcon,
              badge: i == laundryTab && missing > 0 ? '$missing' : null,
            ),
        ],
      ),
    );
  }
}

class AppTabItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? badge;

  const AppTabItem({required this.label, required this.icon, required this.selectedIcon, this.badge});
}

/// A frosted capsule floating over the content, with the tabs inside and
/// the round add button beside it. The selected tab gets a filled symbol
/// on a soft gray lozenge.
class AppTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppTabItem> items;
  final String addLabel;
  final VoidCallback onAdd;

  const AppTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.addLabel,
    required this.onAdd,
  });

  static const _height = 64.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final shadow = [
      BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.5 : 0.10), blurRadius: 28, offset: const Offset(0, 10)),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 0 ? bottom : 14),
      // Labels may grow a little with the text size, not without limit:
      // the bar has to keep its height.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: Row(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), boxShadow: shadow),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      height: _height,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: context.colors.surface.withValues(alpha: dark ? 0.72 : 0.82),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: palette.separator, width: 0.6),
                      ),
                      child: Row(
                        children: [
                          for (final (i, item) in items.indexed)
                            Expanded(
                              child: _Tab(
                                item: item,
                                selected: i == currentIndex,
                                onTap: () {
                                  if (i != currentIndex) HapticFeedback.selectionClick();
                                  onTap(i);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: addLabel,
              excludeSemantics: true,
              child: Tooltip(
                message: addLabel,
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: shadow),
                  child: Material(
                    color: context.ink,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onAdd();
                      },
                      child: SizedBox.square(
                        dimension: _height,
                        child: Icon(AppIcons.add, size: 26, color: context.colors.surface),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final AppTabItem item;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.ink : context.palette.secondaryText;
    final still = MediaQuery.disableAnimationsOf(context);
    Widget icon = Icon(selected ? item.selectedIcon : item.icon, size: 23, color: color);
    if (item.badge != null) {
      icon = Badge(label: Text(item.badge!), child: icon);
    }

    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: still ? Duration.zero : const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? context.ink.withValues(alpha: 0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
