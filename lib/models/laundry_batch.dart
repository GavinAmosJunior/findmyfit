/// One load of laundry: everything dropped off together (say, a full bin).
/// Loads are numbered automatically; a nickname and the laundromat are
/// optional.
class LaundryBatch {
  final String id;
  final String batchCode; // e.g. #L-1001

  /// Where it went. Empty when not set.
  String laundromatName;

  /// Optional name, like "Bedsheets". Null when not set.
  String? nickname;
  final List<String> itemIds;
  final Set<String> verifiedItemIds;
  final DateTime createdAt;
  bool isCompleted;
  DateTime? completedAt;

  LaundryBatch({
    required this.id,
    required this.batchCode,
    required this.laundromatName,
    required this.itemIds,
    this.nickname,
    Set<String>? verifiedItemIds,
    DateTime? createdAt,
    this.isCompleted = false,
    this.completedAt,
  })  : verifiedItemIds = verifiedItemIds ?? <String>{},
        createdAt = createdAt ?? DateTime.now();

  /// The load number people see: #L-1003 is load 3.
  int get number {
    final n = int.tryParse(batchCode.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return n > 1000 ? n - 1000 : n;
  }

  bool get hasNickname => nickname != null && nickname!.trim().isNotEmpty;

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
      if (hasNickname) 'nickname': nickname,
      'itemIds': itemIds,
      'verifiedItemIds': verifiedItemIds.toList(),
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory LaundryBatch.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [];
    return LaundryBatch(
      id: json['id'] as String,
      batchCode: json['batchCode'] as String? ?? '#L-1000',
      laundromatName: (json['laundromatName'] as String?)?.trim() ?? '',
      nickname: json['nickname'] as String?,
      itemIds: strings(json['itemIds']),
      verifiedItemIds: strings(json['verifiedItemIds']).toSet(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
    );
  }
}
