import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/strings.dart';
import 'screens/home_shell.dart';
import 'services/image_store.dart';
import 'state/app_scope.dart';
import 'state/wardrobe_state.dart';
import 'theme/app_theme.dart';
import 'widgets/mobile_frame.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FindMyFitApp(state: WardrobeState()));
}

class FindMyFitApp extends StatefulWidget {
  final WardrobeState state;

  const FindMyFitApp({super.key, required this.state});

  @override
  State<FindMyFitApp> createState() => _FindMyFitAppState();
}

class _FindMyFitAppState extends State<FindMyFitApp> {
  bool _cleaned = false;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_cleanUpPhotosOnce);
  }

  // Once data has loaded, delete photo files left behind by deleted clothes.
  void _cleanUpPhotosOnce() {
    if (_cleaned || !widget.state.isLoaded) return;
    _cleaned = true;
    ImageStore.deleteUnused(widget.state.garments.map((g) => g.imageUrl).whereType<String>().toSet());
  }

  @override
  void dispose() {
    widget.state.removeListener(_cleanUpPhotosOnce);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          final lang = widget.state.language;
          return MaterialApp(
            title: 'FindMyFit',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.system,
            locale: lang == 'system' ? null : Locale(lang),
            supportedLocales: S.supported,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MobileFrame(child: child!),
            home: HomeShell(key: homeShellKey),
          );
        },
      ),
    );
  }
}
