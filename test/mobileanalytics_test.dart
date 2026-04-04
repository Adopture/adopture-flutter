import 'package:flutter_test/flutter_test.dart';

import 'package:adopture/adopture.dart';

void main() {
  group('AdoptureConfig', () {
    test('validates correct appKey format', () {
      const config = AdoptureConfig(appKey: 'ak_abcdefghijklmnopqrstuvwx');
      expect(() => config.validate(), returnsNormally);
    });

    test('rejects invalid appKey format', () {
      const config = AdoptureConfig(appKey: 'invalid_key');
      expect(() => config.validate(), throwsArgumentError);
    });

    test('rejects appKey without ak_ prefix', () {
      const config = AdoptureConfig(appKey: 'xx_abcdefghijklmnopqrstuvwx');
      expect(() => config.validate(), throwsArgumentError);
    });

    test('rejects appKey with wrong length', () {
      const config = AdoptureConfig(appKey: 'ak_tooshort');
      expect(() => config.validate(), throwsArgumentError);
    });

    test('rejects flushAt out of range', () {
      const config = AdoptureConfig(
        appKey: 'ak_abcdefghijklmnopqrstuvwx',
        flushAt: 0,
      );
      expect(() => config.validate(), throwsArgumentError);
    });

    test('rejects flushAt over 100', () {
      const config = AdoptureConfig(
        appKey: 'ak_abcdefghijklmnopqrstuvwx',
        flushAt: 101,
      );
      expect(() => config.validate(), throwsArgumentError);
    });

    test('uses correct defaults', () {
      const config = AdoptureConfig(appKey: 'ak_abcdefghijklmnopqrstuvwx');
      expect(config.debug, false);
      expect(config.autoCapture, true);
      expect(config.flushInterval, const Duration(seconds: 30));
      expect(config.flushAt, 20);
      expect(config.maxQueueSize, 1000);
      expect(config.sdkVersion, '0.1.0');
    });
  });

  group('AnalyticsEvent', () {
    test('serializes to JSON matching backend schema', () {
      const context = EventContext(
        os: 'iOS',
        osVersion: '18.3',
        appVersion: '1.0.0',
        locale: 'de_DE',
        deviceType: 'iPhone 16 Pro',
        screenWidth: 393,
        screenHeight: 852,
      );

      final event = AnalyticsEvent(
        type: EventType.track,
        name: 'button_clicked',
        hashedDailyId: 'a' * 64,
        hashedMonthlyId: 'b' * 64,
        hashedRetentionId: 'c' * 64,
        sessionId: '550e8400-e29b-41d4-a716-446655440000',
        timestamp: '2026-04-01T12:00:00',
        properties: {'screen': 'home'},
        context: context,
      );

      final json = event.toJson();

      expect(json['type'], 'track');
      expect(json['name'], 'button_clicked');
      expect(json['hashed_daily_id'], 'a' * 64);
      expect(json['hashed_monthly_id'], 'b' * 64);
      expect(json['hashed_retention_id'], 'c' * 64);
      expect(json['session_id'], '550e8400-e29b-41d4-a716-446655440000');
      expect(json['timestamp'], '2026-04-01T12:00:00');
      expect(json['properties'], {'screen': 'home'});
      expect(json['context']['os'], 'iOS');
      expect(json['context']['os_version'], '18.3');
      expect(json['context']['app_version'], '1.0.0');
      expect(json['context']['locale'], 'de_DE');
      expect(json['context']['device_type'], 'iPhone 16 Pro');
      expect(json['context']['screen_width'], 393);
      expect(json['context']['screen_height'], 852);
    });

    test('omits hashed_retention_id when null', () {
      const context = EventContext(
        os: 'Android',
        osVersion: '15.0',
        appVersion: '1.0.0',
        locale: 'en_US',
        deviceType: 'Pixel 9',
        screenWidth: 412,
        screenHeight: 915,
      );

      final event = AnalyticsEvent(
        type: EventType.screen,
        name: 'HomeScreen',
        hashedDailyId: 'a' * 64,
        hashedMonthlyId: 'b' * 64,
        sessionId: 'test-session',
        timestamp: '2026-04-01T12:00:00',
        context: context,
      );

      final json = event.toJson();
      expect(json.containsKey('hashed_retention_id'), false);
      expect(json['type'], 'screen');
      expect(json['properties'], isEmpty);
    });

    test('roundtrips through JSON', () {
      const context = EventContext(
        os: 'iOS',
        osVersion: '18.3',
        appVersion: '1.0.0',
        locale: 'de_DE',
        deviceType: 'iPhone 16 Pro',
        screenWidth: 393,
        screenHeight: 852,
      );

      const original = AnalyticsEvent(
        type: EventType.track,
        name: 'test_event',
        hashedDailyId: 'daily123',
        hashedMonthlyId: 'monthly456',
        hashedRetentionId: 'retention789',
        sessionId: 'session-1',
        timestamp: '2026-04-01T12:00:00',
        properties: {'key': 'value'},
        context: context,
      );

      final restored = AnalyticsEvent.fromJson(original.toJson());

      expect(restored.type, original.type);
      expect(restored.name, original.name);
      expect(restored.hashedDailyId, original.hashedDailyId);
      expect(restored.hashedMonthlyId, original.hashedMonthlyId);
      expect(restored.hashedRetentionId, original.hashedRetentionId);
      expect(restored.sessionId, original.sessionId);
      expect(restored.timestamp, original.timestamp);
      expect(restored.properties, original.properties);
      expect(restored.context.os, original.context.os);
    });
  });

  group('EventContext', () {
    test('serializes with snake_case keys', () {
      const context = EventContext(
        os: 'iOS',
        osVersion: '18.3',
        appVersion: '1.0.0',
        locale: 'de_DE',
        deviceType: 'iPhone 16 Pro',
        screenWidth: 393,
        screenHeight: 852,
      );

      final json = context.toJson();
      expect(json.keys, containsAll([
        'os', 'os_version', 'app_version', 'locale',
        'device_type', 'screen_width', 'screen_height',
      ]));
    });
  });
}
