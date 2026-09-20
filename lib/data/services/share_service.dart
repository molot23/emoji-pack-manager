import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

/// Shares a local sticker image via the Android system share sheet.
class ShareService {
  Future<void> shareImageFile(String absolutePath) async {
    final file = File(absolutePath);
    if (!await file.exists()) {
      throw StateError('图片文件不存在');
    }
    final mime = _mimeForPath(absolutePath);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(absolutePath, mimeType: mime)],
        subject: '分享表情',
      ),
    );
  }

  static String _mimeForPath(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      case '.png':
      default:
        return 'image/png';
    }
  }
}
