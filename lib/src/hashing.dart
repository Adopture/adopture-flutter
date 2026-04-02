import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Generates privacy-preserving hashed identifiers.
///
/// Produces daily, monthly, and retention hashes using SHA256
/// with rotating date-based salts. The raw device ID never
/// leaves the device.
class Hashing {
  final String _deviceId;
  final String _appKey;

  String? _cachedDailyHash;
  String? _cachedMonthlyHash;
  String? _cachedRetentionHash;
  String? _lastDailySalt;
  String? _lastMonthlySalt;
  String? _lastRetentionSalt;

  Hashing({required String deviceId, required String appKey})
    : _deviceId = deviceId,
      _appKey = appKey;

  /// SHA256(device_id + app_key + YYYY-MM-DD) for DAU counting.
  String dailyHash() {
    final salt = _dailySalt();
    if (salt == _lastDailySalt && _cachedDailyHash != null) {
      return _cachedDailyHash!;
    }
    _lastDailySalt = salt;
    _cachedDailyHash = _hash(salt);
    return _cachedDailyHash!;
  }

  /// SHA256(device_id + app_key + YYYY-MM) for MAU + retention.
  String monthlyHash() {
    final salt = _monthlySalt();
    if (salt == _lastMonthlySalt && _cachedMonthlyHash != null) {
      return _cachedMonthlyHash!;
    }
    _lastMonthlySalt = salt;
    _cachedMonthlyHash = _hash(salt);
    return _cachedMonthlyHash!;
  }

  /// SHA256(device_id + app_key + YYYY-QN) for 90-day retention buckets.
  String retentionHash() {
    final salt = _retentionSalt();
    if (salt == _lastRetentionSalt && _cachedRetentionHash != null) {
      return _cachedRetentionHash!;
    }
    _lastRetentionSalt = salt;
    _cachedRetentionHash = _hash(salt);
    return _cachedRetentionHash!;
  }

  String _hash(String salt) {
    final input = '$_deviceId$_appKey$salt';
    return sha256.convert(utf8.encode(input)).toString();
  }

  String _dailySalt() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
  }

  String _monthlySalt() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${_pad(now.month)}';
  }

  String _retentionSalt() {
    final now = DateTime.now().toUtc();
    final quarter = ((now.month - 1) ~/ 3) + 1;
    return '${now.year}-Q$quarter';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
