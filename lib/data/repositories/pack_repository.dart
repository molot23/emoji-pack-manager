import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/pack.dart';
import '../../domain/models/sticker.dart';
import '../database/app_database.dart';
import '../services/image_storage_service.dart';

class PackRepository {
  PackRepository({
    AppDatabase? database,
    ImageStorageService? storage,
  })  : _db = database ?? AppDatabase.instance,
        _storage = storage ?? ImageStorageService();

  final AppDatabase _db;
  final ImageStorageService _storage;
  static const _uuid = Uuid();

  Future<List<Pack>> getAllPacks() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT p.*, COUNT(s.id) AS sticker_count
      FROM packs p
      LEFT JOIN stickers s ON s.pack_id = p.id
      GROUP BY p.id
      ORDER BY p.updated_at DESC
    ''');
    return rows
        .map(
          (m) => Pack.fromMap(
            m,
            stickerCount: (m['sticker_count'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  Future<Pack?> getPack(String id) async {
    final db = await _db.database;
    final rows = await db.query('packs', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final count = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM stickers WHERE pack_id = ?',
            [id],
          ),
        ) ??
        0;
    return Pack.fromMap(rows.first, stickerCount: count);
  }

  Future<Pack> createPack(String name) async {
    final now = DateTime.now();
    final pack = Pack(
      id: _uuid.v4(),
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
    );
    final db = await _db.database;
    await db.insert('packs', pack.toMap());
    await _storage.packDir(pack.id);
    return pack;
  }

  Future<Pack> renamePack(String id, String newName) async {
    final db = await _db.database;
    final now = DateTime.now();
    await db.update(
      'packs',
      {
        'name': newName.trim(),
        'updated_at': now.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    final pack = await getPack(id);
    if (pack == null) {
      throw StateError('表情包不存在');
    }
    return pack;
  }

  Future<void> deletePack(String id) async {
    final db = await _db.database;
    final stickers = await getStickers(id);
    await db.delete('packs', where: 'id = ?', whereArgs: [id]);
    for (final s in stickers) {
      await _storage.deleteImage(s.relativePath);
    }
    await _storage.deletePackFolder(id);
  }

  Future<List<Sticker>> getStickers(String packId) async {
    final db = await _db.database;
    final rows = await db.query(
      'stickers',
      where: 'pack_id = ?',
      whereArgs: [packId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Sticker.fromMap).toList();
  }

  Future<Sticker> addStickerFromFile({
    required String packId,
    required File source,
  }) async {
    final saved = await _storage.saveImage(packId: packId, source: source);
    final sticker = Sticker(
      id: _uuid.v4(),
      packId: packId,
      fileName: saved.fileName,
      relativePath: saved.relativePath,
      createdAt: DateTime.now(),
    );
    final db = await _db.database;
    await db.insert('stickers', sticker.toMap());
    await db.update(
      'packs',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [packId],
    );
    return sticker;
  }

  Future<void> deleteSticker(Sticker sticker) async {
    final db = await _db.database;
    await db.delete('stickers', where: 'id = ?', whereArgs: [sticker.id]);
    await _storage.deleteImage(sticker.relativePath);
    await db.update(
      'packs',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [sticker.packId],
    );
  }

  Future<String> resolveAbsolutePath(String relativePath) {
    return _storage.absolutePath(relativePath);
  }
}
