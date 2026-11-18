import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_navigation_screen.dart';
import 'state/wardrobe_state.dart';
import 'theme/app_theme.dart';
import 'widgets/mobile_frame.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const SmartLaundryTrackerApp());
}

class SmartLaundryTrackerApp extends StatefulWidget {
  const SmartLaundryTrackerApp({super.key});

  @override
  State<SmartLaundryTrackerApp> createState() => _SmartLaundryTrackerAppState();
}

class _SmartLaundryTrackerAppState extends State<SmartLaundryTrackerApp> {
  late final WardrobeState _wardrobeState;

  @override
  void initState() {
    super.initState();
    _wardrobeState = WardrobeState();
  }

  @override
  void dispose() {
    _wardrobeState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FindMyFit - Smart Laundry Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: MobileFrame(
        child: MainNavigationScreen(state: _wardrobeState),
      ),
    );
  }
}
