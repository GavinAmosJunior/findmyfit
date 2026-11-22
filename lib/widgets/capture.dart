import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Draws [child] off screen and returns it as a PNG: for pictures made to
/// be shared, like a story or a note to the laundromat.
Future<Uint8List> captureOffscreen(BuildContext context, Widget child, {double pixelRatio = 3}) async {
  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(left: -4000, top: 0, child: RepaintBoundary(key: key, child: child)),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  try {
    // Time for the pictures in it to decode at this size.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await WidgetsBinding.instance.endOfFrame;
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw StateError('No picture');
    return png.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}
