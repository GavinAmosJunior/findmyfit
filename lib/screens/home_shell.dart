import 'package:flutter/services.dart';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import 'closet_screen.dart';
import 'hamper_screen.dart';
import 'laundry_screen.dart';
import 'missing_screen.dart';
import '../theme/app_icons.dart';

/// Lets screens outside the shell (pushed routes) switch tabs.
final homeShellKey = GlobalKey<HomeShellState>();

/// The four top-level sections. Tabs only navigate; actions live inside
/// each screen. Only Missing gets a badge, because it's the one section
/// that needs your attention.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;

  void goTo(int index) => setState(() => _index = index);

  static HomeShellState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>() ?? homeShellKey.currentState;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final missing = state.countOf(GarmentStatus.missing);

    // Each tab has its own messenger, so a snackbar appears inside that
    // tab's scaffold and pushes its buttons (+, Send to laundry) up
    // instead of covering them.
    final body = IndexedStack(
      index: _index,
      children: const [
        ScaffoldMessenger(child: ClosetScreen()),
        ScaffoldMessenger(child: HamperScreen()),
        ScaffoldMessenger(child: LaundryScreen()),
        ScaffoldMessenger(child: MissingScreen()),
      ],
    );

    final tabs = [
      (s.closet, AppIcons.closet, AppIcons.closetFill),
      (s.hamper, AppIcons.hamper, AppIcons.hamperFill),
      (s.laundry, AppIcons.laundry, AppIcons.laundryFill),
      (s.missing, AppIcons.missing, AppIcons.missingFill),
    ];

    // Content scrolls under the frosted tab bar, as on iPhone.
    return Scaffold(
      extendBody: true,
      // extendBody only grows `padding`; the + button, snackbars and
      // SafeArea inside each tab look at `viewPadding`, so count the bar
      // there too or they'd sit underneath it.
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
        items: [
          for (final (i, (label, icon, selectedIcon)) in tabs.indexed)
            AppTabItem(
              label: label,
              icon: icon,
              selectedIcon: selectedIcon,
              badge: i == 3 && missing > 0 ? '$missing' : null,
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

/// One tab bar for iPhone and Android, drawn the iOS way: a frosted bar
/// floating over content, a hairline on top, and the selected tab shown by
/// a filled, tinted symbol instead of a pill (tab-bars.md, sf-symbols.md ›
/// Design variants: "an iOS tab bar prefers the fill variant").
class AppTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppTabItem> items;

  const AppTabBar({super.key, required this.currentIndex, required this.onTap, required this.items});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.card.withValues(alpha: 0.82),
            border: Border(top: BorderSide(color: palette.separator, width: 0.5)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            // Labels may grow a little with the text size, not without limit:
            // the bar has to keep its height.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: SizedBox(
                height: 58,
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
    final color = selected ? context.colors.primary : context.palette.secondaryText;
    final still = MediaQuery.disableAnimationsOf(context);
    Widget icon = Icon(selected ? item.selectedIcon : item.icon, size: 26, color: color);
    if (item.badge != null) {
      icon = Badge(label: Text(item.badge!), child: icon);
    }

    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // A small pop when a tab becomes selected; none with Reduce Motion.
            TweenAnimationBuilder<double>(
              key: ValueKey(selected),
              tween: Tween(begin: selected && !still ? 0.82 : 1, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.elasticOut,
              builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
              child: icon,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
