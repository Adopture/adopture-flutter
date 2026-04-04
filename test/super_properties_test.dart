import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adopture/src/super_properties.dart';

void main() {
  group('SuperProperties', () {
    late SuperProperties superProps;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      superProps = SuperProperties();
    });

    test('starts empty', () {
      expect(superProps.all, isEmpty);
    });

    test('register adds properties', () async {
      await superProps.register({'plan': 'pro', 'theme': 'dark'});
      expect(superProps.all, {'plan': 'pro', 'theme': 'dark'});
    });

    test('register overwrites existing keys', () async {
      await superProps.register({'plan': 'free'});
      await superProps.register({'plan': 'pro'});
      expect(superProps.all['plan'], 'pro');
    });

    test('registerOnce does not overwrite existing keys', () async {
      await superProps.register({'plan': 'free'});
      await superProps.registerOnce({'plan': 'pro', 'source': 'organic'});
      expect(superProps.all['plan'], 'free');
      expect(superProps.all['source'], 'organic');
    });

    test('unregister removes a single key', () async {
      await superProps.register({'a': '1', 'b': '2', 'c': '3'});
      await superProps.unregister('b');
      expect(superProps.all, {'a': '1', 'c': '3'});
    });

    test('unregister is a no-op for missing key', () async {
      await superProps.register({'a': '1'});
      await superProps.unregister('nonexistent');
      expect(superProps.all, {'a': '1'});
    });

    test('clear removes all properties', () async {
      await superProps.register({'a': '1', 'b': '2'});
      await superProps.clear();
      expect(superProps.all, isEmpty);
    });

    test('all returns an unmodifiable map', () async {
      await superProps.register({'a': '1'});
      expect(
        () => superProps.all['b'] = '2',
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('persists across instances via SharedPreferences', () async {
      await superProps.register({'plan': 'pro', 'source': 'ad'});

      // Create a new instance and load from disk
      final loaded = SuperProperties();
      await loaded.load();
      expect(loaded.all, {'plan': 'pro', 'source': 'ad'});
    });

    test('load with empty storage starts empty', () async {
      await superProps.load();
      expect(superProps.all, isEmpty);
    });

    test('clear persists the empty state', () async {
      await superProps.register({'a': '1'});
      await superProps.clear();

      final loaded = SuperProperties();
      await loaded.load();
      expect(loaded.all, isEmpty);
    });
  });
}
