import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageStorageService {
  static const _uuid = Uuid();

  Future<Directory> _rootDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, 'stickers'));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<Directory> packDir(String packId) async {
    final root = await _rootDir();
    final dir = Directory(p.join(root.path, packId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copy source image into pack folder. Returns relative path under docs/stickers.
  Future<({String relativePath, String fileName})> saveImage({
    required String packId,
    required File source,
  }) async {
    final dir = await packDir(packId);
    final ext = p.extension(source.path).toLowerCase();
    final safeExt = ext.isEmpty ? '.png' : ext;
    final fileName = '${_uuid.v4()}$safeExt';
    final dest = File(p.join(dir.path, fileName));
    await source.copy(dest.path);
    final relativePath = p.join(packId, fileName);
    return (relativePath: relativePath, fileName: fileName);
  }

  Future<String> absolutePath(String relativePath) async {
    final root = await _rootDir();
    return p.join(root.path, relativePath);
  }

  Future<void> deleteImage(String relativePath) async {
    final abs = await absolutePath(relativePath);
    final file = File(abs);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deletePackFolder(String packId) async {
    final root = await _rootDir();
    final dir = Directory(p.join(root.path, packId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
