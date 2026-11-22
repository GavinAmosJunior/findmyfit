import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/app_scope.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/capture.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/garment_image.dart';
import '../widgets/pressable.dart';
import 'garment_sheet.dart';

/// Clothes that didn't come back. Grouped by laundromat, each group can
/// send that laundromat a ready-made message listing what's missing.
/// Opened from the Laundry tab.
class MissingScreen extends StatelessWidget {
  const MissingScreen({super.key});

  static Future<void> open(BuildContext context, {bool replace = false}) {
    final route = MaterialPageRoute<void>(builder: (_) => const MissingScreen());
    final nav = Navigator.of(context);
    return replace ? nav.pushReplacement(route) : nav.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final missing = state.withStatus(GarmentStatus.missing);
    final lost = state.withStatus(GarmentStatus.lost);

    // Group by laundromat so one message covers each place.
    final groups = <String, List<Garment>>{};
    for (final g in missing) {
      // Loads with no laundromat set share one group.
      final place = state.batchById(g.currentBatchId)?.laundromatName ?? '';
      groups.putIfAbsent(place, () => []).add(g);
    }

    return Scaffold(
      appBar: AppBar(title: BarTitle(s.missing, subtitle: missing.isEmpty ? null : s.missingSubtitle)),
      body: missing.isEmpty && lost.isEmpty
          ? EmptyState(icon: AppIcons.allFound, title: s.emptyMissingTitle, body: s.emptyMissingBody)
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                for (final (i, MapEntry(key: place, value: garments)) in groups.entries.indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _PlaceCard(place: place, garments: garments),
                ],
                // Pieces you stopped looking for: kept, quiet, and one tap
                // from coming back.
                if (lost.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 26, 4, 8),
                    child: Text(s.lostSection, style: context.text.titleMedium),
                  ),
                  for (final g in lost) _LostPiece(garment: g),
                ],
              ],
            ),
    );
  }
}

/// One laundromat: what's missing from there, and a ready-made message to
/// ask about it.
class _PlaceCard extends StatelessWidget {
  final String place;
  final List<Garment> garments;

  const _PlaceCard({required this.place, required this.garments});

  /// The message, with a picture of what's missing so they know what to
  /// look for. Falls back to the words alone if the picture can't be made.
  Future<void> _ask(BuildContext context, S s, String title) async {
    final text = s.askMessage(place, garments.map((g) => g.name).toList());
    try {
      final png = await captureOffscreen(context, _AskPicture(title: s.missingFrom(title), garments: garments), pixelRatio: 2.5);
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          files: [XFile.fromData(png, mimeType: 'image/png', name: 'missing.png')],
          fileNameOverrides: ['missing.png'],
        ),
      );
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final title = place.isEmpty ? s.laundromat : place;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(color: context.palette.tile, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                ),
                const SizedBox(width: 8),
                Text(
                  s.stampMissing(garments.length),
                  style: context.text.labelMedium?.copyWith(color: context.palette.signal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final (i, g) in garments.indexed) ...[if (i > 0) const Divider(height: 28), _MissingPiece(garment: g)],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(backgroundColor: context.colors.surface),
            onPressed: () => _ask(context, s, title),
            icon: const Icon(AppIcons.chat, size: 20),
            label: Text(s.askLaundromat),
          ),
        ],
      ),
    );
  }
}

class _MissingPiece extends StatelessWidget {
  final Garment garment;

  const _MissingPiece({required this.garment});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.read(context);
    final batch = state.batchById(garment.currentBatchId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tap the piece for its details: edit it, or delete it.
        Pressable(
          label: garment.name,
          onTap: () => GarmentSheet.show(context, garment.id),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox.square(
                  dimension: 64,
                  child: GarmentImage(garment: garment, iconSize: 26, backdrop: context.colors.surface),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(garment.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                    if (batch != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${s.loadName(batch)} · ${s.sentOn(s.date(batch.createdAt))}',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(AppIcons.chevron, size: 14, color: context.palette.tertiaryText),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(44, 46)),
                onPressed: () {
                  final fromBatch = garment.currentBatchId;
                  state.markFound(garment.id);
                  HapticFeedback.mediumImpact();
                  showMessage(
                    context,
                    s.foundMessage(garment.name),
                    actionLabel: s.undo,
                    onAction: () {
                      garment
                        ..status = GarmentStatus.missing
                        ..currentBatchId = fromBatch;
                      state.updateGarment(garment);
                    },
                  );
                },
                icon: const Icon(AppIcons.check, size: 18),
                label: Text(s.foundIt),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 46),
                  backgroundColor: context.colors.surface,
                ),
                onPressed: () async {
                  final ok = await confirmAction(
                    context,
                    title: s.lostTitle(garment.name),
                    body: s.lostBody,
                    confirmLabel: s.lostForGood,
                    cancelLabel: s.cancel,
                  );
                  if (ok) state.markLost(garment.id);
                },
                child: Text(s.lostForGood),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A piece you stopped looking for, with a way back to the closet.
class _LostPiece extends StatelessWidget {
  final Garment garment;

  const _LostPiece({required this.garment});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.square(dimension: 52, child: Opacity(opacity: 0.6, child: GarmentImage(garment: garment, iconSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(garment.name, style: context.text.titleSmall)),
          TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              AppScope.read(context).markFound(garment.id);
              showMessage(context, s.foundMessage(garment.name));
            },
            child: Text(s.bringBack),
          ),
        ],
      ),
    );
  }
}

/// The picture sent with the message: each missing piece and its name, on
/// white, so the laundromat can spot it on their shelves.
class _AskPicture extends StatelessWidget {
  final String title;
  final List<Garment> garments;

  const _AskPicture({required this.title, required this.garments});

  @override
  Widget build(BuildContext context) {
    const width = 360.0, tile = 148.0;
    return Theme(
      data: AppTheme.light,
      child: Builder(
        builder: (context) => Container(
          width: width,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleLarge?.copyWith(color: const Color(0xFF1D1D1F))),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final g in garments)
                    SizedBox(
                      width: tile,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox.square(
                              dimension: tile,
                              child: GarmentImage(garment: g, backdrop: const Color(0xFFF2F2F4)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(g.name, maxLines: 2, style: context.text.titleSmall?.copyWith(color: const Color(0xFF1D1D1F))),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
