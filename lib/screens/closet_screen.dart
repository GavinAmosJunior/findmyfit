import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/closet_widgets.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/garment_image.dart';
import '../widgets/pill.dart';
import '../widgets/pressable.dart';
import '../widgets/tags.dart';
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

  // Order stays fixed (newest first) so tiles don't jump when you tap
  // "Wore it"; each tile's label shows its status.
  List<Garment> _visible(List<Garment> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((g) {
      if (_filter == 'fav' && !g.isFavorite) return false;
      if (_filter != null && _filter != 'fav' && g.category.name != _filter) return false;
      if (q.isNotEmpty) {
        final hay = '${g.name} ${g.brand ?? ''} ${g.notes ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
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
      body: CustomScrollView(
        slivers: [
          LargeTitle(
            title: s.closet,
            actions: [
              // The camera is what + opens; the library is here.
              IconButton(
                tooltip: s.addFromGallery,
                onPressed: () => GarmentFormScreen.openAdd(context, fromGallery: true),
                icon: const Icon(AppIcons.library),
              ),
              IconButton(
                tooltip: s.search,
                onPressed: all.isEmpty ? null : _toggleSearch,
                icon: Icon(_searching ? AppIcons.close : AppIcons.search),
              ),
              IconButton(
                tooltip: s.settings,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                icon: const Icon(AppIcons.settings),
              ),
            ],
          ),
          if (!state.isLoaded)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator.adaptive()))
          else if (all.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: AppIcons.addPhoto,
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
                child: EmptyState(icon: AppIcons.noResults, title: s.noMatches, body: s.noMatchesBody),
              )
            else
              SliverPadding(
                // Room for the tab bar floating over the grid.
                padding: EdgeInsets.fromLTRB(16, 6, 16, 24 + MediaQuery.paddingOf(context).bottom),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final columns = (constraints.crossAxisExtent / 190).floor().clamp(2, 5);
                    // Name and status line grow with the phone's text size.
                    final labelArea = 14 + MediaQuery.textScalerOf(context).scale(40);
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 20,
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(hintText: s.searchClothes, prefixIcon: const Icon(AppIcons.search)),
            ),
          ),
        // What's at the laundry, and an outfit for today.
        const ClosetWidgets(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              for (final (i, (key, label)) in filters.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Pill(label: label, selected: _filter == key, onTap: () => setState(() => _filter = key)),
              ],
            ],
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
    final statusColor = context.palette.statusColor(garment.status, context.palette.secondaryText);

    // The piece on its gray tile, then its name, and its category or,
    // when it isn't clean in the closet, where it is.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Pressable(
                label: garment.name,
                onTap: () => GarmentSheet.show(context, garment.id),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: GarmentImage(garment: garment),
                ),
              ),
              if (garment.isFavorite)
                Positioned(
                  top: 10,
                  left: 10,
                  child: IgnorePointer(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: context.colors.surface.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(AppIcons.favorite, color: context.ink, size: 15),
                    ),
                  ),
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
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(garment.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
              const SizedBox(height: 2),
              if (canWear)
                Text(s.categoryLabel(garment.category), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall)
              else
                Row(
                  children: [
                    Icon(statusIcon(garment.status), size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        s.statusLabel(garment.status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: statusColor),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The one-tap "I wore this" button on a closet tile: a small round
/// button with a basket, in a 44pt touch target.
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
        backgroundColor: context.colors.surface,
        foregroundColor: context.ink,
        minimumSize: const Size(40, 40),
        fixedSize: const Size(40, 40),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      icon: const Icon(AppIcons.hamper, size: 20),
    );
  }
}
