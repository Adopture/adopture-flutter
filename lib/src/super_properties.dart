import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Global event properties that persist across app sessions.
///
/// Super properties are automatically merged into every tracked event.
/// Event-level properties override super properties with the same key.
class SuperProperties {
  static const _storageKey = 'mobileanalytics_super_props';

  Map<String, String> _props = {};

  /// Loads persisted super properties from disk.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey);
    if (json != null) {
      _props = Map<String, String>.from(
        jsonDecode(json) as Map<String, dynamic>,
      );
    }
  }

  /// Registers super properties, overwriting any existing keys.
  Future<void> register(Map<String, String> properties) async {
    _props.addAll(properties);
    await _persist();
  }

  /// Registers super properties only if the key is not already set.
  Future<void> registerOnce(Map<String, String> properties) async {
    for (final entry in properties.entries) {
      _props.putIfAbsent(entry.key, () => entry.value);
    }
    await _persist();
  }

  /// Removes a single super property by key.
  Future<void> unregister(String key) async {
    _props.remove(key);
    await _persist();
  }

  /// Clears all super properties.
  Future<void> clear() async {
    _props.clear();
    await _persist();
  }

  /// Returns an unmodifiable view of all current super properties.
  Map<String, String> get all => Map.unmodifiable(_props);

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_props));
  }
}
