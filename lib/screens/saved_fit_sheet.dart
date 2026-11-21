import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../models/saved_fit.dart';
import '../state/app_scope.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/fit_collage.dart';

/// A saved fit, large: the flat-lay board, with Share (as a picture),
/// Show on rails, and Remove.
class SavedFitSheet extends StatefulWidget {
  final SavedFit fit;
  final VoidCallback onShow;

  const SavedFitSheet({super.key, required this.fit, required this.onShow});

  static Future<void> show(BuildContext context, SavedFit fit, {required VoidCallback onShow}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SavedFitSheet(fit: fit, onShow: onShow),
    );
  }

  @override
  State<SavedFitSheet> createState() => _SavedFitSheetState();
}

class _SavedFitSheetState extends State<SavedFitSheet> {
  final _board = GlobalKey();
  bool _sharing = false;

  /// The board as a picture, with the app's mark, through the share sheet.
  Future<void> _share(List<Garment> pieces) async {
    final s = S.of(context);
    setState(() => _sharing = true);
    try {
      final boundary = _board.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('No picture');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(png.buffer.asUint8List(), mimeType: 'image/png', name: 'my-fit.png')],
          fileNameOverrides: ['my-fit.png'],
          text: pieces.map((g) => g.name).join(' · '),
        ),
      );
    } catch (_) {
      if (mounted) showMessage(context, s.shareFailed);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);
    final pieces = widget.fit.itemIds.map(state.garmentById).whereType<Garment>().toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.savedFit, style: context.text.headlineSmall),
          const SizedBox(height: 4),
          Text(
            pieces.map((g) => g.name).join(' · '),
            style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText),
          ),
          const SizedBox(height: 16),
          // What gets shared: the board, with the mark in its corner.
          RepaintBoundary(
            key: _board,
            child: Stack(
              children: [
                FitCollage(pieces: pieces, radius: 28),
                Positioned(right: 16, bottom: 14, child: _Mark(color: context.palette.secondaryText)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _sharing ? null : () => _share(pieces),
            icon: const Icon(AppIcons.share, size: 20),
            label: Text(s.share),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onShow();
            },
            icon: const Icon(AppIcons.shuffle, size: 20),
            label: Text(s.showOnRails),
          ),
          const SizedBox(height: 4),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.palette.signal),
            onPressed: () {
              HapticFeedback.lightImpact();
              state.toggleFit(widget.fit.itemIds);
              Navigator.of(context).pop();
            },
            child: Text(s.removeFit),
          ),
        ],
      ),
    );
  }
}

/// The app's logo and name, small, for shared pictures.
class _Mark extends StatelessWidget {
  final Color color;

  const _Mark({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          Theme.of(context).brightness == Brightness.dark ? 'assets/brand/logo_mark_dark.png' : 'assets/brand/logo_mark.png',
          width: 16,
          height: 16,
        ),
        const SizedBox(width: 5),
        Text('FindMyFit', style: context.text.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
