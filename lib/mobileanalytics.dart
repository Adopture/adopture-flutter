/// Privacy-first mobile analytics SDK for Flutter.
///
/// Simple event tracking with offline support, automatic session management,
/// and privacy-preserving user identification.
///
/// ```dart
/// await Mobileanalytics.init(appKey: 'ak_your_app_key');
/// Mobileanalytics.track('button_clicked', {'screen': 'home'});
/// Mobileanalytics.screen('HomeScreen');
/// ```
library;

export 'src/analytics.dart' show Mobileanalytics;
export 'src/config.dart' show AnalyticsConfig;
export 'src/event.dart' show AnalyticsEvent, EventContext, EventType;
