import 'package:flutter_test/flutter_test.dart';

import 'package:adopture/src/session_manager.dart';

void main() {
  group('SessionManager', () {
    test('generates a valid UUID v4 session ID', () {
      final session = SessionManager();
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(session.sessionId),
        true,
      );
    });

    test('session ID stays the same within timeout', () {
      final session = SessionManager();
      final id1 = session.sessionId;
      session.touch();
      expect(session.rotateIfNeeded(), false);
      expect(session.sessionId, id1);
    });

    test('startNewSession generates a different ID', () {
      final session = SessionManager();
      final id1 = session.sessionId;
      session.startNewSession();
      expect(session.sessionId, isNot(id1));
    });

    test('touch updates last activity', () {
      final session = SessionManager();
      session.touch();
      expect(session.rotateIfNeeded(), false);
    });
  });
}
