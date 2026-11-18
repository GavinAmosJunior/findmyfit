import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../state/wardrobe_state.dart';
import 'image_store.dart';

/// Saves the whole wardrobe, photos included, to one JSON file and reads
/// it back. On phones the file goes through the share sheet (save to Files,
/// Drive, WhatsApp to yourself…); on web it downloads.
class BackupService {
  static String fileName() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'findmyfit-backup-${d.year}-${two(d.month)}-${two(d.day)}.json';
  }

  static Future<Uint8List> buildFile(WardrobeState state) async {
    final data = state.toBackup();
    for (final g in data['garments'] as List) {
      final json = g as Map<String, dynamic>;
      json['imageUrl'] = await ImageStore.toPortable(json['imageUrl'] as String?);
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(data)));
  }

  static Future<void> export(WardrobeState state) async {
    final bytes = await buildFile(state);
    final name = fileName();
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, name: name, mimeType: 'application/json')],
      fileNameOverrides: [name],
      subject: 'FindMyFit backup',
    ));
  }

  /// Lets the person pick a backup file. Returns its parsed contents, or
  /// null if they cancelled. Throws [FormatException] for other files.
  static Future<Map<String, dynamic>?> pick() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (files.isEmpty) return null;
    final text = utf8.decode(await files.first.readAsBytes());
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic> || decoded['format'] != WardrobeState.backupFormat) {
      throw const FormatException('Not a FindMyFit backup');
    }
    return decoded;
  }

  static int garmentCount(Map<String, dynamic> backup) => (backup['garments'] as List? ?? []).length;

  /// Writes photos back to disk (phones) and replaces the wardrobe.
  static Future<void> restore(WardrobeState state, Map<String, dynamic> backup) async {
    for (final g in backup['garments'] as List? ?? []) {
      final json = g as Map<String, dynamic>;
      json['imageUrl'] = await ImageStore.fromPortable(json['imageUrl'] as String?);
    }
    state.restoreBackup(backup);
  }
}
