import 'package:uuid/uuid.dart';

/// Manages session lifecycle with 30-minute inactivity timeout.
class SessionManager {
  static const _sessionTimeout = Duration(minutes: 30);
  static const _uuid = Uuid();

  String _sessionId;
  DateTime _lastActivityAt;

  SessionManager()
    : _sessionId = _uuid.v4(),
      _lastActivityAt = DateTime.now();

  /// The current session ID.
  String get sessionId => _sessionId;

  /// Updates the last activity timestamp.
  void touch() {
    _lastActivityAt = DateTime.now();
  }

  /// Checks if the session has expired and rotates if needed.
  /// Returns true if a new session was started.
  bool rotateIfNeeded() {
    final elapsed = DateTime.now().difference(_lastActivityAt);
    if (elapsed >= _sessionTimeout) {
      _sessionId = _uuid.v4();
      _lastActivityAt = DateTime.now();
      return true;
    }
    return false;
  }

  /// Forces a new session (e.g., on cold app start).
  void startNewSession() {
    _sessionId = _uuid.v4();
    _lastActivityAt = DateTime.now();
  }
}
