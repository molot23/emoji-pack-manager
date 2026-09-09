class Pack {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int stickerCount;

  const Pack({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.stickerCount = 0,
  });

  Pack copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? stickerCount,
  }) {
    return Pack(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stickerCount: stickerCount ?? this.stickerCount,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Pack.fromMap(Map<String, Object?> map, {int stickerCount = 0}) {
    return Pack(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      stickerCount: stickerCount,
    );
  }
}
