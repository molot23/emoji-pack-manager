import 'tag.dart';

class Sticker {
  final String id;
  final String fileName;
  final String relativePath;
  final DateTime createdAt;
  final List<Tag> tags;

  const Sticker({
    required this.id,
    required this.fileName,
    required this.relativePath,
    required this.createdAt,
    this.tags = const [],
  });

  Sticker copyWith({
    String? id,
    String? fileName,
    String? relativePath,
    DateTime? createdAt,
    List<Tag>? tags,
  }) {
    return Sticker(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      relativePath: relativePath ?? this.relativePath,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'file_name': fileName,
      'relative_path': relativePath,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Sticker.fromMap(Map<String, Object?> map, {List<Tag> tags = const []}) {
    return Sticker(
      id: map['id'] as String,
      fileName: map['file_name'] as String,
      relativePath: map['relative_path'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      tags: tags,
    );
  }
}

/// Sort options for the album grid.
enum StickerSort {
  newest,
  oldest,
  nameAsc,
}

extension StickerSortLabel on StickerSort {
  String get label {
    switch (this) {
      case StickerSort.newest:
        return '最新优先';
      case StickerSort.oldest:
        return '最旧优先';
      case StickerSort.nameAsc:
        return '按文件名';
    }
  }
}
