enum GarmentCategory {
  tops,
  bottoms,
  outerwear,
  delicates;

  String get displayName {
    switch (this) {
      case GarmentCategory.tops:
        return 'Tops';
      case GarmentCategory.bottoms:
        return 'Bottoms';
      case GarmentCategory.outerwear:
        return 'Outerwear';
      case GarmentCategory.delicates:
        return 'Delicates';
    }
  }

  static GarmentCategory fromString(String? val) {
    return GarmentCategory.values.firstWhere(
      (e) => e.name == val,
      orElse: () => GarmentCategory.tops,
    );
  }
}

enum GarmentStatus {
  closet,      // In Closet (Clean)
  dirtyHamper, // In Dirty Hamper (Dirty Bin)
  inLaundry,   // Dumped to laundry / washing
  missing;     // Flagged as missing after return cross-check

  String get displayName {
    switch (this) {
      case GarmentStatus.closet:
        return 'In Closet (Clean)';
      case GarmentStatus.dirtyHamper:
        return 'In Hamper (Dirty)';
      case GarmentStatus.inLaundry:
        return 'At Laundry';
      case GarmentStatus.missing:
        return 'Missing';
    }
  }

  String get shortName {
    switch (this) {
      case GarmentStatus.closet:
        return 'In Closet';
      case GarmentStatus.dirtyHamper:
        return 'In Hamper';
      case GarmentStatus.inLaundry:
        return 'At Laundry';
      case GarmentStatus.missing:
        return 'Missing';
    }
  }

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
  final String? fabricNotes;
  final String? washNotes;
  final String? imageUrl;
  final int? fallbackColor;
  bool isFavorite;
  String? currentBatchId;
  DateTime dateAdded;

  Garment({
    required this.id,
    required this.name,
    required this.category,
    this.status = GarmentStatus.closet,
    this.brand,
    this.fabricNotes,
    this.washNotes,
    this.imageUrl,
    this.fallbackColor,
    this.isFavorite = false,
    this.currentBatchId,
    DateTime? dateAdded,
  }) : dateAdded = dateAdded ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'status': status.name,
      'brand': brand,
      'fabricNotes': fabricNotes,
      'washNotes': washNotes,
      'imageUrl': imageUrl,
      'fallbackColor': fallbackColor,
      'isFavorite': isFavorite,
      'currentBatchId': currentBatchId,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  factory Garment.fromJson(Map<String, dynamic> json) {
    return Garment(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled Garment',
      category: GarmentCategory.fromString(json['category'] as String?),
      status: GarmentStatus.fromString(json['status'] as String?),
      brand: json['brand'] as String?,
      fabricNotes: json['fabricNotes'] as String?,
      washNotes: json['washNotes'] as String?,
      imageUrl: json['imageUrl'] as String?,
      fallbackColor: json['fallbackColor'] as int?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      currentBatchId: json['currentBatchId'] as String?,
      dateAdded: json['dateAdded'] != null
          ? DateTime.tryParse(json['dateAdded'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Garment copyWith({
    String? name,
    GarmentCategory? category,
    GarmentStatus? status,
    String? brand,
    String? fabricNotes,
    String? washNotes,
    String? imageUrl,
    int? fallbackColor,
    bool? isFavorite,
    String? currentBatchId,
  }) {
    return Garment(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      status: status ?? this.status,
      brand: brand ?? this.brand,
      fabricNotes: fabricNotes ?? this.fabricNotes,
      washNotes: washNotes ?? this.washNotes,
      imageUrl: imageUrl ?? this.imageUrl,
      fallbackColor: fallbackColor ?? this.fallbackColor,
      isFavorite: isFavorite ?? this.isFavorite,
      currentBatchId: currentBatchId ?? this.currentBatchId,
      dateAdded: dateAdded,
    );
  }
}
