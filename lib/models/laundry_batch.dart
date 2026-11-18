class LaundryBatch {
  final String id;
  final String batchCode; // e.g. #L-2849
  final String name;      // e.g. "Weekly Wash"
  final String laundromatName; // e.g. "Sparkle Clean Laundromat"
  final List<String> itemIds; // List of garment IDs
  final Set<String> verifiedItemIds;
  final Set<String> flaggedMissingItemIds;
  final DateTime createdAt;
  bool isCompleted;

  LaundryBatch({
    required this.id,
    required this.batchCode,
    required this.name,
    this.laundromatName = "Local Laundromat",
    required this.itemIds,
    Set<String>? verifiedItemIds,
    Set<String>? flaggedMissingItemIds,
    DateTime? createdAt,
    this.isCompleted = false,
  })  : verifiedItemIds = verifiedItemIds ?? <String>{},
        flaggedMissingItemIds = flaggedMissingItemIds ?? <String>{},
        createdAt = createdAt ?? DateTime.now();

  int get totalItems => itemIds.length;
  int get verifiedCount => verifiedItemIds.length;
  int get missingCount => flaggedMissingItemIds.length;
  int get pendingCount => totalItems - verifiedCount - missingCount;

  double get progress => totalItems == 0 ? 0 : verifiedCount / totalItems;

  bool isItemVerified(String garmentId) => verifiedItemIds.contains(garmentId);
  bool isItemMissing(String garmentId) => flaggedMissingItemIds.contains(garmentId);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batchCode': batchCode,
      'name': name,
      'laundromatName': laundromatName,
      'itemIds': itemIds,
      'verifiedItemIds': verifiedItemIds.toList(),
      'flaggedMissingItemIds': flaggedMissingItemIds.toList(),
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  factory LaundryBatch.fromJson(Map<String, dynamic> json) {
    return LaundryBatch(
      id: json['id'] as String,
      batchCode: json['batchCode'] as String? ?? '#L-1000',
      name: json['name'] as String? ?? 'Weekly Wash',
      laundromatName: json['laundromatName'] as String? ?? 'Local Laundromat',
      itemIds: (json['itemIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      verifiedItemIds: (json['verifiedItemIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          <String>{},
      flaggedMissingItemIds: (json['flaggedMissingItemIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          <String>{},
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  LaundryBatch copyWith({
    String? name,
    String? laundromatName,
    List<String>? itemIds,
    Set<String>? verifiedItemIds,
    Set<String>? flaggedMissingItemIds,
    bool? isCompleted,
  }) {
    return LaundryBatch(
      id: id,
      batchCode: batchCode,
      name: name ?? this.name,
      laundromatName: laundromatName ?? this.laundromatName,
      itemIds: itemIds ?? this.itemIds,
      verifiedItemIds: verifiedItemIds ?? Set<String>.from(this.verifiedItemIds),
      flaggedMissingItemIds: flaggedMissingItemIds ?? Set<String>.from(this.flaggedMissingItemIds),
      createdAt: createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
