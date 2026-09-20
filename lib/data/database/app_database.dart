import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  static const _uuid = Uuid();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'emoji_pack_manager.db');
    return openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await _createV2Schema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateV1ToV2(db);
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createV2Schema(Database db) async {
    await db.execute('''
      CREATE TABLE stickers (
        id TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        relative_path TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sticker_tags (
        sticker_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (sticker_id, tag_id),
        FOREIGN KEY (sticker_id) REFERENCES stickers (id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_sticker_tags_tag_id ON sticker_tags(tag_id)',
    );
    await db.execute(
      'CREATE INDEX idx_stickers_created_at ON stickers(created_at)',
    );
  }

  /// Flatten packs into tags: each sticker keeps its file; pack name becomes
  /// an initial tag when possible.
  Future<void> _migrateV1ToV2(Database db) async {
    // Avoid CASCADE wiping junction rows while we rebuild stickers.
    await db.execute('PRAGMA foreign_keys = OFF');

    final oldStickers = await db.rawQuery('''
      SELECT s.id, s.file_name, s.relative_path, s.created_at,
             p.name AS pack_name
      FROM stickers s
      LEFT JOIN packs p ON p.id = s.pack_id
    ''');

    await db.execute('''
      CREATE TABLE stickers_v2 (
        id TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        relative_path TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      )
    ''');
    // Temp junction without FK so DROP old stickers cannot cascade.
    await db.execute('''
      CREATE TABLE sticker_tags_mig (
        sticker_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (sticker_id, tag_id)
      )
    ''');

    final tagIdByName = <String, String>{};
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final row in oldStickers) {
      final stickerId = row['id'] as String;
      final fileName = row['file_name'] as String;
      final relativePath = row['relative_path'] as String;
      final createdAt = row['created_at'] as int;
      final packName = (row['pack_name'] as String?)?.trim();

      await db.insert('stickers_v2', {
        'id': stickerId,
        'file_name': fileName,
        'relative_path': relativePath,
        'created_at': createdAt,
      });

      if (packName != null && packName.isNotEmpty) {
        var tagId = tagIdByName[packName];
        if (tagId == null) {
          final existing = await db.query(
            'tags',
            where: 'name = ?',
            whereArgs: [packName],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            tagId = existing.first['id'] as String;
          } else {
            tagId = _uuid.v4();
            await db.insert('tags', {
              'id': tagId,
              'name': packName,
              'created_at': now,
            });
          }
          tagIdByName[packName] = tagId;
        }
        await db.insert(
          'sticker_tags_mig',
          {'sticker_id': stickerId, 'tag_id': tagId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    await db.execute('DROP TABLE IF EXISTS stickers');
    await db.execute('ALTER TABLE stickers_v2 RENAME TO stickers');
    await db.execute('DROP TABLE IF EXISTS packs');
    await db.execute('DROP TABLE IF EXISTS sticker_tags');

    await db.execute('''
      CREATE TABLE sticker_tags (
        sticker_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (sticker_id, tag_id),
        FOREIGN KEY (sticker_id) REFERENCES stickers (id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      INSERT INTO sticker_tags (sticker_id, tag_id)
      SELECT sticker_id, tag_id FROM sticker_tags_mig
    ''');
    await db.execute('DROP TABLE sticker_tags_mig');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sticker_tags_tag_id ON sticker_tags(tag_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stickers_created_at ON stickers(created_at)',
    );

    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
