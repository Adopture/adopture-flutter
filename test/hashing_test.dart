import 'package:flutter_test/flutter_test.dart';

import 'package:adopture/src/hashing.dart';

void main() {
  group('Hashing', () {
    test('daily hash is 64 chars (SHA256 hex)', () {
      final hashing = Hashing(
        deviceId: 'test-device-id',
        appKey: 'ak_abcdefghijklmnopqrstuvwx',
      );

      final hash = hashing.dailyHash();
      expect(hash.length, 64);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(hash), true);
    });

    test('monthly hash is 64 chars', () {
      final hashing = Hashing(
        deviceId: 'test-device-id',
        appKey: 'ak_abcdefghijklmnopqrstuvwx',
      );

      final hash = hashing.monthlyHash();
      expect(hash.length, 64);
    });

    test('retention hash is 64 chars', () {
      final hashing = Hashing(
        deviceId: 'test-device-id',
        appKey: 'ak_abcdefghijklmnopqrstuvwx',
      );

      final hash = hashing.retentionHash();
      expect(hash.length, 64);
    });

    test('same device + same day = same daily hash', () {
      final h1 = Hashing(
        deviceId: 'device-1',
        appKey: 'ak_abcdefghijklmnopqrstuvwx',
      );
      final h2 = Hashing(
        deviceId: 'device-1',
        appKey: 'ak_abcdefghijklmnopqrstuvwx',
      );

      expect(h1.dailyHash(), h2.dailyHash());
    });

    test('different device IDs produce different hashes', () {
      final h1 = Hashing(
        deviceId: 'device-1',
        appKey: 'ak_abcdefghijklmnopqrstuvwx',
      );
      final h2 = Hashing(
        deviceId: 'device-2',
        appKey: 'ak_abcdefghijklmnopqrstuvwx',
      );

      expect(h1.dailyHash(), isNot(h2.dailyHash()));
    });

    test('different app keys produce different hashes', () {
      final h1 = Hashing(
        deviceId: 'device-1',
        appKey: 'ak_aaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final h2 = Hashing(
        deviceId: 'device-1',
        appKey: 'ak_bbbbbbbbbbbbbbbbbbbbbbbbbb',
      );

      expect(h1.dailyHash(), isNot(h2.dailyHash()));
    });

    test('daily and monthly hashes are different', () {
      final hashing = Hashing(
        deviceId: 'test-device',
        appKey: 'ak_abcdefghijklmnopqrstuvwx',
      );

      expect(hashing.dailyHash(), isNot(hashing.monthlyHash()));
    });

    test('caches hashes on repeated calls', () {
      final hashing = Hashing(
        deviceId: 'test-device',
        appKey: 'ak_abcdefghijklmnopqrstuvwx',
      );

      final first = hashing.dailyHash();
      final second = hashing.dailyHash();
      expect(identical(first, second), true);
    });

    test('raw device ID is not present in hash output', () {
      const deviceId = 'my-secret-device-id';
      final hashing = Hashing(
        deviceId: deviceId,
        appKey: 'ak_abcdefghijklmnopqrstuvwx',
      );

      expect(hashing.dailyHash().contains(deviceId), false);
      expect(hashing.monthlyHash().contains(deviceId), false);
      expect(hashing.retentionHash().contains(deviceId), false);
    });
  });
}
