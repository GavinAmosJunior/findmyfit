import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Saves garment photos somewhere that survives an app restart.
///
/// * Phones and desktop: copied into the app's documents folder.
/// * Web: stored inline as a small `data:` URL, because the browser's
///   temporary `blob:` URLs stop working after a reload.
class ImageStore {
  static const _folder = 'garments';

  /// Options for the picker. Small enough that a few hundred photos fit in
  /// browser storage on web, sharp enough for a phone screen.
  static const maxSize = 900.0;
  static const quality = 72;

  static Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_folder');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Whether these bytes are a PNG: how cutouts are stored, since they need
  /// a transparent background. Camera photos are JPEGs.
  static bool isCutoutBytes(Uint8List bytes) =>
      bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;

  /// Whether a stored image is a cutout (garment on a transparent background).
  static bool isCutout(String? ref) =>
      ref != null && (ref.toLowerCase().endsWith('.png') || ref.startsWith('data:image/png'));

  static String _dataUrl(Uint8List bytes) =>
      'data:image/${isCutoutBytes(bytes) ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}';

  static Future<String> savePicked(XFile picked) async => saveBytes(await picked.readAsBytes());

  /// Stores a photo or cutout and returns its reference.
  static Future<String> saveBytes(Uint8List bytes) async {
    if (kIsWeb) return _dataUrl(bytes);
    final dir = await _dir();
    final ext = isCutoutBytes(bytes) ? 'png' : 'jpg';
    final file = File('${dir.path}/g_${DateTime.now().microsecondsSinceEpoch}.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Reads a stored image back, for rotating it.
  static Future<Uint8List?> read(String ref) async {
    try {
      if (ref.startsWith('data:')) return UriData.parse(ref).contentAsBytes();
      if (kIsWeb || ref.startsWith('http')) return null;
      return await File(ref).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Turns a stored image reference into something that can travel inside
  /// a backup file.
  static Future<String?> toPortable(String? ref) async {
    if (ref == null || ref.isEmpty) return null;
    if (ref.startsWith('data:') || ref.startsWith('http')) return ref;
    if (kIsWeb) return null; // A stale blob: URL from an older version.
    try {
      final file = File(ref);
      if (!file.existsSync()) return null;
      return _dataUrl(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  /// The reverse of [toPortable]: on phones, writes inline images to files.
  static Future<String?> fromPortable(String? ref) async {
    if (ref == null || !ref.startsWith('data:') || kIsWeb) return ref;
    try {
      final bytes = UriData.parse(ref).contentAsBytes();
      final dir = await _dir();
      final ext = isCutoutBytes(bytes) ? 'png' : 'jpg';
      final file = File('${dir.path}/g_${DateTime.now().microsecondsSinceEpoch}_${ref.hashCode.abs()}.$ext');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Deletes photo files no garment uses any more (phones only).
  static Future<void> deleteUnused(Set<String> inUse) async {
    if (kIsWeb) return;
    try {
      final dir = await _dir();
      for (final f in dir.listSync().whereType<File>()) {
        if (!inUse.contains(f.path)) f.deleteSync();
      }
    } catch (e) {
      debugPrint('Photo cleanup skipped: $e');
    }
  }
}
