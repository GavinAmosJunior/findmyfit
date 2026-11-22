/// An outfit you liked in Fit Shuffle: one garment from each rail.
class SavedFit {
  final String id;
  final List<String> itemIds;
  final DateTime createdAt;

  /// Which of the board colors it wears (FitCollage.tints).
  final int tint;

  SavedFit({required this.id, required this.itemIds, DateTime? createdAt, int? tint})
      : createdAt = createdAt ?? DateTime.now(),
        // New fits get a color of their own, picked from their id.
        tint = tint ?? id.codeUnits.fold<int>(0, (a, b) => a + b) % 5;

  SavedFit withTint(int tint) => SavedFit(id: id, itemIds: itemIds, createdAt: createdAt, tint: tint);

  /// Same pieces, in any order.
  bool sameAs(Iterable<String> ids) {
    final other = ids.toSet();
    return other.length == itemIds.length && other.containsAll(itemIds);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemIds': itemIds,
        'createdAt': createdAt.toIso8601String(),
        'tint': tint,
      };

  factory SavedFit.fromJson(Map<String, dynamic> json) => SavedFit(
        id: json['id'] as String,
        itemIds: (json['itemIds'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        tint: json['tint'] as int?,
      );
}
