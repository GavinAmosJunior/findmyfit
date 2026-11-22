
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../models/saved_fit.dart';
import '../state/app_scope.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/capture.dart';
import '../widgets/dialogs.dart';
import '../widgets/fit_collage.dart';

/// A saved fit, large: the flat-lay board on its color, with Share to
/// story, Show on rails, and Remove.
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
  bool _sharing = false;

  /// The fit as a 9:16 story picture, through the share sheet, so it can
  /// go straight to an Instagram story.
  Future<void> _share(SavedFit fit, List<Garment> pieces) async {
    final s = S.of(context);
    final storyDate = DateFormat.MMMMd(Localizations.localeOf(context).toString()).format(fit.createdAt);
    setState(() => _sharing = true);
    HapticFeedback.lightImpact();
    try {
      final png = await captureOffscreen(context, _Story(pieces: pieces, tint: fit.tint, date: storyDate, s: s));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(png, mimeType: 'image/png', name: 'my-fit.png')],
          fileNameOverrides: ['my-fit.png'],
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
    // The fit as it is now, so a new color shows at once.
    final fit = state.fits.firstWhere((f) => f.id == widget.fit.id, orElse: () => widget.fit);
    final pieces = fit.itemIds.map(state.garmentById).whereType<Garment>().toList();
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(fit.createdAt);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.savedFit, style: context.text.headlineSmall),
          const SizedBox(height: 2),
          Text(date, style: context.text.bodyMedium?.copyWith(color: context.palette.secondaryText)),
          const SizedBox(height: 14),
          FitCollage(pieces: pieces, radius: 28, tint: fit.tint),
          const SizedBox(height: 14),
          // The board's color: a row of swatches, like picking a watch face.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (i, colors) in FitCollage.tints.indexed)
                Semantics(
                  button: true,
                  selected: i == fit.tint,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      state.setFitTint(fit.id, i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      width: 30,
                      height: 30,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: i == fit.tint ? context.ink : Colors.transparent, width: 2),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.first,
                          border: Border.all(color: context.palette.separator),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _sharing ? null : () => _share(fit, pieces),
            icon: _sharing
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.surface),
                  )
                : const Icon(AppIcons.share, size: 20),
            label: Text(s.shareStory),
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
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.palette.signal),
            onPressed: () {
              HapticFeedback.lightImpact();
              state.toggleFit(fit.itemIds);
              Navigator.of(context).pop();
            },
            child: Text(s.removeFit),
          ),
        ],
      ),
    );
  }
}

/// The story picture: the fit on its color, a title and its pieces. Always
/// light, so it looks the same wherever it's posted.
class _Story extends StatelessWidget {
  final List<Garment> pieces;
  final int tint;
  final String date;
  final S s;

  const _Story({required this.pieces, required this.tint, required this.date, required this.s});

  @override
  Widget build(BuildContext context) {
    final colors = FitCollage.tints[tint % FitCollage.tints.length];
    return Theme(
      data: AppTheme.light,
      child: Builder(
        builder: (context) => SizedBox(
          width: 360,
          height: 640,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 72, 28, 64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.myFit, style: context.text.displaySmall?.copyWith(color: const Color(0xFF1D1D1F))),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: context.text.titleMedium?.copyWith(color: const Color(0xFF6E6E73)),
                  ),
                  const Spacer(),
                  FitCollage(pieces: pieces, plain: true),
                  const Spacer(),
                  Text(
                    pieces.map((g) => g.name).join('  ·  '),
                    style: context.text.bodyMedium?.copyWith(color: const Color(0xFF6E6E73)),
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
