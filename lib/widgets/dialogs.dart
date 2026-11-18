import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Asks for confirmation with the platform's own alert style (an iOS alert
/// on iPhone, a Material dialog on Android). Returns true if confirmed.
///
/// Use only for actions that can't be undone; everything else gets an Undo.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final ios = Theme.of(context).platform == TargetPlatform.iOS;

  Widget action(String label, bool value, {bool isDefault = false, bool isDestructive = false}) {
    if (ios) {
      return CupertinoDialogAction(
        isDefaultAction: isDefault,
        isDestructiveAction: isDestructive,
        onPressed: () => Navigator.pop(context, value),
        child: Text(label),
      );
    }
    return TextButton(
      onPressed: () => Navigator.pop(context, value),
      style: isDestructive ? TextButton.styleFrom(foregroundColor: context.colors.error) : null,
      child: Text(label),
    );
  }

  final result = await showAdaptiveDialog<bool>(
    context: context,
    builder: (_) => AlertDialog.adaptive(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        action(cancelLabel, false, isDefault: !destructive),
        action(confirmLabel, true, isDefault: destructive ? false : true, isDestructive: destructive),
      ],
    ),
  );
  return result ?? false;
}

/// Shows a short message at the bottom, optionally with an Undo-style action.
void showMessage(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      // Undo snackbars should still go away on their own.
      persist: false,
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );
}
