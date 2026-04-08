import 'revenue.dart';

/// Event types matching the backend schema.
enum EventType {
  /// Custom event (e.g. button clicks, form submissions).
  track,

  /// Screen view event.
  screen,

  /// Revenue / purchase event.
  revenue;

  String toJson() => name;
}

/// Device context attached to every event.
///
/// Collected once at SDK initialization and cached for the session.
/// Contains only non-PII device metadata.
class EventContext {
  /// Operating system name (e.g. "iOS", "Android").
  final String os;

  /// Operating system version string.
  final String osVersion;

  /// App version from `package_info_plus`.
  final String appVersion;

  /// Device locale (e.g. "en_US").
  final String locale;

  /// Device model identifier (e.g. "iPhone15,2").
  final String deviceType;

  /// Logical screen width in pixels.
  final int screenWidth;

  /// Logical screen height in pixels.
  final int screenHeight;

  const EventContext({
    required this.os,
    required this.osVersion,
    required this.appVersion,
    required this.locale,
    required this.deviceType,
    required this.screenWidth,
    required this.screenHeight,
  });

  Map<String, dynamic> toJson() => {
        'os': os,
        'os_version': osVersion,
        'app_version': appVersion,
        'locale': locale,
        'device_type': deviceType,
        'screen_width': screenWidth,
        'screen_height': screenHeight,
      };

  factory EventContext.fromJson(Map<String, dynamic> json) => EventContext(
        os: json['os'] as String,
        osVersion: json['os_version'] as String,
        appVersion: json['app_version'] as String,
        locale: json['locale'] as String,
        deviceType: json['device_type'] as String,
        screenWidth: json['screen_width'] as int,
        screenHeight: json['screen_height'] as int,
      );
}

/// A single analytics event matching the backend SDKEvent schema.
///
/// Created internally by the SDK when [Adopture.track], [Adopture.screen],
/// or [Adopture.trackRevenue] is called.
class AnalyticsEvent {
  /// The event type.
  final EventType type;

  /// Event name (e.g. "button_clicked", "HomeScreen").
  final String name;

  /// SHA256 hash rotating daily — used for DAU counting.
  final String hashedDailyId;

  /// SHA256 hash rotating monthly — used for MAU and retention.
  final String hashedMonthlyId;

  /// SHA256 hash rotating quarterly — used for cohort analysis.
  final String? hashedRetentionId;

  /// UUID identifying the current session.
  final String sessionId;

  /// ISO 8601 UTC timestamp.
  final String timestamp;

  /// Custom properties merged with super properties.
  final Map<String, String> properties;

  /// Device context snapshot.
  final EventContext context;

  /// Authenticated user ID, or `null` for anonymous events.
  /// May be hashed or raw depending on [AdoptureConfig.hashUserIds].
  final String? userId;

  /// Revenue data — only present when [type] is [EventType.revenue].
  final RevenueData? revenue;

  const AnalyticsEvent({
    required this.type,
    required this.name,
    required this.hashedDailyId,
    required this.hashedMonthlyId,
    this.hashedRetentionId,
    required this.sessionId,
    required this.timestamp,
    this.properties = const {},
    required this.context,
    this.userId,
    this.revenue,
  });

  Map<String, dynamic> toJson() => {
        'type': type.toJson(),
        'name': name,
        'hashed_daily_id': hashedDailyId,
        'hashed_monthly_id': hashedMonthlyId,
        if (hashedRetentionId != null) 'hashed_retention_id': hashedRetentionId,
        'session_id': sessionId,
        'timestamp': timestamp,
        'properties': properties,
        'context': context.toJson(),
        if (userId != null) 'user_id': userId,
        if (revenue != null) 'revenue': revenue!.toJson(),
      };

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) => AnalyticsEvent(
        type: EventType.values.firstWhere(
          (e) => e.name == json['type'],
        ),
        name: json['name'] as String,
        hashedDailyId: json['hashed_daily_id'] as String,
        hashedMonthlyId: json['hashed_monthly_id'] as String,
        hashedRetentionId: json['hashed_retention_id'] as String?,
        sessionId: json['session_id'] as String,
        timestamp: json['timestamp'] as String,
        properties: Map<String, String>.from(
          json['properties'] as Map? ?? {},
        ),
        context: EventContext.fromJson(
          json['context'] as Map<String, dynamic>,
        ),
        userId: json['user_id'] as String?,
        revenue: json['revenue'] != null
            ? RevenueData.fromJson(json['revenue'] as Map<String, dynamic>)
            : null,
      );
}
