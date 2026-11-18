import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../models/laundry_batch.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/care_label.dart';
import '../widgets/dialogs.dart';
import '../widgets/garment_image.dart';
import 'home_shell.dart';

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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(batch.laundromatName),
            Text('${batch.batchCode} · ${s.sentOn(s.date(batch.createdAt))}', style: context.text.bodySmall),
          ],
        ),
        actions: [
          if (editable) ...[
            TextButton(
              onPressed: batch.verifiedCount == garments.length
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      state.markAllReceived(batch.id);
                    },
              child: Text(s.allBack),
            ),
            PopupMenuButton<String>(
              onSelected: (_) => _cancel(context, batch),
              itemBuilder: (_) => [PopupMenuItem(value: 'cancel', child: Text(s.cancelBatch))],
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(s.backCount(batch.verifiedCount, batch.totalItems), style: context.text.labelMedium),
            ),
            const SizedBox(height: 16),
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
                child: FilledButton(onPressed: () => _finish(context, batch), child: Text(s.finishReturn)),
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
      body: notBack == 0 ? s.finishAllBackBody : s.finishMissingBody,
      confirmLabel: notBack == 0 ? s.done : s.moveToMissing,
      cancelLabel: s.keepChecking,
    );
    if (!ok || !context.mounted) return;
    state.finishReturn(batch.id);
    HapticFeedback.mediumImpact();
    final shell = HomeShellState.maybeOf(context);
    Navigator.of(context).pop();
    shell?.goTo(notBack > 0 ? 3 : 0);
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
                        CareLabel(status: garment.status),
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
                      received ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
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
