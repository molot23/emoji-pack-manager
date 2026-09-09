class Sticker {
  final String id;
  final String packId;
  final String fileName;
  final String relativePath;
  final DateTime createdAt;

  const Sticker({
    required this.id,
    required this.packId,
    required this.fileName,
    required this.relativePath,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'pack_id': packId,
      'file_name': fileName,
      'relative_path': relativePath,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Sticker.fromMap(Map<String, Object?> map) {
    return Sticker(
      id: map['id'] as String,
      packId: map['pack_id'] as String,
      fileName: map['file_name'] as String,
      relativePath: map['relative_path'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
