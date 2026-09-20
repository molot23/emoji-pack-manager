import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/sticker.dart';
import '../../domain/models/tag.dart';
import '../database/app_database.dart';
import '../services/image_storage_service.dart';

class StickerRepository {
  StickerRepository({
    AppDatabase? database,
    ImageStorageService? storage,
  })  : _db = database ?? AppDatabase.instance,
        _storage = storage ?? ImageStorageService();

  final AppDatabase _db;
  final ImageStorageService _storage;
  static const _uuid = Uuid();

  Future<List<Sticker>> getStickers({
    Set<String> tagIds = const {},
    StickerSort sort = StickerSort.newest,
    bool untaggedOnly = false,
  }) async {
    final db = await _db.database;
    final orderBy = switch (sort) {
      StickerSort.newest => 's.created_at DESC',
      StickerSort.oldest => 's.created_at ASC',
      StickerSort.nameAsc => 's.file_name COLLATE NOCASE ASC',
    };

    List<Map<String, Object?>> rows;
    if (untaggedOnly) {
      rows = await db.rawQuery('''
        SELECT s.*
        FROM stickers s
        WHERE s.id NOT IN (SELECT DISTINCT sticker_id FROM sticker_tags)
        ORDER BY $orderBy
      ''');
    } else if (tagIds.isEmpty) {
      rows = await db.rawQuery('''
        SELECT s.*
        FROM stickers s
        ORDER BY $orderBy
      ''');
    } else {
      final placeholders = List.filled(tagIds.length, '?').join(',');
      rows = await db.rawQuery(
        '''
        SELECT s.*
        FROM stickers s
        WHERE s.id IN (
          SELECT sticker_id
          FROM sticker_tags
          WHERE tag_id IN ($placeholders)
          GROUP BY sticker_id
          HAVING COUNT(DISTINCT tag_id) = ?
        )
        ORDER BY $orderBy
        ''',
        [...tagIds, tagIds.length],
      );
    }

    if (rows.isEmpty) return [];

    final ids = rows.map((r) => r['id'] as String).toList();
    final tagsBySticker = await _loadTagsForStickers(db, ids);

    return rows
        .map(
          (m) => Sticker.fromMap(
            m,
            tags: tagsBySticker[m['id'] as String] ?? const [],
          ),
        )
        .toList();
  }

  Future<Map<String, List<Tag>>> _loadTagsForStickers(
    Database db,
    List<String> stickerIds,
  ) async {
    if (stickerIds.isEmpty) return {};
    final placeholders = List.filled(stickerIds.length, '?').join(',');
    final rows = await db.rawQuery(
      '''
      SELECT st.sticker_id, t.id, t.name, t.created_at
      FROM sticker_tags st
      INNER JOIN tags t ON t.id = st.tag_id
      WHERE st.sticker_id IN ($placeholders)
      ORDER BY t.name COLLATE NOCASE ASC
      ''',
      stickerIds,
    );
    final map = <String, List<Tag>>{};
    for (final row in rows) {
      final sid = row['sticker_id'] as String;
      map.putIfAbsent(sid, () => []).add(
            Tag(
              id: row['id'] as String,
              name: row['name'] as String,
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
            ),
          );
    }
    return map;
  }

  Future<Sticker?> getSticker(String id) async {
    final db = await _db.database;
    final rows = await db.query('stickers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final tags = await _loadTagsForStickers(db, [id]);
    return Sticker.fromMap(rows.first, tags: tags[id] ?? const []);
  }

  Future<Sticker> addStickerFromFile({
    required File source,
    List<String> tagNames = const [],
  }) async {
    final saved = await _storage.saveImage(source: source);
    final sticker = Sticker(
      id: _uuid.v4(),
      fileName: saved.fileName,
      relativePath: saved.relativePath,
      createdAt: DateTime.now(),
    );
    final db = await _db.database;
    await db.insert('stickers', sticker.toMap());

    final tags = <Tag>[];
    for (final raw in tagNames) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final tag = await getOrCreateTag(name);
      await db.insert(
        'sticker_tags',
        {'sticker_id': sticker.id, 'tag_id': tag.id},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      tags.add(tag);
    }
    return sticker.copyWith(tags: tags);
  }

  Future<void> deleteSticker(Sticker sticker) async {
    final db = await _db.database;
    await db.delete('stickers', where: 'id = ?', whereArgs: [sticker.id]);
    await _storage.deleteImage(sticker.relativePath);
  }

  Future<List<Tag>> getAllTags() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT t.*, COUNT(st.sticker_id) AS sticker_count
      FROM tags t
      LEFT JOIN sticker_tags st ON st.tag_id = t.id
      GROUP BY t.id
      ORDER BY t.name COLLATE NOCASE ASC
    ''');
    return rows
        .map(
          (m) => Tag.fromMap(
            m,
            stickerCount: (m['sticker_count'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  Future<Tag> getOrCreateTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('标签名不能为空');
    }
    final db = await _db.database;
    final existing = await db.query(
      'tags',
      where: 'name = ?',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return Tag.fromMap(existing.first);
    }
    final tag = Tag(
      id: _uuid.v4(),
      name: trimmed,
      createdAt: DateTime.now(),
    );
    await db.insert('tags', tag.toMap());
    return tag;
  }

  /// Replace all tags on a sticker with [tagNames] (creates missing tags).
  Future<Sticker> setStickerTags(String stickerId, List<String> tagNames) async {
    final db = await _db.database;
    await db.delete(
      'sticker_tags',
      where: 'sticker_id = ?',
      whereArgs: [stickerId],
    );
    final unique = <String>{};
    for (final raw in tagNames) {
      final name = raw.trim();
      if (name.isEmpty || !unique.add(name)) continue;
      final tag = await getOrCreateTag(name);
      await db.insert(
        'sticker_tags',
        {'sticker_id': stickerId, 'tag_id': tag.id},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    // Clean unused tags (optional hygiene).
    await db.rawDelete('''
      DELETE FROM tags
      WHERE id NOT IN (SELECT DISTINCT tag_id FROM sticker_tags)
    ''');
    final sticker = await getSticker(stickerId);
    if (sticker == null) {
      throw StateError('贴纸不存在');
    }
    return sticker;
  }

  /// Add tags to multiple stickers without removing existing ones.
  Future<void> addTagsToStickers(
    List<String> stickerIds,
    List<String> tagNames,
  ) async {
    if (stickerIds.isEmpty) return;
    final uniqueNames = <String>{};
    final tags = <Tag>[];
    for (final raw in tagNames) {
      final name = raw.trim();
      if (name.isEmpty || !uniqueNames.add(name)) continue;
      tags.add(await getOrCreateTag(name));
    }
    if (tags.isEmpty) return;
    final db = await _db.database;
    for (final stickerId in stickerIds) {
      for (final tag in tags) {
        await db.insert(
          'sticker_tags',
          {'sticker_id': stickerId, 'tag_id': tag.id},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  Future<void> deleteTag(String tagId) async {
    final db = await _db.database;
    await db.delete('tags', where: 'id = ?', whereArgs: [tagId]);
  }

  Future<String> resolveAbsolutePath(String relativePath) {
    return _storage.absolutePath(relativePath);
  }
}
