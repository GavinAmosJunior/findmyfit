import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../services/backup_service.dart';
import '../services/cutout.dart';
import '../services/image_store.dart';
import '../services/samples.dart';
import '../state/app_scope.dart';
import '../widgets/dialogs.dart';
import '../widgets/grouped_section.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _clearing = false;

  bool _working = false;

  // Removing all backgrounds: how far along, while it runs.
  int? _cutDone;
  int _cutTotal = 0;

  /// Clothes with a plain photo that could get the clean cutout look.
  List<Garment> _plainPhotos() => AppScope.read(context)
      .garments
      .where((g) => g.imageUrl != null && g.imageUrl!.isNotEmpty && !ImageStore.isCutout(g.imageUrl))
      .toList();

  /// Lifts every plain photo onto the clean backdrop, one at a time, and
  /// swaps it in. Stops early if the phone can't run it yet.
  Future<void> _removeAllBackgrounds() async {
    final s = S.of(context);
    final state = AppScope.read(context);
    final todo = _plainPhotos();
    if (todo.isEmpty) return;
    final ok = await confirmAction(
      context,
      title: s.cutoutAllTitle(todo.length),
      body: s.cutoutAllBody,
      confirmLabel: s.removeBackgrounds,
      cancelLabel: s.cancel,
    );
    if (!ok || !mounted) return;

    setState(() {
      _cutDone = 0;
      _cutTotal = todo.length;
    });
    var updated = 0, skipped = 0;
    String? stopped;
    for (final g in todo) {
      if (!mounted) return;
      final bytes = await ImageStore.read(g.imageUrl!);
      final result = bytes == null ? null : await Cutout.lift(bytes);
      if (result != null && result.unavailable) {
        stopped = result.downloading ? s.cutoutNotReady : s.cutoutFailed;
        break;
      }
      final png = result?.png;
      final current = state.garmentById(g.id);
      // Skip pieces with no clear garment, or changed or deleted meanwhile.
      if (png == null || current == null || current.imageUrl != g.imageUrl) {
        skipped++;
      } else {
        final stored = await ImageStore.saveBytes(png);
        state.updateGarment(current.edited(
          name: current.name,
          category: current.category,
          brand: current.brand,
          notes: current.notes,
          imageUrl: stored,
        ));
        updated++;
      }
      if (mounted) setState(() => _cutDone = updated + skipped);
    }
    if (!mounted) return;
    setState(() => _cutDone = null);
    showMessage(context, stopped ?? s.cutoutAllDone(updated, skipped));
  }

  Future<void> _export() async {
    final s = S.of(context);
    setState(() => _working = true);
    try {
      await BackupService.export(AppScope.read(context));
    } catch (_) {
      if (mounted) showMessage(context, s.exportFailed);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _import() async {
    final s = S.of(context);
    final state = AppScope.read(context);
    Map<String, dynamic>? backup;
    try {
      backup = await BackupService.pick();
    } catch (_) {
      if (mounted) showMessage(context, s.importFailed);
      return;
    }
    if (backup == null || !mounted) return;

    final ok = await confirmAction(
      context,
      title: s.importTitle,
      body: s.importBody(BackupService.garmentCount(backup)),
      confirmLabel: s.replace,
      cancelLabel: s.cancel,
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _working = true);
    try {
      await BackupService.restore(state, backup);
      if (mounted) showMessage(context, s.importDone);
    } catch (_) {
      if (mounted) showMessage(context, s.importFailed);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          GroupedSection(
            header: s.appearance,
            children: [
              for (final (mode, label) in [
                ('system', s.systemLanguage),
                ('light', s.light),
                ('dark', s.dark),
              ])
                ListTile(
                  title: Text(label),
                  selected: state.appearance == mode,
                  selectedColor: context.ink,
                  trailing: state.appearance == mode
                      ? Icon(AppIcons.check, color: context.ink, size: 20)
                      : null,
                  onTap: () => state.setAppearance(mode),
                ),
            ],
          ),
          GroupedSection(
            header: s.language,
            children: [
              for (final (code, label) in [
                ('system', s.systemLanguage),
                ('en', 'English'),
                ('id', 'Bahasa Indonesia'),
              ])
                ListTile(
                  title: Text(label),
                  selected: state.language == code,
                  selectedColor: context.ink,
                  trailing: state.language == code
                      ? Icon(AppIcons.check, color: context.ink, size: 20)
                      : null,
                  onTap: () => state.setLanguage(code),
                ),
            ],
          ),
          if (Cutout.supported)
            Builder(
              builder: (context) {
                final plain = _plainPhotos().length;
                final running = _cutDone != null;
                return GroupedSection(
                  header: s.photos,
                  footer: s.photosFooter,
                  children: [
                    ListTile(
                      enabled: !_working && !running && plain > 0,
                      leading: running
                          ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(AppIcons.cutout),
                      title: Text(s.removeBackgrounds),
                      subtitle: Text(
                        running
                            ? s.cutoutAllProgress((_cutDone! + 1).clamp(1, _cutTotal), _cutTotal)
                            : (plain > 0 ? s.cutoutAllCount(plain) : s.cutoutAllNone),
                      ),
                      onTap: _removeAllBackgrounds,
                    ),
                  ],
                );
              },
            ),
          GroupedSection(
            header: s.backup,
            footer: s.backupFooter,
            children: [
              ListTile(
                enabled: !_working,
                leading: const Icon(AppIcons.share),
                title: Text(s.exportBackup),
                onTap: _export,
              ),
              ListTile(
                enabled: !_working,
                leading: const Icon(AppIcons.download),
                title: Text(s.importBackup),
                onTap: _import,
              ),
            ],
          ),
          GroupedSection(
            header: s.gettingStarted,
            children: [
              ListTile(
                leading: const Icon(AppIcons.closet),
                title: Text(s.showWelcome),
                subtitle: Text(s.showWelcomeHint),
                onTap: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  Samples.replayWelcome(state);
                },
              ),
              if (state.hasSamples)
                ListTile(
                  leading: _clearing
                      ? SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: context.palette.signal),
                        )
                      : Icon(AppIcons.delete, color: context.palette.signal),
                  title: Text(s.removeSamples, style: TextStyle(color: context.palette.signal)),
                  onTap: _clearing
                      ? null
                      : () async {
                          // A short beat so it reads as work done, then back
                          // to a closet that's all yours.
                          HapticFeedback.mediumImpact();
                          setState(() => _clearing = true);
                          await Future<void>.delayed(const Duration(milliseconds: 900));
                          if (!context.mounted) return;
                          final messenger = ScaffoldMessenger.of(context);
                          Samples.remove(state);
                          Navigator.of(context).popUntil((r) => r.isFirst);
                          showMessageOn(messenger, s.allClear);
                        },
                ),
            ],
          ),
          GroupedSection(
            header: s.about,
            children: [
              ListTile(
                title: const Text('FindMyFit'),
                subtitle: Text(s.aboutBody),
              ),
            ],
          ),
          if (_working) const Center(child: CircularProgressIndicator.adaptive()),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
