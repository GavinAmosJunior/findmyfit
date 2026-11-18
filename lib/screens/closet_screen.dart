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
import '../widgets/pressable.dart';
import 'garment_form_screen.dart';
import 'fit_shuffle_screen.dart';
import 'garment_sheet.dart';
import 'settings_screen.dart';
import '../theme/app_icons.dart';

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
              child: const Icon(AppIcons.add, size: 30),
            ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(s.closet),
            actions: [
              IconButton(
                tooltip: s.search,
                onPressed: all.isEmpty ? null : _toggleSearch,
                icon: Icon(_searching ? AppIcons.close : AppIcons.search),
              ),
              IconButton(
                tooltip: s.settings,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(AppIcons.settings),
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
                // Room for the + button and the tab bar floating over the grid.
                padding: EdgeInsets.fromLTRB(16, 4, 16, 96 + MediaQuery.paddingOf(context).bottom),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final columns = (constraints.crossAxisExtent / 190).floor().clamp(2, 5);
                    // Name + care label grow with the phone's text size setting.
                    final labelArea = 16 + MediaQuery.textScalerOf(context).scale(42);
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 18,
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
                prefixIcon: const Icon(AppIcons.search),
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
        if (AppScope.of(context).shuffleTops.isNotEmpty && AppScope.of(context).shuffleBottoms.isNotEmpty)
          const _ShuffleBanner(),
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

    // Photo first: no card around it, just the picture, the name and,
    // only when a piece isn't clean in the closet, its care label.
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
                  borderRadius: BorderRadius.circular(18),
                  child: GarmentImage(garment: garment),
                ),
              ),
              if (garment.isFavorite)
                const Positioned(
                  top: 10,
                  left: 10,
                  child: IgnorePointer(
                    child: Icon(AppIcons.favorite, color: Colors.white, size: 20,
                        shadows: [Shadow(color: Color(0x66000000), blurRadius: 6)]),
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
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(garment.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
              const SizedBox(height: 4),
              if (canWear)
                Text(s.categoryLabel(garment.category), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall)
              else
                CareLabel(status: garment.status),
            ],
          ),
        ),
      ],
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
      icon: const Icon(AppIcons.hamper, size: 22),
    );
  }
}

/// The way into Fit Shuffle: a label stitched onto the closet.
class _ShuffleBanner extends StatelessWidget {
  const _ShuffleBanner();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Pressable(
        label: '${s.fitShuffle}. ${s.shufflePrompt}',
        onTap: () => FitShuffleScreen.open(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(color: context.palette.card, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(AppIcons.shuffle, color: context.palette.thread, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WovenLabel(s.fitShuffle, fontSize: 13),
                    const SizedBox(height: 6),
                    Text(s.shufflePrompt, style: context.text.bodySmall),
                  ],
                ),
              ),
              Icon(AppIcons.chevron, size: 18, color: context.palette.tertiaryText),
            ],
          ),
        ),
      ),
    );
  }
}
