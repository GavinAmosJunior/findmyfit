import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/garment.dart';
import '../models/laundry_batch.dart';
import '../models/saved_fit.dart';

/// What a garment looked like before "Wore it", so the action can be undone.
typedef WornSnapshot = ({GarmentStatus status, int wearCount, DateTime? lastWornAt});

class WardrobeState extends ChangeNotifier {
  static const _keyGarments = 'saved_garments_v1';
  static const _keyBatches = 'saved_batches_v1';
  static const _keyBatchCounter = 'saved_batch_counter_v1';
  static const _keyLanguage = 'language_v1';
  static const _keyFits = 'saved_fits_v1';

  static const backupFormat = 'findmyfit-backup';
  static const backupVersion = 1;

  final List<Garment> _garments = [];
  final List<LaundryBatch> _batches = [];
  final List<SavedFit> _fits = [];
  int _batchCounter = 1000;
  bool _isLoaded = false;
  String _language = 'system';

  WardrobeState({bool load = true}) {
    if (load) loadFromStorage();
  }

  bool get isLoaded => _isLoaded;
  List<Garment> get garments => List.unmodifiable(_garments);
  List<LaundryBatch> get batches => List.unmodifiable(_batches);

  /// Saved outfits, newest first, skipping any whose pieces were deleted.
  List<SavedFit> get fits => _fits.where((f) => f.itemIds.every((id) => garmentById(id) != null)).toList();

  /// 'system', 'en' or 'id'.
  String get language => _language;

  List<Garment> withStatus(GarmentStatus status) =>
      _garments.where((g) => g.status == status).toList();

  int countOf(GarmentStatus status) => _garments.where((g) => g.status == status).length;

  List<LaundryBatch> get activeBatches => _batches.where((b) => !b.isCompleted).toList();
  List<LaundryBatch> get completedBatches => _batches.where((b) => b.isCompleted).toList();

  Garment? garmentById(String id) {
    for (final g in _garments) {
      if (g.id == id) return g;
    }
    return null;
  }

  LaundryBatch? batchById(String? id) {
    for (final b in _batches) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Garments in a batch, in the order they were sent. Deleted garments are skipped.
  List<Garment> garmentsInBatch(LaundryBatch batch) =>
      batch.itemIds.map(garmentById).whereType<Garment>().toList();

  /// Pieces from [batch] that are still missing (not found since).
  int stillMissingFrom(LaundryBatch batch) =>
      _garments.where((g) => g.status == GarmentStatus.missing && g.currentBatchId == batch.id).length;

  /// Laundromat names used before, most recent first.
  List<String> get recentLaundromats {
    final seen = <String>{};
    for (final b in _batches) {
      if (b.laundromatName.isNotEmpty) seen.add(b.laundromatName);
    }
    return seen.toList();
  }

  /// The number the next load will get.
  int get nextLoadNumber => _batchCounter + 1 - 1000;

  // ---------------------------------------------------------------- storage

  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _readJson(
        garments: prefs.getString(_keyGarments),
        batches: prefs.getString(_keyBatches),
        fits: prefs.getString(_keyFits),
      );
      _batchCounter = prefs.getInt(_keyBatchCounter) ?? 1000;
      _language = prefs.getString(_keyLanguage) ?? 'system';
    } catch (e) {
      debugPrint('Error loading wardrobe storage: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  void _readJson({String? garments, String? batches, String? fits}) {
    if (garments != null && garments.isNotEmpty) {
      _garments
        ..clear()
        ..addAll((jsonDecode(garments) as List).map((e) => Garment.fromJson(e as Map<String, dynamic>)));
    }
    if (batches != null && batches.isNotEmpty) {
      _batches
        ..clear()
        ..addAll((jsonDecode(batches) as List).map((e) => LaundryBatch.fromJson(e as Map<String, dynamic>)));
    }
    if (fits != null && fits.isNotEmpty) {
      _fits
        ..clear()
        ..addAll((jsonDecode(fits) as List).map((e) => SavedFit.fromJson(e as Map<String, dynamic>)));
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyGarments, jsonEncode(_garments.map((g) => g.toJson()).toList()));
      await prefs.setString(_keyBatches, jsonEncode(_batches.map((b) => b.toJson()).toList()));
      await prefs.setString(_keyFits, jsonEncode(_fits.map((f) => f.toJson()).toList()));
      await prefs.setInt(_keyBatchCounter, _batchCounter);
      await prefs.setString(_keyLanguage, _language);
    } catch (e) {
      debugPrint('Error saving wardrobe storage: $e');
    }
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  void setLanguage(String code) {
    _language = code;
    _changed();
  }

  // --------------------------------------------------------------- garments

  Garment addGarment({
    required String name,
    required GarmentCategory category,
    GarmentStatus status = GarmentStatus.closet,
    String? brand,
    String? notes,
    String? imageUrl,
    int? fallbackColor,
  }) {
    String? clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    final garment = Garment(
      id: 'g_${DateTime.now().microsecondsSinceEpoch}_${_garments.length}',
      name: clean(name) ?? 'Untitled',
      category: category,
      status: status,
      brand: clean(brand),
      notes: clean(notes),
      imageUrl: imageUrl,
      fallbackColor: fallbackColor,
    );
    _garments.insert(0, garment);
    _changed();
    return garment;
  }

  void updateGarment(Garment updated) {
    final i = _garments.indexWhere((g) => g.id == updated.id);
    if (i == -1) return;
    _garments[i] = updated;
    _changed();
  }

  /// Removes a garment and returns where it was, so it can be restored.
  int removeGarment(String id) {
    final i = _garments.indexWhere((g) => g.id == id);
    if (i == -1) return -1;
    _garments.removeAt(i);
    _changed();
    return i;
  }

  void restoreGarment(Garment garment, int index) {
    if (garmentById(garment.id) != null) return;
    _garments.insert(index.clamp(0, _garments.length), garment);
    _changed();
  }

  void toggleFavorite(String id) {
    final g = garmentById(id);
    if (g == null) return;
    g.isFavorite = !g.isFavorite;
    _changed();
  }

  // -------------------------------------------------------------- lifecycle

  /// Moves a clean garment to the hamper and counts the wear.
  WornSnapshot? markWorn(String id) {
    final g = garmentById(id);
    if (g == null) return null;
    final before = (status: g.status, wearCount: g.wearCount, lastWornAt: g.lastWornAt);
    g
      ..status = GarmentStatus.dirtyHamper
      ..wearCount += 1
      ..lastWornAt = DateTime.now()
      ..currentBatchId = null;
    _changed();
    return before;
  }

  void undoMarkWorn(String id, WornSnapshot before) {
    final g = garmentById(id);
    if (g == null) return;
    g
      ..status = before.status
      ..wearCount = before.wearCount
      ..lastWornAt = before.lastWornAt;
    _changed();
  }

  /// Puts a garment back in the closet (e.g. it wasn't dirty after all).
  void moveToCloset(String id) {
    final g = garmentById(id);
    if (g == null) return;
    g
      ..status = GarmentStatus.closet
      ..currentBatchId = null;
    _changed();
  }

  void moveToHamper(String id) {
    final g = garmentById(id);
    if (g == null) return;
    g
      ..status = GarmentStatus.dirtyHamper
      ..currentBatchId = null;
    _changed();
  }

  // ---------------------------------------------------------------- laundry

  /// Drops off a load. The laundromat and nickname are optional.
  LaundryBatch sendToLaundry({
    required List<String> garmentIds,
    String laundromatName = '',
    String? nickname,
  }) {
    _batchCounter++;
    final batch = LaundryBatch(
      id: 'batch_${DateTime.now().microsecondsSinceEpoch}_$_batchCounter',
      batchCode: '#L-$_batchCounter',
      laundromatName: laundromatName.trim(),
      nickname: _clean(nickname),
      itemIds: List.of(garmentIds),
    );
    for (final id in garmentIds) {
      final g = garmentById(id);
      if (g == null) continue;
      g
        ..status = GarmentStatus.inLaundry
        ..currentBatchId = batch.id;
    }
    _batches.insert(0, batch);
    _changed();
    return batch;
  }

  /// Renames a load or changes where it went.
  void editLoad(String batchId, {required String? nickname, required String laundromatName}) {
    final b = batchById(batchId);
    if (b == null) return;
    b
      ..nickname = _clean(nickname)
      ..laundromatName = laundromatName.trim();
    _changed();
  }

  static String? _clean(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

  void toggleReceived(String batchId, String garmentId) {
    final b = batchById(batchId);
    if (b == null) return;
    if (!b.verifiedItemIds.remove(garmentId)) b.verifiedItemIds.add(garmentId);
    _changed();
  }

  void markAllReceived(String batchId) {
    final b = batchById(batchId);
    if (b == null) return;
    b.verifiedItemIds
      ..clear()
      ..addAll(garmentsInBatch(b).map((g) => g.id));
    _changed();
  }

  /// Ends a return check: ticked items go back to the closet, the rest
  /// become missing (they keep the batch id so we know where they went).
  void finishReturn(String batchId) {
    final b = batchById(batchId);
    if (b == null) return;
    for (final g in garmentsInBatch(b)) {
      if (b.isItemVerified(g.id)) {
        g
          ..status = GarmentStatus.closet
          ..currentBatchId = null;
      } else {
        g.status = GarmentStatus.missing;
      }
    }
    b
      ..isCompleted = true
      ..completedAt = DateTime.now();
    _changed();
  }

  /// Undoes sending a batch: its items go back to the hamper.
  void cancelBatch(String batchId) {
    final b = batchById(batchId);
    if (b == null) return;
    for (final g in garmentsInBatch(b)) {
      g
        ..status = GarmentStatus.dirtyHamper
        ..currentBatchId = null;
    }
    _batches.remove(b);
    _changed();
  }

  // ------------------------------------------------------------ fit shuffle

  /// Clean clothes for the upper rail: anything worn on top.
  List<Garment> get shuffleTops => withStatus(GarmentStatus.closet)
      .where((g) => g.category != GarmentCategory.bottoms)
      .toList();

  /// Clean clothes for the lower rail.
  List<Garment> get shuffleBottoms => withStatus(GarmentStatus.closet)
      .where((g) => g.category == GarmentCategory.bottoms)
      .toList();

  bool isFitSaved(Iterable<String> ids) => _fits.any((f) => f.sameAs(ids));

  /// Saves a fit, or removes it if it's already saved. Returns whether it
  /// is saved now.
  bool toggleFit(List<String> ids) {
    final existing = _fits.indexWhere((f) => f.sameAs(ids));
    if (existing != -1) {
      _fits.removeAt(existing);
      _changed();
      return false;
    }
    _fits.insert(0, SavedFit(id: 'fit_${DateTime.now().microsecondsSinceEpoch}', itemIds: List.of(ids)));
    _changed();
    return true;
  }

  // ---------------------------------------------------------------- missing

  void markFound(String id) => moveToCloset(id);

  /// Permanently removes a garment that is gone for good.
  void markLost(String id) {
    _garments.removeWhere((g) => g.id == id);
    _changed();
  }

  // ----------------------------------------------------------------- backup

  /// Everything needed to restore the wardrobe. Images are added by the
  /// caller, because reading files is platform-specific.
  Map<String, dynamic> toBackup() => {
        'format': backupFormat,
        'version': backupVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'batchCounter': _batchCounter,
        'garments': _garments.map((g) => g.toJson()).toList(),
        'batches': _batches.map((b) => b.toJson()).toList(),
        'fits': _fits.map((f) => f.toJson()).toList(),
      };

  /// Replaces all data with a backup. Throws [FormatException] if the file
  /// isn't a FindMyFit backup, leaving the current data untouched.
  void restoreBackup(Map<String, dynamic> data) {
    if (data['format'] != backupFormat) {
      throw const FormatException('Not a FindMyFit backup');
    }
    final garments = (data['garments'] as List? ?? [])
        .map((e) => Garment.fromJson(e as Map<String, dynamic>))
        .toList();
    final batches = (data['batches'] as List? ?? [])
        .map((e) => LaundryBatch.fromJson(e as Map<String, dynamic>))
        .toList();
    // Backups from before Fit Shuffle have no fits.
    final fits = (data['fits'] as List? ?? [])
        .map((e) => SavedFit.fromJson(e as Map<String, dynamic>))
        .toList();
    _garments
      ..clear()
      ..addAll(garments);
    _batches
      ..clear()
      ..addAll(batches);
    _fits
      ..clear()
      ..addAll(fits);
    _batchCounter = data['batchCounter'] as int? ?? _batchCounter;
    _changed();
  }
}
