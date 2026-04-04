import 'package:flutter/widgets.dart';

import 'analytics.dart';

/// Tracks all route changes from a GoRouter instance, including
/// `StatefulShellRoute` branch switches that standard [NavigatorObserver]
/// cannot see.
///
/// Listens to `GoRouter.routeInformationProvider` (a Flutter-core type),
/// so this file does **not** import `go_router` — any router that exposes
/// a [RouteInformationProvider] will work.
///
/// ## Usage
///
/// ```dart
/// final router = GoRouter(routes: [...]);
/// Adopture.observeGoRouter(router);
/// ```
class GoRouterObserver {
  static GoRouterObserver? _instance;

  String? _lastTrackedPath;
  VoidCallback? _removeListener;

  GoRouterObserver._();

  /// Attaches to a router instance. Accepts `dynamic` so we don't need
  /// `go_router` as a dependency — the only requirement is that the object
  /// has a `routeInformationProvider` getter.
  static void observe(dynamic goRouter) {
    _instance?.detach();
    _instance = GoRouterObserver._();
    _instance!._attach(goRouter);
  }

  /// Detaches and stops tracking.
  static void dispose() {
    _instance?.detach();
    _instance = null;
  }

  void _attach(dynamic goRouter) {
    try {
      final provider =
          goRouter.routeInformationProvider as RouteInformationProvider;

      void listener() {
        final path = provider.value.uri.toString();
        if (path != _lastTrackedPath) {
          _lastTrackedPath = path;
          _trackScreen(path);
        }
      }

      provider.addListener(listener);
      _removeListener = () => provider.removeListener(listener);

      // Track initial route
      listener();
    } catch (e) {
      debugPrint('[Adopture] GoRouter observation failed: $e');
    }
  }

  void detach() {
    _removeListener?.call();
    _removeListener = null;
    _lastTrackedPath = null;
  }

  void _trackScreen(String path) {
    if (!Adopture.isEnabled) return;

    final screenName = formatScreenName(path);
    Adopture.screen(screenName, {'path': path});
  }

  /// Converts a URI path into a readable screen name.
  ///
  /// - `/` → `home`
  /// - `/shopping-list` → `shopping-list`
  /// - `/settings?tab=privacy` → `settings`
  /// - `/users/a1b2c3d4e5f6g7h8i9j0` → `users/detail`
  static String formatScreenName(String path) {
    var name = path.startsWith('/') ? path.substring(1) : path;
    if (name.isEmpty) return 'home';

    // Strip query params
    final q = name.indexOf('?');
    if (q != -1) name = name.substring(0, q);

    // Strip fragment
    final h = name.indexOf('#');
    if (h != -1) name = name.substring(0, h);

    // Strip trailing slash
    if (name.endsWith('/')) name = name.substring(0, name.length - 1);

    return _normalizeDynamicSegments(name);
  }

  static String _normalizeDynamicSegments(String path) {
    final segments = path.split('/');
    final out = <String>[];

    for (var i = 0; i < segments.length; i++) {
      if (_looksLikeId(segments[i]) && i > 0) {
        out.add('detail');
      } else {
        out.add(segments[i]);
      }
    }

    return out.join('/');
  }

  /// Heuristic: UUIDs (32+ chars with dashes) or Firestore-style IDs (20+ alphanum).
  static bool _looksLikeId(String s) {
    if (s.isEmpty) return false;
    if (s.contains('-') && s.length >= 32) return true;
    if (s.length >= 20 && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(s)) return true;
    return false;
  }
}
