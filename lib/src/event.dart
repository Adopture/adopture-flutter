import 'revenue.dart';

/// Event types matching the backend schema.
enum EventType {
  track,
  screen,
  revenue;

  String toJson() => name;
}

/// Device context attached to every event.
class EventContext {
  final String os;
  final String osVersion;
  final String appVersion;
  final String locale;
  final String deviceType;
  final int screenWidth;
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
class AnalyticsEvent {
  final EventType type;
  final String name;
  final String hashedDailyId;
  final String hashedMonthlyId;
  final String? hashedRetentionId;
  final String sessionId;
  final String timestamp;
  final Map<String, String> properties;
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

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) =>
      AnalyticsEvent(
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
