import 'package:emoji_pack_manager/data/services/update_check_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSemverPrefix', () {
    test('strips v and suffix', () {
      expect(
        UpdateCheckService.parseSemverPrefix('v0.1.0-android-local'),
        (0, 1, 0),
      );
    });

    test('plain semver', () {
      expect(UpdateCheckService.parseSemverPrefix('0.2.0'), (0, 2, 0));
    });

    test('rejects garbage', () {
      expect(UpdateCheckService.parseSemverPrefix('latest'), isNull);
    });
  });

  group('isRemoteNewer', () {
    test('0.2.0 newer than 0.1.0', () {
      expect(
        UpdateCheckService.isRemoteNewer(
          remoteSemver: (0, 2, 0),
          localSemver: (0, 1, 0),
        ),
        isTrue,
      );
    });

    test('equal is not newer', () {
      expect(
        UpdateCheckService.isRemoteNewer(
          remoteSemver: (0, 1, 1),
          localSemver: (0, 1, 1),
        ),
        isFalse,
      );
    });

    test('older remote is not newer', () {
      expect(
        UpdateCheckService.isRemoteNewer(
          remoteSemver: (0, 1, 0),
          localSemver: (0, 1, 1),
        ),
        isFalse,
      );
    });
  });
}
