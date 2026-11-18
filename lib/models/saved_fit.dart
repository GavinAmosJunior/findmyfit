/// An outfit you liked in Fit Shuffle: one garment from each rail.
class SavedFit {
  final String id;
  final List<String> itemIds;
  final DateTime createdAt;

  SavedFit({required this.id, required this.itemIds, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  /// Same pieces, in any order.
  bool sameAs(Iterable<String> ids) {
    final other = ids.toSet();
    return other.length == itemIds.length && other.containsAll(itemIds);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemIds': itemIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedFit.fromJson(Map<String, dynamic> json) => SavedFit(
        id: json['id'] as String,
        itemIds: (json['itemIds'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );
}
