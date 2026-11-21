import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/app_header.dart';
import '../widgets/garment_image.dart';
import '../widgets/pill.dart';
import 'garment_sheet.dart';
import 'home_shell.dart';
import '../theme/app_icons.dart';

/// Dirty clothes waiting to go out. Everything starts selected (you usually
/// send the whole hamper); untick what stays home, then send.
class HamperScreen extends StatefulWidget {
  const HamperScreen({super.key});

  @override
  State<HamperScreen> createState() => _HamperScreenState();
}

class _HamperScreenState extends State<HamperScreen> {
  // Tracking what's *unselected* means new hamper items start selected.
  final Set<String> _unselected = {};

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final items = state.withStatus(GarmentStatus.dirtyHamper);
    _unselected.removeWhere((id) => !items.any((g) => g.id == id));
    final selected = items.where((g) => !_unselected.contains(g.id)).toList();
    final allSelected = selected.length == items.length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          LargeTitle(
            title: s.hamper,
            actions: [
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    if (allSelected) {
                      _unselected.addAll(items.map((g) => g.id));
                    } else {
                      _unselected.clear();
                    }
                  }),
                  child: Text(allSelected ? s.selectNone : s.selectAll),
                ),
            ],
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: AppIcons.hamper, title: s.emptyHamperTitle, body: s.emptyHamperBody),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Text(
                  s.hamperSubtitle(items.length, selected.length),
                  style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              // One grouped list on a gray tile, rather than a stack of cards.
              sliver: DecoratedSliver(
                decoration: BoxDecoration(color: context.palette.tile, borderRadius: BorderRadius.circular(22)),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(indent: 128),
                  itemBuilder: (context, i) => _HamperRow(
                    garment: items[i],
                    selected: !_unselected.contains(items[i].id),
                    onToggle: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        final id = items[i].id;
                        if (!_unselected.remove(id)) _unselected.add(id);
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: selected.isEmpty
                      ? () => showMessage(context, s.selectToSend)
                      : () => _send(context, selected),
                  icon: const Icon(AppIcons.laundryFill, size: 20),
                  label: Text(s.dropOff(selected.length)),
                ),
              ),
            ),
    );
  }

  Future<void> _send(BuildContext context, List<Garment> selected) async {
    final s = S.of(context);
    final result = await showModalBottomSheet<({String nickname, String place})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DropOffSheet(count: selected.length),
    );
    if (result == null || !context.mounted) return;
    final state = AppScope.read(context);
    final load = state.sendToLaundry(
      garmentIds: selected.map((g) => g.id).toList(),
      laundromatName: result.place,
      nickname: result.nickname,
    );
    HapticFeedback.mediumImpact();
    // We switch to Laundry, so show the message above the whole app.
    final shell = HomeShellState.maybeOf(context);
    shell?.goTo(HomeShellState.laundryTab);
    if (shell != null && shell.mounted) {
      showMessage(shell.context, s.droppedOff(s.loadName(load), load.totalItems));
    }
  }
}

class _HamperRow extends StatelessWidget {
  final Garment garment;
  final bool selected;
  final VoidCallback onToggle;

  const _HamperRow({required this.garment, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.read(context);

    void putBack() {
      HapticFeedback.lightImpact();
      state.moveToCloset(garment.id);
      showMessage(
        context,
        s.foundMessage(garment.name),
        actionLabel: s.undo,
        onAction: () => state.moveToHamper(garment.id),
      );
    }

    return Dismissible(
      key: ValueKey(garment.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: context.ink,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.swipePutBack, style: context.text.titleSmall?.copyWith(color: context.colors.surface)),
            const SizedBox(width: 8),
            Icon(AppIcons.closetFill, color: context.colors.surface),
          ],
        ),
      ),
      onDismissed: (_) => putBack(),
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          checked: selected,
          child: InkWell(
            onTap: onToggle,
            onLongPress: () => GarmentSheet.show(context, garment.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  Checkbox.adaptive(value: selected, onChanged: (_) => onToggle()),
                  const SizedBox(width: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox.square(dimension: 56, child: GarmentImage(garment: garment, iconSize: 24, backdrop: context.colors.surface)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          garment.name,
                          style: context.text.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(s.categoryLabel(garment.category), style: context.text.bodySmall),
                      ],
                    ),
                  ),
                  // Swiping works too, but a visible button is what people
                  // find when something landed here by mistake.
                  IconButton(
                    tooltip: s.putBackHint(garment.name),
                    onPressed: putBack,
                    icon: Icon(AppIcons.putBack, color: context.palette.secondaryText),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dropping off a load: it gets the next number on its own. A nickname is
/// optional, and the laundromat is remembered from last time.
class _DropOffSheet extends StatefulWidget {
  final int count;

  const _DropOffSheet({required this.count});

  @override
  State<_DropOffSheet> createState() => _DropOffSheetState();
}

class _DropOffSheetState extends State<_DropOffSheet> {
  final _nickname = TextEditingController();
  final _place = TextEditingController();

  /// Showing the laundromat field rather than the remembered name.
  bool _editingPlace = false;

  @override
  void initState() {
    super.initState();
    final recent = AppScope.read(context).recentLaundromats;
    if (recent.isNotEmpty) {
      _place.text = recent.first;
    } else {
      _editingPlace = true;
    }
  }

  @override
  void dispose() {
    _nickname.dispose();
    _place.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop((nickname: _nickname.text, place: _place.text));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.read(context);
    final recent = state.recentLaundromats.take(4).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.dropOffTitle(state.nextLoadNumber), style: context.text.headlineSmall),
              const SizedBox(height: 2),
              Text(s.items(widget.count), style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText)),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            // Clear the keyboard, or the gesture bar when there's no keyboard.
            16 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nickname,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(labelText: s.loadNickname, hintText: s.loadNicknameHint),
              ),
              const SizedBox(height: 14),
              if (_editingPlace) ...[
                TextField(
                  controller: _place,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: s.laundromatOptional, hintText: s.laundromatHint),
                ),
                if (recent.length > 1) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in recent)
                        Pill(label: r, selected: _place.text == r, onTap: () => setState(() => _place.text = r)),
                    ],
                  ),
                ],
              ] else
                // Most people use one laundromat: show it, don't ask again.
                Row(
                  children: [
                    Icon(AppIcons.laundry, size: 20, color: context.ink),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.atPlace(_place.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _editingPlace = true),
                      child: Text(s.change),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                child: Text(s.dropOff(widget.count)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
