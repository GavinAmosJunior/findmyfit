import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/backup_service.dart';
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
  bool _working = false;

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
