import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Result of comparing the installed app with the latest GitHub release.
sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

class UpdateAvailable extends UpdateCheckResult {
  const UpdateAvailable({
    required this.latestTag,
    required this.releaseUrl,
    required this.notesSummary,
    required this.localVersion,
  });

  final String latestTag;
  final String releaseUrl;
  final String notesSummary;
  final String localVersion;
}

class AlreadyLatest extends UpdateCheckResult {
  const AlreadyLatest({
    required this.localVersion,
    required this.latestTag,
  });

  final String localVersion;
  final String latestTag;
}

class UpdateCheckError extends UpdateCheckResult {
  const UpdateCheckError(this.message);

  final String message;
}

class UpdateCheckService {
  UpdateCheckService({
    http.Client? client,
    this.owner = 'molot23',
    this.repo = 'emoji-pack-manager',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String owner;
  final String repo;

  static const fallbackReleaseUrl =
      'https://github.com/molot23/emoji-pack-manager/releases/latest';

  Uri get _latestApiUri => Uri.https(
        'api.github.com',
        '/repos/$owner/$repo/releases/latest',
      );

  Future<UpdateCheckResult> checkForUpdates() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final localVersionName = info.version;
      final localBuild = int.tryParse(info.buildNumber);

      final response = await _client
          .get(
            _latestApiUri,
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'emoji-pack-manager-android',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        return const UpdateCheckError('暂无发布版本，请稍后再试');
      }
      if (response.statusCode != 200) {
        return UpdateCheckError('检查更新失败（HTTP ${response.statusCode}）');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const UpdateCheckError('无法解析更新信息');
      }

      final tagName = (decoded['tag_name'] as String?)?.trim() ?? '';
      if (tagName.isEmpty) {
        return const UpdateCheckError('无法解析更新信息');
      }

      final htmlUrl = (decoded['html_url'] as String?)?.trim();
      final releaseUrl =
          (htmlUrl != null && htmlUrl.isNotEmpty) ? htmlUrl : fallbackReleaseUrl;

      final bodyText = (decoded['body'] as String?)?.trim() ?? '';
      final notesSummary = _summarizeNotes(bodyText, tagName);

      final remoteSemver = parseSemverPrefix(tagName);
      final localSemver = parseSemverPrefix(localVersionName);
      final localDisplay = localBuild == null
          ? localVersionName
          : '$localVersionName+$localBuild';

      final isNewer = isRemoteNewer(
        remoteSemver: remoteSemver,
        localSemver: localSemver,
      );

      if (isNewer) {
        return UpdateAvailable(
          latestTag: tagName,
          releaseUrl: releaseUrl,
          notesSummary: notesSummary,
          localVersion: localDisplay,
        );
      }

      return AlreadyLatest(
        localVersion: localDisplay,
        latestTag: tagName,
      );
    } on FormatException {
      return const UpdateCheckError('无法解析更新信息');
    } catch (_) {
      return const UpdateCheckError('网络错误，请检查网络后重试');
    }
  }

  /// Strips a leading `v`/`V` and returns leading `major.minor.patch`.
  /// Examples: `v0.1.0-android-local` → (0,1,0); `0.2.0` → (0,2,0).
  static (int, int, int)? parseSemverPrefix(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1);
    }
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(s);
    if (match == null) return null;
    return (
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static int compareSemver((int, int, int) a, (int, int, int) b) {
    if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
    if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
    return a.$3.compareTo(b.$3);
  }

  /// Compare remote tag semver vs local pubspec versionName.
  /// Pre-release suffixes on the tag (e.g. `-android-local`) are ignored after
  /// extracting major.minor.patch. Equal semver ⇒ already latest.
  static bool isRemoteNewer({
    required (int, int, int)? remoteSemver,
    required (int, int, int)? localSemver,
  }) {
    if (remoteSemver != null && localSemver != null) {
      return compareSemver(remoteSemver, localSemver) > 0;
    }
    // Remote parsed, local did not — treat as update available.
    if (remoteSemver != null && localSemver == null) {
      return true;
    }
    return false;
  }

  static String _summarizeNotes(String body, String tagName) {
    if (body.isEmpty) return '版本 $tagName';
    final lines = body
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(6)
        .toList();
    if (lines.isEmpty) return '版本 $tagName';
    var summary = lines.join('\n');
    if (summary.length > 280) {
      summary = '${summary.substring(0, 277)}...';
    }
    return summary;
  }
}
