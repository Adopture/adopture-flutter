/// Privacy-first mobile analytics SDK for Flutter.
///
/// Simple event tracking with offline support, automatic session management,
/// and privacy-preserving user identification.
///
/// ```dart
/// await Adopture.init(appKey: 'ak_your_app_key');
/// Adopture.track('button_clicked', {'screen': 'home'});
/// Adopture.screen('HomeScreen');
/// ```
library;

export 'src/analytics.dart' show Adopture;
export 'src/config.dart' show AdoptureConfig;
export 'src/event.dart' show AnalyticsEvent, EventContext, EventType;
export 'src/navigation_observer.dart' show AdoptureNavigationObserver;
