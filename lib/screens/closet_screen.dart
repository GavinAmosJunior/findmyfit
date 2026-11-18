import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/care_label.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/garment_image.dart';
import 'garment_form_screen.dart';
import 'garment_sheet.dart';
import 'settings_screen.dart';

/// Marks a clean garment as worn, with haptic feedback and an Undo.
void wearGarment(BuildContext context, Garment garment) {
  final state = AppScope.read(context);
  final s = S.of(context);
  final before = state.markWorn(garment.id);
  if (before == null) return;
  HapticFeedback.lightImpact();
  showMessage(
    context,
    s.movedToHamper(garment.name),
    actionLabel: s.undo,
    onAction: () => state.undoMarkWorn(garment.id, before),
  );
}

class ClosetScreen extends StatefulWidget {
  const ClosetScreen({super.key});

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

/// Filter chips: null = all, 'fav' = favorites, otherwise a category name.
class _ClosetScreenState extends State<ClosetScreen> {
  String? _filter;
  bool _searching = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Garment> _visible(List<Garment> all) {
    final q = _search.text.trim().toLowerCase();
    final list = all.where((g) {
      if (_filter == 'fav' && !g.isFavorite) return false;
      if (_filter != null && _filter != 'fav' && g.category.name != _filter) return false;
      if (q.isNotEmpty) {
        final hay = '${g.name} ${g.brand ?? ''} ${g.notes ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    // Order stays fixed (newest first) so tiles don't jump when you tap
    // "Wore it"; the care label shows each status.
    return list;
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final all = state.garments;
    final visible = _visible(all);

    return Scaffold(
      floatingActionButton: all.isEmpty
          ? null
          : FloatingActionButton(
              tooltip: s.addClothes,
              onPressed: () => GarmentFormScreen.openAdd(context),
              child: const Icon(Icons.add_rounded, size: 30),
            ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(s.closet),
            actions: [
              IconButton(
                tooltip: s.search,
                onPressed: all.isEmpty ? null : _toggleSearch,
                icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
              ),
              IconButton(
                tooltip: s.settings,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: 4),
            ],
          ),
          if (!state.isLoaded)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator.adaptive()))
          else if (all.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.add_a_photo_outlined,
                title: s.emptyClosetTitle,
                body: s.emptyClosetBody,
                actionLabel: s.addClothes,
                onAction: () => GarmentFormScreen.openAdd(context),
              ),
            )
          else ...[
            SliverToBoxAdapter(child: _header(context, s, state.countOf)),
            if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(icon: Icons.search_off_rounded, title: s.noMatches, body: s.noMatchesBody),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final columns = (constraints.crossAxisExtent / 190).floor().clamp(2, 5);
                    // Name + care label grow with the phone's text size setting.
                    final labelArea = 30 + MediaQuery.textScalerOf(context).scale(42);
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 12,
                        mainAxisExtent: (constraints.crossAxisExtent - 12 * (columns - 1)) / columns + labelArea,
                      ),
                      itemCount: visible.length,
                      itemBuilder: (context, i) => _GarmentTile(garment: visible[i]),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context, S s, int Function(GarmentStatus) count) {
    final filters = <(String?, String)>[
      (null, s.all),
      ('fav', s.favorites),
      for (final c in GarmentCategory.values) (c.name, s.categoryLabel(c)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: s.searchClothes,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            s.closetSummary(
              count(GarmentStatus.closet),
              count(GarmentStatus.dirtyHamper),
              count(GarmentStatus.inLaundry),
            ),
            style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText),
          ),
        ),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            itemCount: filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final (key, label) = filters[i];
              return ChoiceChip(
                label: Text(label),
                selected: _filter == key,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _filter = key);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GarmentTile extends StatelessWidget {
  final Garment garment;

  const _GarmentTile({required this.garment});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final canWear = garment.status == GarmentStatus.closet;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => GarmentSheet.show(context, garment.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GarmentImage(garment: garment),
                  if (garment.isFavorite)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: Icon(Icons.favorite_rounded, color: Colors.white, size: 20,
                          shadows: [Shadow(color: Color(0x66000000), blurRadius: 6)]),
                    ),
                  if (canWear)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: _WoreItButton(
                        tooltip: s.woreItHint(garment.name),
                        onPressed: () => wearGarment(context, garment),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(garment.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                  const SizedBox(height: 6),
                  CareLabel(status: garment.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one-tap "I wore this" button on a closet photo: a white disc with a
/// basket icon, 44pt touch target.
class _WoreItButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;

  const _WoreItButton({required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        foregroundColor: const Color(0xFF92400E),
        minimumSize: const Size(44, 44),
        elevation: 2,
        shadowColor: const Color(0x55000000),
      ),
      icon: const Icon(Icons.shopping_basket_outlined, size: 22),
    );
  }
}
