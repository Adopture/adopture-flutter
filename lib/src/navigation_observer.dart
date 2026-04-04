import 'package:flutter/widgets.dart';

import 'analytics.dart';

/// [NavigatorObserver] that automatically tracks screen views.
///
/// Add this to your navigator's `observers` list for basic screen tracking.
///
/// **Note:** If you use `go_router` with `StatefulShellRoute`, this observer
/// will NOT see branch switches. Use [Adopture.observeGoRouter] instead
/// (or in addition — it deduplicates automatically).
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [Adopture.navigationObserver()],
/// );
/// ```
class AdoptureNavigationObserver extends NavigatorObserver {
  /// Route names managed by GoRouter — skipped to avoid double-counting
  /// when [Adopture.observeGoRouter] is also active.
  final Set<String> _goRouterRouteNames;

  AdoptureNavigationObserver({Set<String>? goRouterRouteNames})
      : _goRouterRouteNames = goRouterRouteNames ?? const {};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackScreenView(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _trackScreenView(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _trackScreenView(previousRoute);
  }

  void _trackScreenView(Route<dynamic> route) {
    if (!Adopture.isEnabled) return;

    final name = route.settings.name;
    if (name == null || name.isEmpty) return;

    // Skip GoRouter routes when the GoRouter observer is active
    if (_isGoRouterRoute(name)) return;

    Adopture.screen(name, {'source': 'navigator_observer'});
  }

  bool _isGoRouterRoute(String name) {
    if (name.startsWith('/')) return true;
    return _goRouterRouteNames.contains(name);
  }
}
