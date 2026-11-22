enum GarmentCategory {
  tops,
  bottoms,
  outerwear,
  delicates,
  shoes,
  hats,
  bags,
  accessories,
  watches;

  /// Clothes you wash: wearing them sends them to the hamper. Shoes, hats,
  /// bags, accessories and watches just count the wear.
  bool get goesToHamper => index <= delicates.index;

  /// Where a piece sits in the wardrobe drawing: watches share the
  /// accessories cubby.
  GarmentCategory get compartment => this == watches ? accessories : this;

  /// What Fit Shuffle hangs on the top rail.
  bool get isUpper => this == tops || this == outerwear || this == delicates;

  static GarmentCategory fromString(String? val) {
    return GarmentCategory.values.firstWhere(
      (e) => e.name == val,
      orElse: () => GarmentCategory.tops,
    );
  }
}

enum GarmentStatus {
  closet, // Clean, in the closet
  dirtyHamper, // Worn, waiting in the hamper
  inLaundry, // Sent out to the laundromat
  missing, // Didn't come back from the laundromat
  lost; // Gave up looking: kept, out of the closet, can come back

  static GarmentStatus fromString(String? val) {
    return GarmentStatus.values.firstWhere(
      (e) => e.name == val,
      orElse: () => GarmentStatus.closet,
    );
  }
}

class Garment {
  final String id;
  final String name;
  final GarmentCategory category;
  GarmentStatus status;
  final String? brand;
  final String? notes;
  final String? imageUrl;
  final int? fallbackColor;
  bool isFavorite;

  /// The laundry batch this garment is in, or went missing from.
  String? currentBatchId;
  final DateTime dateAdded;
  int wearCount;
  DateTime? lastWornAt;

  Garment({
    required this.id,
    required this.name,
    required this.category,
    this.status = GarmentStatus.closet,
    this.brand,
    this.notes,
    this.imageUrl,
    this.fallbackColor,
    this.isFavorite = false,
    this.currentBatchId,
    DateTime? dateAdded,
    this.wearCount = 0,
    this.lastWornAt,
  }) : dateAdded = dateAdded ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'status': status.name,
      'brand': brand,
      'notes': notes,
      'imageUrl': imageUrl,
      'fallbackColor': fallbackColor,
      'isFavorite': isFavorite,
      'currentBatchId': currentBatchId,
      'dateAdded': dateAdded.toIso8601String(),
      'wearCount': wearCount,
      'lastWornAt': lastWornAt?.toIso8601String(),
    };
  }

  factory Garment.fromJson(Map<String, dynamic> json) {
    // Older saves kept fabric and wash notes in separate fields.
    final legacyNotes = [json['fabricNotes'], json['washNotes']]
        .whereType<String>()
        .where((s) => s.isNotEmpty && s != 'Everyday Fabric' && s != 'Machine Wash Safe')
        .join(' · ');
    return Garment(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled',
      category: GarmentCategory.fromString(json['category'] as String?),
      status: GarmentStatus.fromString(json['status'] as String?),
      brand: json['brand'] as String?,
      notes: json['notes'] as String? ?? (legacyNotes.isEmpty ? null : legacyNotes),
      imageUrl: json['imageUrl'] as String?,
      fallbackColor: json['fallbackColor'] as int?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      currentBatchId: json['currentBatchId'] as String?,
      dateAdded: DateTime.tryParse(json['dateAdded'] as String? ?? ''),
      wearCount: json['wearCount'] as int? ?? 0,
      lastWornAt: DateTime.tryParse(json['lastWornAt'] as String? ?? ''),
    );
  }

  /// Returns a copy with the given fields replaced. Nullable text fields are
  /// passed as-is (including null), so an edit can clear them.
  Garment edited({
    required String name,
    required GarmentCategory category,
    required String? brand,
    required String? notes,
    required String? imageUrl,
  }) {
    return Garment(
      id: id,
      name: name,
      category: category,
      status: status,
      brand: brand,
      notes: notes,
      imageUrl: imageUrl,
      fallbackColor: fallbackColor,
      isFavorite: isFavorite,
      currentBatchId: currentBatchId,
      dateAdded: dateAdded,
      wearCount: wearCount,
      lastWornAt: lastWornAt,
    );
  }
}
