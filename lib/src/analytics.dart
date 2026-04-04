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
import 'go_router_observer.dart';
import 'hashing.dart';
import 'lifecycle_observer.dart';
import 'navigation_observer.dart';
import 'session_manager.dart';
import 'super_properties.dart';

/// Privacy-first mobile analytics SDK.
///
/// Singleton — call [init] once at app startup, then use
/// [track], [screen], and [identify] anywhere.
class Adopture {
  static Adopture? _instance;

  final AdoptureConfig _config;
  final EventQueue _queue;
  final BatchSender _sender;
  final SessionManager _session;
  late final Hashing _hashing;
  final SuperProperties _superProperties;
  LifecycleObserver? _lifecycleObserver;

  EventContext? _cachedContext;
  String? _userId;
  bool _enabled = true;

  Adopture._({
    required AdoptureConfig config,
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
  /// await Adopture.init(appKey: 'ak_your_app_key');
  /// ```
  static Future<void> init({
    required String appKey,
    String endpoint = 'https://api.adopture.com',
    bool debug = false,
    bool autoCapture = true,
    Duration flushInterval = const Duration(seconds: 30),
    int flushAt = 20,
    int maxQueueSize = 1000,
    bool hashUserIds = true,
  }) async {
    final config = AdoptureConfig(
      appKey: appKey,
      endpoint: endpoint,
      debug: debug,
      autoCapture: autoCapture,
      flushInterval: flushInterval,
      flushAt: flushAt,
      maxQueueSize: maxQueueSize,
      hashUserIds: hashUserIds,
    );
    config.validate();

    final queue = EventQueue(maxQueueSize: maxQueueSize);
    await queue.init();

    final sender = BatchSender(config: config, queue: queue);
    final session = SessionManager();
    final superProps = SuperProperties();
    await superProps.load();

    final instance = Adopture._(
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

    // Restore persisted user identity (survives app restart)
    final idPrefs = await SharedPreferences.getInstance();
    instance._userId = idPrefs.getString('adopture_user_id');

    // Detect app install / update
    await instance._trackInstallOrUpdate();

    // Start auto-capture if enabled
    if (autoCapture) {
      instance._setupAutoCapture();
    }

    // Start flush timer
    sender.start();

    if (debug) {
      debugPrint('[Adopture] Initialized with appKey: ${appKey.substring(0, 6)}...');
    }
  }

  /// Tracks a custom event.
  ///
  /// ```dart
  /// Adopture.track('button_clicked', {'screen': 'home'});
  /// ```
  static void track(String name, [Map<String, String>? properties]) {
    _assertInitialized();
    if (!_instance!._enabled) return;
    _instance!._enqueue(EventType.track, name, properties ?? {});
  }

  /// Tracks a screen view.
  ///
  /// ```dart
  /// Adopture.screen('HomeScreen');
  /// ```
  static void screen(String name, [Map<String, String>? properties]) {
    _assertInitialized();
    if (!_instance!._enabled) return;
    _instance!._enqueue(EventType.screen, name, properties ?? {});
  }

  /// Associates a user ID with all subsequent events.
  ///
  /// The ID is persisted across app restarts. By default it is hashed
  /// with `SHA256(userId + appKey)` before sending. Set `hashUserIds: false`
  /// in [init] to send raw IDs (e.g. for RevenueCat matching).
  ///
  /// Does **not** start a new session — the user is the same person
  /// before and after authentication.
  ///
  /// ```dart
  /// Adopture.identify(firebaseUser.uid);
  /// ```
  static Future<void> identify(String userId) async {
    _assertInitialized();
    final effectiveId = _instance!._config.hashUserIds
        ? _instance!._hashing.hashUserId(userId)
        : userId;
    _instance!._userId = effectiveId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adopture_user_id', effectiveId);

    if (_instance!._config.debug) {
      debugPrint('[Adopture] identify: ${effectiveId.substring(0, 8)}...');
    }
  }

  /// Clears the user identity without affecting the session or queue.
  ///
  /// Use this on logout / account switch. Subsequent events will be
  /// anonymous until [identify] is called again.
  ///
  /// For a full state reset (identity + session + queue), use [reset].
  static Future<void> logout() async {
    _assertInitialized();
    _instance!._userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('adopture_user_id');

    if (_instance!._config.debug) {
      debugPrint('[Adopture] logout: user identity cleared');
    }
  }

  /// Flushes all queued events to the server immediately.
  static Future<void> flush() async {
    _assertInitialized();
    await _instance!._sender.flush();
  }

  /// Resets all local state: clears user identity, queue, and starts a new session.
  static Future<void> reset() async {
    _assertInitialized();
    _instance!._userId = null;
    _instance!._session.startNewSession();
    await _instance!._queue.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('adopture_user_id');
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
    GoRouterObserver.dispose();
    _instance!._lifecycleObserver?.unregister();
    _instance!._sender.stop();
    await _instance!._sender.flush();
    await _instance!._queue.close();
    _instance!._sender.dispose();
    _instance = null;
  }

  // --- Navigation tracking ---

  /// Observes a `GoRouter` instance for automatic screen tracking.
  ///
  /// Tracks **all** route changes including `StatefulShellRoute` branch
  /// switches that a standard [NavigatorObserver] cannot see.
  ///
  /// Call this once after creating your `GoRouter`:
  ///
  /// ```dart
  /// final router = GoRouter(routes: [...]);
  /// Adopture.observeGoRouter(router);
  /// ```
  ///
  /// The [goRouter] parameter is `dynamic` so the SDK does not depend on
  /// the `go_router` package. Any object with a `routeInformationProvider`
  /// getter works.
  static void observeGoRouter(dynamic goRouter) {
    GoRouterObserver.observe(goRouter);
  }

  /// Returns a [NavigatorObserver] for standard (non-GoRouter) navigation.
  ///
  /// Use this for `MaterialApp.navigatorObservers` or as a fallback in
  /// `GoRouter.observers` to catch modals/dialogs that bypass the router.
  ///
  /// If [observeGoRouter] is also active, GoRouter routes are automatically
  /// deduplicated. Pass [goRouterRouteNames] to list named routes that
  /// should be skipped by this observer.
  ///
  /// ```dart
  /// GoRouter(
  ///   observers: [Adopture.navigationObserver()],
  ///   routes: [...],
  /// );
  /// ```
  static NavigatorObserver navigationObserver({
    Set<String>? goRouterRouteNames,
  }) {
    return AdoptureNavigationObserver(
      goRouterRouteNames: goRouterRouteNames,
    );
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
      userId: _userId,
    );

    unawaited(_queue.add(event).catchError((Object e) {
      debugPrint('[Adopture] Failed to persist event to disk: $e');
    }));

    if (_config.debug) {
      debugPrint('[Adopture] ${type.name}: $name');
      unawaited(_sender.flush().catchError((Object e) {
        debugPrint('[Adopture] Debug flush failed: $e');
      }));
    } else if (_queue.length >= _config.flushAt) {
      unawaited(_sender.flush().catchError((Object e) {
        debugPrint('[Adopture] Flush failed: $e');
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
          debugPrint('[Adopture] Background flush failed: $e');
        }));
      },
    );
    _lifecycleObserver!.register();
  }

  Future<void> _trackInstallOrUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getString('adopture_app_version');
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

    await prefs.setString('adopture_app_version', currentVersion);
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
    final stored = prefs.getString('adopture_device_id');
    if (stored != null) return stored;
    final generated = 'desktop-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    await prefs.setString('adopture_device_id', generated);
    return generated;
  }

  static void _assertInitialized() {
    assert(
      _instance != null,
      'Adopture.init() must be called before using the SDK.',
    );
  }
}
