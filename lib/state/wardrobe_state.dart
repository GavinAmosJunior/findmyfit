import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/garment.dart';
import '../models/laundry_batch.dart';

class WardrobeState extends ChangeNotifier {
  static const String _keyGarments = 'saved_garments_v1';
  static const String _keyBatches = 'saved_batches_v1';
  static const String _keyBatchCounter = 'saved_batch_counter_v1';

  final List<Garment> _garments = [];
  final List<LaundryBatch> _batches = [];
  int _batchCounter = 1000;
  bool _isLoaded = false;

  WardrobeState() {
    loadFromStorage();
  }

  bool get isLoaded => _isLoaded;
  List<Garment> get garments => List.unmodifiable(_garments);
  List<LaundryBatch> get batches => List.unmodifiable(_batches);

  List<LaundryBatch> get activeBatches =>
      _batches.where((b) => !b.isCompleted).toList();

  List<LaundryBatch> get completedBatches =>
      _batches.where((b) => b.isCompleted).toList();

  // Statistics
  int get totalGarments => _garments.length;
  int get closetCount =>
      _garments.where((g) => g.status == GarmentStatus.closet).length;
  int get hamperCount =>
      _garments.where((g) => g.status == GarmentStatus.dirtyHamper).length;
  int get laundryCount =>
      _garments.where((g) => g.status == GarmentStatus.inLaundry).length;
  int get missingCount =>
      _garments.where((g) => g.status == GarmentStatus.missing).length;

  double get closetPercent =>
      totalGarments == 0 ? 0 : (closetCount / totalGarments) * 100;
  double get hamperPercent =>
      totalGarments == 0 ? 0 : (hamperCount / totalGarments) * 100;
  double get laundryPercent =>
      totalGarments == 0 ? 0 : (laundryCount / totalGarments) * 100;
  double get missingPercent =>
      totalGarments == 0 ? 0 : (missingCount / totalGarments) * 100;

  // Persistence methods
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final garmentsJson = prefs.getString(_keyGarments);
      if (garmentsJson != null && garmentsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(garmentsJson);
        _garments.clear();
        _garments.addAll(
          decoded.map((item) => Garment.fromJson(item as Map<String, dynamic>)),
        );
      }

      final batchesJson = prefs.getString(_keyBatches);
      if (batchesJson != null && batchesJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(batchesJson);
        _batches.clear();
        _batches.addAll(
          decoded.map((item) => LaundryBatch.fromJson(item as Map<String, dynamic>)),
        );
      }

      _batchCounter = prefs.getInt(_keyBatchCounter) ?? 1000;
    } catch (e) {
      debugPrint('Error loading wardrobe storage: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final garmentsJson = jsonEncode(_garments.map((g) => g.toJson()).toList());
      await prefs.setString(_keyGarments, garmentsJson);

      final batchesJson = jsonEncode(_batches.map((b) => b.toJson()).toList());
      await prefs.setString(_keyBatches, batchesJson);

      await prefs.setInt(_keyBatchCounter, _batchCounter);
    } catch (e) {
      debugPrint('Error saving wardrobe storage: $e');
    }
  }

  // Garment Actions
  void addGarment({
    required String name,
    required GarmentCategory category,
    GarmentStatus initialStatus = GarmentStatus.closet,
    String? brand,
    String? fabricNotes,
    String? washNotes,
    String? imageUrl,
    int? fallbackColor,
  }) {
    final garment = Garment(
      id: 'g_${DateTime.now().millisecondsSinceEpoch}_${_garments.length}',
      name: name.trim().isEmpty ? 'Untitled Garment' : name.trim(),
      category: category,
      status: initialStatus,
      brand: brand?.trim().isEmpty == true ? null : brand?.trim(),
      fabricNotes: fabricNotes?.trim().isEmpty == true ? 'Everyday Fabric' : fabricNotes?.trim(),
      washNotes: washNotes?.trim().isEmpty == true ? 'Machine Wash Safe' : washNotes?.trim(),
      imageUrl: imageUrl,
      fallbackColor: fallbackColor ?? 0xFF0058BE,
    );
    _garments.insert(0, garment);
    notifyListeners();
    _saveToStorage();
  }

  void removeGarment(String id) {
    _garments.removeWhere((g) => g.id == id);
    for (final b in _batches) {
      b.itemIds.remove(id);
      b.verifiedItemIds.remove(id);
      b.flaggedMissingItemIds.remove(id);
    }
    notifyListeners();
    _saveToStorage();
  }

  void toggleFavorite(String id) {
    final index = _garments.indexWhere((g) => g.id == id);
    if (index != -1) {
      _garments[index].isFavorite = !_garments[index].isFavorite;
      notifyListeners();
      _saveToStorage();
    }
  }

  // Lifecycle Transitions
  void moveToHamper(String id) {
    final index = _garments.indexWhere((g) => g.id == id);
    if (index != -1) {
      _garments[index].status = GarmentStatus.dirtyHamper;
      _garments[index].currentBatchId = null;
      notifyListeners();
      _saveToStorage();
    }
  }

  void moveToCloset(String id) {
    final index = _garments.indexWhere((g) => g.id == id);
    if (index != -1) {
      _garments[index].status = GarmentStatus.closet;
      _garments[index].currentBatchId = null;
      notifyListeners();
      _saveToStorage();
    }
  }

  /// "Dump Hamper" - moves selected (or all) hamper items to Laundry batch
  LaundryBatch dumpHamperToLaundry({
    required String batchName,
    List<String>? selectedItemIds,
    String laundromatName = 'Sparkle Clean Laundromat',
  }) {
    final List<String> targetIds = selectedItemIds ??
        _garments
            .where((g) => g.status == GarmentStatus.dirtyHamper)
            .map((g) => g.id)
            .toList();

    _batchCounter++;
    final newBatch = LaundryBatch(
      id: 'batch_${DateTime.now().millisecondsSinceEpoch}',
      batchCode: '#L-$_batchCounter',
      name: batchName.trim().isEmpty ? 'Weekly Wash' : batchName.trim(),
      laundromatName: laundromatName,
      itemIds: List<String>.from(targetIds),
    );

    // Update garments
    for (final id in targetIds) {
      final index = _garments.indexWhere((g) => g.id == id);
      if (index != -1) {
        _garments[index].status = GarmentStatus.inLaundry;
        _garments[index].currentBatchId = newBatch.id;
      }
    }

    _batches.insert(0, newBatch);
    notifyListeners();
    _saveToStorage();
    return newBatch;
  }

  // Cross-check Checklist Actions
  void toggleBatchItemVerification(String batchId, String garmentId) {
    final batchIndex = _batches.indexWhere((b) => b.id == batchId);
    if (batchIndex == -1) return;

    final batch = _batches[batchIndex];
    if (batch.verifiedItemIds.contains(garmentId)) {
      batch.verifiedItemIds.remove(garmentId);
    } else {
      batch.verifiedItemIds.add(garmentId);
      batch.flaggedMissingItemIds.remove(garmentId);
    }
    notifyListeners();
    _saveToStorage();
  }

  void flagBatchItemMissing(String batchId, String garmentId) {
    final batchIndex = _batches.indexWhere((b) => b.id == batchId);
    if (batchIndex == -1) return;

    final batch = _batches[batchIndex];
    if (batch.flaggedMissingItemIds.contains(garmentId)) {
      batch.flaggedMissingItemIds.remove(garmentId);
    } else {
      batch.flaggedMissingItemIds.add(garmentId);
      batch.verifiedItemIds.remove(garmentId);
    }
    notifyListeners();
    _saveToStorage();
  }

  void verifyAllBatchItems(String batchId) {
    final batchIndex = _batches.indexWhere((b) => b.id == batchId);
    if (batchIndex == -1) return;

    final batch = _batches[batchIndex];
    batch.verifiedItemIds.clear();
    batch.verifiedItemIds.addAll(batch.itemIds);
    batch.flaggedMissingItemIds.clear();
    notifyListeners();
    _saveToStorage();
  }

  /// Finalize return from laundry:
  /// - Verified items go back to Closet (Clean)
  /// - Flagged or unverified items go to Missing (Lost & Found)
  void completeLaundryReturn(String batchId) {
    final batchIndex = _batches.indexWhere((b) => b.id == batchId);
    if (batchIndex == -1) return;

    final batch = _batches[batchIndex];

    for (final id in batch.itemIds) {
      final garmentIndex = _garments.indexWhere((g) => g.id == id);
      if (garmentIndex == -1) continue;

      if (batch.verifiedItemIds.contains(id)) {
        _garments[garmentIndex].status = GarmentStatus.closet;
        _garments[garmentIndex].currentBatchId = null;
      } else {
        _garments[garmentIndex].status = GarmentStatus.missing;
        _garments[garmentIndex].currentBatchId = null;
      }
    }

    batch.isCompleted = true;
    notifyListeners();
    _saveToStorage();
  }

  // Lost & Found Resolution
  void resolveMissingItem(String garmentId, {bool foundInCloset = true}) {
    final index = _garments.indexWhere((g) => g.id == garmentId);
    if (index != -1) {
      if (foundInCloset) {
        _garments[index].status = GarmentStatus.closet;
      } else {
        _garments.removeAt(index);
      }
      notifyListeners();
      _saveToStorage();
    }
  }

  void markAllMissingFound() {
    for (final g in _garments) {
      if (g.status == GarmentStatus.missing) {
        g.status = GarmentStatus.closet;
      }
    }
    notifyListeners();
    _saveToStorage();
  }
}
