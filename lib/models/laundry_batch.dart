class LaundryBatch {
  final String id;
  final String batchCode; // e.g. #L-1001
  final String laundromatName;
  final List<String> itemIds;
  final Set<String> verifiedItemIds;
  final DateTime createdAt;
  final DateTime? pickupDate;
  bool isCompleted;
  DateTime? completedAt;

  LaundryBatch({
    required this.id,
    required this.batchCode,
    required this.laundromatName,
    required this.itemIds,
    Set<String>? verifiedItemIds,
    DateTime? createdAt,
    this.pickupDate,
    this.isCompleted = false,
    this.completedAt,
  })  : verifiedItemIds = verifiedItemIds ?? <String>{},
        createdAt = createdAt ?? DateTime.now();

  int get totalItems => itemIds.length;
  int get verifiedCount => verifiedItemIds.length;
  int get notBackCount => totalItems - verifiedCount;
  double get progress => totalItems == 0 ? 0 : verifiedCount / totalItems;

  bool isItemVerified(String garmentId) => verifiedItemIds.contains(garmentId);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batchCode': batchCode,
      'laundromatName': laundromatName,
      'itemIds': itemIds,
      'verifiedItemIds': verifiedItemIds.toList(),
      'createdAt': createdAt.toIso8601String(),
      'pickupDate': pickupDate?.toIso8601String(),
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory LaundryBatch.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [];
    return LaundryBatch(
      id: json['id'] as String,
      batchCode: json['batchCode'] as String? ?? '#L-1000',
      laundromatName: (json['laundromatName'] as String?)?.trim().isNotEmpty == true
          ? json['laundromatName'] as String
          : 'Laundromat',
      itemIds: strings(json['itemIds']),
      verifiedItemIds: strings(json['verifiedItemIds']).toSet(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      pickupDate: DateTime.tryParse(json['pickupDate'] as String? ?? ''),
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
    );
  }
}
