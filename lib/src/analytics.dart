import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'batch_sender.dart';
import 'config.dart';
import 'context_collector.dart';
import 'event.dart';
import 'event_queue.dart';
import 'hashing.dart';
import 'lifecycle_observer.dart';
import 'session_manager.dart';
import 'super_properties.dart';

/// Privacy-first mobile analytics SDK.
///
/// Singleton — call [init] once at app startup, then use
/// [track], [screen], and [identify] anywhere.
class Mobileanalytics {
  static Mobileanalytics? _instance;

  final AnalyticsConfig _config;
  final EventQueue _queue;
  final BatchSender _sender;
  final SessionManager _session;
  late final Hashing _hashing;
  final SuperProperties _superProperties;
  LifecycleObserver? _lifecycleObserver;

  EventContext? _cachedContext;
  // ignore: unused_field — reserved for future RevenueCat attribution
  String? _userId;
  bool _enabled = true;

  Mobileanalytics._({
    required AnalyticsConfig config,
    required EventQueue queue,
    required BatchSender sender,
    required SessionManager session,
    required SuperProperties superProperties,
  })  : _config = config,
        _queue = queue,
        _sender = sender,
        _session = session,
        _superProperties = superProperties;

  /// Initializes the SDK. Must be called once before any tracking.
  ///
  /// ```dart
  /// await Mobileanalytics.init(appKey: 'ak_your_app_key');
  /// ```
  static Future<void> init({
    required String appKey,
    String endpoint = 'https://api.mobileanalytics.app',
    bool debug = false,
    bool autoCapture = true,
    Duration flushInterval = const Duration(seconds: 30),
    int flushAt = 20,
    int maxQueueSize = 1000,
  }) async {
    final config = AnalyticsConfig(
      appKey: appKey,
      endpoint: endpoint,
      debug: debug,
      autoCapture: autoCapture,
      flushInterval: flushInterval,
      flushAt: flushAt,
      maxQueueSize: maxQueueSize,
    );
    config.validate();

    final queue = EventQueue(maxQueueSize: maxQueueSize);
    await queue.init();

    final sender = BatchSender(config: config, queue: queue);
    final session = SessionManager();
    final superProps = SuperProperties();
    await superProps.load();

    final instance = Mobileanalytics._(
      config: config,
      queue: queue,
      sender: sender,
      session: session,
      superProperties: superProps,
    );

    // Collect device context
    instance._cachedContext = await ContextCollector().collect();

    // Resolve device ID for hashing
    final deviceId = await _resolveDeviceId();
    instance._hashing = Hashing(deviceId: deviceId, appKey: appKey);

    _instance = instance;

    // Detect app install / update
    await instance._trackInstallOrUpdate();

    // Start auto-capture if enabled
    if (autoCapture) {
      instance._setupAutoCapture();
    }

    // Start flush timer
    sender.start();

    if (debug) {
      debugPrint('[Mobileanalytics] Initialized with appKey: ${appKey.substring(0, 6)}...');
    }
  }

  /// Tracks a custom event.
  ///
  /// ```dart
  /// Mobileanalytics.track('button_clicked', {'screen': 'home'});
  /// ```
  static void track(String name, [Map<String, String>? properties]) {
    _assertInitialized();
    if (!_instance!._enabled) return;
    _instance!._enqueue(EventType.track, name, properties ?? {});
  }

  /// Tracks a screen view.
  ///
  /// ```dart
  /// Mobileanalytics.screen('HomeScreen');
  /// ```
  static void screen(String name, [Map<String, String>? properties]) {
    _assertInitialized();
    if (!_instance!._enabled) return;
    _instance!._enqueue(EventType.screen, name, properties ?? {});
  }

  /// Associates a user ID with subsequent events.
  ///
  /// The ID is stored locally — it is not hashed or sent to the server.
  /// Use this for future features like RevenueCat attribution.
  static void identify(String userId) {
    _assertInitialized();
    _instance!._userId = userId;
  }

  /// Flushes all queued events to the server immediately.
  static Future<void> flush() async {
    _assertInitialized();
    await _instance!._sender.flush();
  }

  /// Resets all local state: clears queue, user ID, and starts a new session.
  static Future<void> reset() async {
    _assertInitialized();
    _instance!._userId = null;
    _instance!._session.startNewSession();
    await _instance!._queue.clear();
  }

  /// Disables all tracking (opt-out).
  static Future<void> disable() async {
    _assertInitialized();
    _instance!._enabled = false;
    _instance!._sender.stop();
    await _instance!._queue.clear();
  }

  /// Re-enables tracking after [disable].
  static void enable() {
    _assertInitialized();
    _instance!._enabled = true;
    _instance!._sender.start();
  }

  /// Registers super properties that are sent with every event.
  /// Overwrites existing keys with the same name.
  static Future<void> registerSuperProperties(Map<String, String> properties) async {
    _assertInitialized();
    await _instance!._superProperties.register(properties);
  }

  /// Registers super properties only if the key is not already set.
  static Future<void> registerSuperPropertiesOnce(Map<String, String> properties) async {
    _assertInitialized();
    await _instance!._superProperties.registerOnce(properties);
  }

  /// Removes a single super property.
  static Future<void> unregisterSuperProperty(String key) async {
    _assertInitialized();
    await _instance!._superProperties.unregister(key);
  }

  /// Clears all super properties.
  static Future<void> clearSuperProperties() async {
    _assertInitialized();
    await _instance!._superProperties.clear();
  }

  /// Returns a read-only view of current super properties.
  static Map<String, String> get superProperties =>
      _instance?._superProperties.all ?? {};

  /// Whether the SDK has been initialized.
  static bool get isInitialized => _instance != null;

  /// Whether tracking is currently enabled.
  static bool get isEnabled => _instance?._enabled ?? false;

  /// Number of events currently in the queue.
  static int get queueLength => _instance?._queue.length ?? 0;

  /// The current session ID.
  static String? get sessionId => _instance?._session.sessionId;

  /// The current endpoint URL.
  static String? get endpoint => _instance?._config.endpoint;

  /// The cached device context (for debugging).
  static EventContext? get deviceContext => _instance?._cachedContext;

  /// Shuts down the SDK, flushing remaining events.
  static Future<void> shutdown() async {
    if (_instance == null) return;
    _instance!._lifecycleObserver?.unregister();
    _instance!._sender.stop();
    await _instance!._sender.flush();
    await _instance!._queue.close();
    _instance!._sender.dispose();
    _instance = null;
  }

  // --- Private ---

  void _enqueue(EventType type, String name, Map<String, String> properties) {
    // Rotate session if needed
    final newSession = _session.rotateIfNeeded();
    if (newSession && _config.autoCapture) {
      _enqueueRaw(EventType.track, 'session_start', {});
    }
    _session.touch();

    _enqueueRaw(type, name, properties);
  }

  void _enqueueRaw(
    EventType type,
    String name,
    Map<String, String> properties,
  ) {
    // Merge: super props as base, event props override
    final mergedProps = {
      ..._superProperties.all,
      ...properties,
    };

    final event = AnalyticsEvent(
      type: type,
      name: name,
      hashedDailyId: _hashing.dailyHash(),
      hashedMonthlyId: _hashing.monthlyHash(),
      hashedRetentionId: _hashing.retentionHash(),
      sessionId: _session.sessionId,
      timestamp: '${DateTime.now().toUtc().toIso8601String().split('.').first}Z',
      properties: mergedProps,
      context: _cachedContext!,
    );

    unawaited(_queue.add(event).catchError((Object e) {
      debugPrint('[Mobileanalytics] Failed to persist event to disk: $e');
    }));

    if (_config.debug) {
      debugPrint('[Mobileanalytics] ${type.name}: $name');
      unawaited(_sender.flush().catchError((Object e) {
        debugPrint('[Mobileanalytics] Debug flush failed: $e');
      }));
    } else if (_queue.length >= _config.flushAt) {
      unawaited(_sender.flush().catchError((Object e) {
        debugPrint('[Mobileanalytics] Flush failed: $e');
      }));
    }
  }

  void _setupAutoCapture() {
    _lifecycleObserver = LifecycleObserver(
      onAppOpened: () {
        final newSession = _session.rotateIfNeeded();
        if (newSession) {
          _enqueueRaw(EventType.track, 'session_start', {});
        }
        _enqueueRaw(EventType.track, 'app_opened', {});
      },
      onAppBackgrounded: () {
        _enqueueRaw(EventType.track, 'app_backgrounded', {});
        unawaited(_sender.flush().catchError((Object e) {
          debugPrint('[Mobileanalytics] Background flush failed: $e');
        }));
      },
    );
    _lifecycleObserver!.register();
  }

  Future<void> _trackInstallOrUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getString('mobileanalytics_app_version');
    final currentVersion = _cachedContext!.appVersion;

    if (storedVersion == null) {
      _enqueueRaw(EventType.track, 'app_installed', {
        'version': currentVersion,
      });
    } else if (storedVersion != currentVersion) {
      _enqueueRaw(EventType.track, 'app_updated', {
        'previous_version': storedVersion,
        'version': currentVersion,
      });
    }

    await prefs.setString('mobileanalytics_app_version', currentVersion);
  }

  static Future<String> _resolveDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      return ios.identifierForVendor ?? 'unknown';
    } else if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      return android.id;
    }
    // Desktop/other: persist a generated ID so it survives app restarts
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('mobileanalytics_device_id');
    if (stored != null) return stored;
    final generated = 'desktop-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    await prefs.setString('mobileanalytics_device_id', generated);
    return generated;
  }

  static void _assertInitialized() {
    assert(
      _instance != null,
      'Mobileanalytics.init() must be called before using the SDK.',
    );
  }
}
