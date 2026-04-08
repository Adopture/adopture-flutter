import 'package:flutter/widgets.dart';

import 'analytics.dart';
import 'go_router_observer.dart';

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
  AdoptureNavigationObserver({
    @Deprecated('No longer needed — dedup is now automatic when GoRouterObserver is active')
    Set<String>? goRouterRouteNames,
  });

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

    // When GoRouterObserver is active it already tracks every route change
    // via routeInformationProvider. Skip ALL navigator events to avoid
    // double-counting (e.g. "onboarding-v3/auth" + "onboarding-v3-auth").
    if (GoRouterObserver.isActive) return;

    Adopture.screen(name, {'source': 'navigator_observer'});
  }
}
