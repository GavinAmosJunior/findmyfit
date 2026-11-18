import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import 'closet_screen.dart';
import 'hamper_screen.dart';
import 'laundry_screen.dart';
import 'missing_screen.dart';

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

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [ClosetScreen(), HamperScreen(), LaundryScreen(), MissingScreen()],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.palette.separator))),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: goTo,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.checkroom_outlined),
              selectedIcon: const Icon(Icons.checkroom_rounded),
              label: s.closet,
            ),
            NavigationDestination(
              icon: const Icon(Icons.shopping_basket_outlined),
              selectedIcon: const Icon(Icons.shopping_basket_rounded),
              label: s.hamper,
            ),
            NavigationDestination(
              icon: const Icon(Icons.local_laundry_service_outlined),
              selectedIcon: const Icon(Icons.local_laundry_service_rounded),
              label: s.laundry,
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: missing > 0,
                label: Text('$missing'),
                child: const Icon(Icons.travel_explore_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: missing > 0,
                label: Text('$missing'),
                child: const Icon(Icons.travel_explore_rounded),
              ),
              label: s.missing,
            ),
          ],
        ),
      ),
    );
  }
}
