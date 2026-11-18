import 'package:flutter/widgets.dart';

import 'wardrobe_state.dart';

/// Gives every widget below it access to [WardrobeState] and rebuilds
/// dependents whenever the state changes.
class AppScope extends InheritedNotifier<WardrobeState> {
  const AppScope({super.key, required WardrobeState state, required super.child})
      : super(notifier: state);

  static WardrobeState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Reads the state without subscribing to changes (for callbacks).
  static WardrobeState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
