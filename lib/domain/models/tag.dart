class Tag {
  final String id;
  final String name;
  final DateTime createdAt;
  final int stickerCount;

  const Tag({
    required this.id,
    required this.name,
    required this.createdAt,
    this.stickerCount = 0,
  });

  Tag copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    int? stickerCount,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      stickerCount: stickerCount ?? this.stickerCount,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Tag.fromMap(Map<String, Object?> map, {int stickerCount = 0}) {
    return Tag(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      stickerCount: stickerCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Tag && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
