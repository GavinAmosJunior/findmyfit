import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/garment_image.dart';
import 'garment_sheet.dart';
import 'home_shell.dart';

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
          SliverAppBar.large(
            title: Text(s.hamper),
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
              const SizedBox(width: 8),
            ],
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.shopping_basket_outlined,
                title: s.emptyHamperTitle,
                body: s.emptyHamperBody,
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  s.hamperSubtitle(items.length, selected.length),
                  style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              // One grouped list, like iOS, rather than a stack of cards.
              sliver: DecoratedSliver(
                decoration: BoxDecoration(
                  color: context.palette.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.palette.separator),
                ),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(indent: 124),
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
                  icon: const Icon(Icons.local_laundry_service_rounded),
                  label: Text(s.sendToLaundry(selected.length)),
                ),
              ),
            ),
    );
  }

  Future<void> _send(BuildContext context, List<Garment> selected) async {
    final s = S.of(context);
    final result = await showModalBottomSheet<(String, DateTime?)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SendSheet(count: selected.length),
    );
    if (result == null || !context.mounted) return;
    final state = AppScope.read(context);
    final batch = state.sendToLaundry(
      garmentIds: selected.map((g) => g.id).toList(),
      laundromatName: result.$1,
      pickupDate: result.$2,
    );
    HapticFeedback.mediumImpact();
    showMessage(context, s.sentToLaundry(batch.totalItems, batch.laundromatName));
    HomeShellState.maybeOf(context)?.goTo(2);
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

    return Dismissible(
      key: ValueKey(garment.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: context.palette.clean.background,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.swipePutBack,
              style: TextStyle(color: context.palette.clean.foreground, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Icon(Icons.checkroom_rounded, color: context.palette.clean.foreground),
          ],
        ),
      ),
      onDismissed: (_) {
        state.moveToCloset(garment.id);
        showMessage(
          context,
          '${garment.name} · ${s.putBackClean}',
          actionLabel: s.undo,
          onAction: () => state.moveToHamper(garment.id),
        );
      },
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          checked: selected,
          child: InkWell(
            onTap: onToggle,
            onLongPress: () => GarmentSheet.show(context, garment.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Checkbox.adaptive(value: selected, onChanged: (_) => onToggle()),
                  const SizedBox(width: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox.square(dimension: 52, child: GarmentImage(garment: garment, iconSize: 24)),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the clothes are going and when to pick them up.
class _SendSheet extends StatefulWidget {
  final int count;

  const _SendSheet({required this.count});

  @override
  State<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<_SendSheet> {
  final _place = TextEditingController();
  DateTime? _pickup;

  @override
  void initState() {
    super.initState();
    final recent = AppScope.read(context).recentLaundromats;
    if (recent.isNotEmpty) _place.text = recent.first;
  }

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickup ?? now.add(const Duration(days: 2)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _pickup = picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final recent = AppScope.read(context).recentLaundromats.take(4).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.sendSheetTitle, style: context.text.headlineSmall),
          const SizedBox(height: 4),
          Text(s.items(widget.count), style: context.text.bodySmall),
          const SizedBox(height: 20),
          TextField(
            controller: _place,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: s.laundromat, hintText: s.laundromatHint),
          ),
          if (recent.length > 1) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in recent) ActionChip(label: Text(r), onPressed: () => setState(() => _place.text = r)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text(s.pickupDate),
              trailing: Text(
                _pickup == null ? s.noPickupDate : s.weekdayDate(_pickup!),
                style: context.text.bodyMedium?.copyWith(color: context.colors.primary),
              ),
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop((_place.text, _pickup)),
            child: Text(s.sendToLaundry(widget.count)),
          ),
        ],
      ),
    );
  }
}
