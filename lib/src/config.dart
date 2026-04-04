/// Configuration for the Adopture analytics SDK.
class AdoptureConfig {
  /// The app key for authentication (format: ak_XXXXXXXXXXXXXXXXXXXXXXXX).
  final String appKey;

  /// The API endpoint URL.
  final String endpoint;

  /// Whether to enable debug mode (logs events, sends immediately).
  final bool debug;

  /// Whether to automatically capture lifecycle events and sessions.
  final bool autoCapture;

  /// How often to flush queued events to the server.
  final Duration flushInterval;

  /// Flush when this many events are queued.
  final int flushAt;

  /// Maximum number of events to store on disk.
  final int maxQueueSize;

  /// SDK version string sent with each request.
  final String sdkVersion;

  /// Whether to hash user IDs before sending.
  ///
  /// When `true` (default), `identify(userId)` sends `SHA256(userId + appKey)`
  /// — consistent with the privacy-first design.
  ///
  /// Set to `false` if you need raw user IDs on the server, e.g. for matching
  /// with RevenueCat subscription data.
  final bool hashUserIds;

  const AdoptureConfig({
    required this.appKey,
    this.endpoint = 'https://api.adopture.com',
    this.debug = false,
    this.autoCapture = true,
    this.flushInterval = const Duration(seconds: 30),
    this.flushAt = 20,
    this.maxQueueSize = 1000,
    this.sdkVersion = '0.1.0',
    this.hashUserIds = true,
  });

  /// Validates the configuration.
  /// Throws [ArgumentError] if the config is invalid.
  void validate() {
    if (!RegExp(r'^ak_[A-Za-z0-9]{24}$').hasMatch(appKey)) {
      throw ArgumentError(
        'Invalid appKey format. Expected: ak_ followed by 24 alphanumeric characters.',
      );
    }
    if (endpoint.isEmpty) {
      throw ArgumentError('Endpoint must not be empty.');
    }
    if (flushAt < 1 || flushAt > 100) {
      throw ArgumentError('flushAt must be between 1 and 100.');
    }
    if (maxQueueSize < 1) {
      throw ArgumentError('maxQueueSize must be at least 1.');
    }
  }
}
