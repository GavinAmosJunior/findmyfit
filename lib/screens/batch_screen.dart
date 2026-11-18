import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../models/laundry_batch.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/tags.dart';
import '../widgets/dialogs.dart';
import '../widgets/garment_image.dart';
import 'home_shell.dart';
import '../theme/app_icons.dart';
import '../widgets/store_sign.dart';

/// The return check: tick each piece as it comes back from the laundromat.
/// Anything left unticked when you finish moves to Missing.
class BatchScreen extends StatelessWidget {
  final String batchId;

  const BatchScreen({super.key, required this.batchId});

  static Future<void> open(BuildContext context, String batchId) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => BatchScreen(batchId: batchId)));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final batch = state.batchById(batchId);
    if (batch == null) return const Scaffold();
    final garments = state.garmentsInBatch(batch);
    final editable = !batch.isCompleted;

    return Scaffold(
      appBar: SignBar(
        title: s.loadName(batch),
        subtitle: s.loadLine(batch),
        color: SignColors.green,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'edit' ? _editLoad(context, batch) : _cancel(context, batch),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(s.editLoad)),
              if (editable) PopupMenuItem(value: 'cancel', child: Text(s.cancelBatch)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          if (!editable) _CompletedStamp(batch: batch),
          if (editable) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(s.tickAsBack, style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText)),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: batch.progress,
                minHeight: 6,
                backgroundColor: context.palette.separator,
                color: context.palette.clean.foreground,
              ),
            ),
            const SizedBox(height: 8),
            // "All back" sits here, not in the top bar, so long translations
            // still fit next to the title on small phones.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(s.backCount(batch.verifiedCount, batch.totalItems), style: context.text.labelMedium),
                ),
                TextButton.icon(
                  // Green like the rest of the laundry screens.
                  style: TextButton.styleFrom(foregroundColor: context.palette.clean.foreground),
                  onPressed: batch.verifiedCount == garments.length
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          state.markAllReceived(batch.id);
                        },
                  icon: const Icon(AppIcons.checkAll),
                  label: Text(s.allBack),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, g) in garments.indexed) ...[
                  if (i > 0) const Divider(indent: 74),
                  _ReturnRow(
                    garment: g,
                    received: batch.isItemVerified(g.id),
                    editable: editable,
                    onToggle: () {
                      HapticFeedback.selectionClick();
                      state.toggleReceived(batch.id, g.id);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !editable
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: () => _finish(context, batch),
                  style: FilledButton.styleFrom(backgroundColor: SignColors.green, foregroundColor: Colors.white),
                  child: Text(s.finishReturn),
                ),
              ),
            ),
    );
  }

  Future<void> _finish(BuildContext context, LaundryBatch batch) async {
    final s = S.of(context);
    final state = AppScope.read(context);
    final notBack = state.garmentsInBatch(batch).where((g) => !batch.isItemVerified(g.id)).length;
    final ok = await confirmAction(
      context,
      title: notBack == 0 ? s.finishAllBackTitle : s.finishMissingTitle(notBack),
      body: notBack == 0 ? s.finishAllBackBody : s.finishMissingBody(notBack),
      confirmLabel: notBack == 0 ? s.done : s.moveToMissing,
      cancelLabel: s.keepChecking,
    );
    if (!ok || !context.mounted) return;
    state.finishReturn(batch.id);
    if (notBack == 0) {
      // Everything came back: stay here and let the stamp land.
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    final shell = HomeShellState.maybeOf(context);
    Navigator.of(context).pop();
    shell?.goTo(HomeShellState.missingTab);
  }

  Future<void> _editLoad(BuildContext context, LaundryBatch batch) async {
    final result = await showDialog<({String nickname, String place})>(
      context: context,
      builder: (_) => _EditLoadDialog(batch: batch),
    );
    if (result == null || !context.mounted) return;
    AppScope.read(context).editLoad(batch.id, nickname: result.nickname, laundromatName: result.place);
  }

  Future<void> _cancel(BuildContext context, LaundryBatch batch) async {
    final s = S.of(context);
    final ok = await confirmAction(
      context,
      title: s.cancelBatchTitle,
      body: s.cancelBatchBody,
      confirmLabel: s.cancelBatch,
      cancelLabel: s.keepBatch,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    AppScope.read(context).cancelBatch(batch.id);
    Navigator.of(context).pop();
  }
}

/// Name a load after the fact, or fix where it went.
class _EditLoadDialog extends StatefulWidget {
  final LaundryBatch batch;

  const _EditLoadDialog({required this.batch});

  @override
  State<_EditLoadDialog> createState() => _EditLoadDialogState();
}

class _EditLoadDialogState extends State<_EditLoadDialog> {
  late final _nickname = TextEditingController(text: widget.batch.nickname ?? '');
  late final _place = TextEditingController(text: widget.batch.laundromatName);

  @override
  void dispose() {
    _nickname.dispose();
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.editLoad),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nickname,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: s.loadNickname, hintText: s.loadNo(widget.batch.number)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _place,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: s.laundromatOptional, hintText: s.laundromatHint),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
        TextButton(
          onPressed: () => Navigator.of(context).pop((nickname: _nickname.text, place: _place.text)),
          child: Text(s.save),
        ),
      ],
    );
  }
}

class _ReturnRow extends StatelessWidget {
  final Garment garment;
  final bool received;
  final bool editable;
  final VoidCallback onToggle;

  const _ReturnRow({required this.garment, required this.received, required this.editable, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final clean = context.palette.clean;

    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        checked: received,
        child: InkWell(
          onTap: editable ? onToggle : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(dimension: 52, child: GarmentImage(garment: garment, iconSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(garment.name, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (!editable) ...[
                        const SizedBox(height: 4),
                        StatusChip(status: garment.status),
                      ] else
                        Text(s.categoryLabel(garment.category), style: context.text.bodySmall),
                    ],
                  ),
                ),
                if (editable)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      received ? AppIcons.checked : AppIcons.unchecked,
                      key: ValueKey(received),
                      size: 30,
                      color: received ? clean.foreground : context.palette.tertiaryText,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The plate on a finished check. It drops in only right after you
/// finish, not every time you open an old ticket.
class _CompletedStamp extends StatelessWidget {
  final LaundryBatch batch;

  const _CompletedStamp({required this.batch});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final missing = AppScope.of(context).stillMissingFrom(batch);
    final done = batch.completedAt;
    final justFinished = done != null && DateTime.now().difference(done) < const Duration(seconds: 3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
      child: Center(
        child: missing == 0
            ? StatusPlate(s.allBack, color: SignColors.green, icon: AppIcons.check, fontSize: 26, land: justFinished)
            : StatusPlate(s.stampMissing(missing), color: SignColors.red, fontSize: 26),
      ),
    );
  }
}
