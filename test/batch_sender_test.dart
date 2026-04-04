import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:mocktail/mocktail.dart';

import 'package:adopture/src/batch_sender.dart';
import 'package:adopture/src/config.dart';
import 'package:adopture/src/event.dart';
import 'package:adopture/src/event_queue.dart';

// --- Mocks ---

class MockConnectivity extends Mock implements Connectivity {}

/// Minimal in-memory EventQueue for testing (no SQLite).
class FakeEventQueue extends Fake implements EventQueue {
  final List<AnalyticsEvent> _events = [];
  int removedFromDiskCount = 0;

  void addEvents(List<AnalyticsEvent> events) => _events.addAll(events);

  @override
  int get length => _events.length;

  @override
  bool get isEmpty => _events.isEmpty;

  @override
  List<AnalyticsEvent> take(int count) {
    final batch = _events.take(count).toList();
    _events.removeRange(0, batch.length);
    return batch;
  }

  @override
  void requeue(List<AnalyticsEvent> events) {
    _events.insertAll(0, events);
  }

  @override
  Future<void> removeFromDisk(int count) async {
    removedFromDiskCount += count;
  }
}

// --- Helpers ---

AdoptureConfig _config({bool debug = false}) => AdoptureConfig(
      appKey: 'ak_ABCDEFGHIJKLMNOPqrstuv01',
      debug: debug,
    );

AnalyticsEvent _event([String name = 'test_event']) => AnalyticsEvent(
      type: EventType.track,
      name: name,
      hashedDailyId: 'daily123',
      hashedMonthlyId: 'monthly123',
      sessionId: 'session-abc',
      timestamp: '2026-04-02T12:00:00Z',
      properties: {'key': 'value'},
      context: const EventContext(
        os: 'ios',
        osVersion: '18.0',
        appVersion: '1.0.0',
        locale: 'en_US',
        deviceType: 'phone',
        screenWidth: 390,
        screenHeight: 844,
      ),
    );

void main() {
  group('BatchSender', () {
    late FakeEventQueue queue;
    late MockConnectivity connectivity;

    setUp(() {
      queue = FakeEventQueue();
      connectivity = MockConnectivity();
      // Default: WiFi connected
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);
      when(() => connectivity.onConnectivityChanged)
          .thenAnswer((_) => const Stream.empty());
    });

    BatchSender _sender({
      http.Client? client,
      bool debug = false,
    }) =>
        BatchSender(
          config: _config(debug: debug),
          queue: queue,
          httpClient: client,
          connectivity: connectivity,
        );

    test('flush sends events and removes from disk on 202', () async {
      final client = http_testing.MockClient((_) async {
        return http.Response('', 202);
      });

      queue.addEvents([_event(), _event()]);
      final sender = _sender(client: client);

      await sender.flush();

      expect(queue.isEmpty, isTrue);
      expect(queue.removedFromDiskCount, 2);
      sender.dispose();
    });

    test('flush sends correct payload shape', () async {
      Map<String, dynamic>? sentPayload;
      final client = http_testing.MockClient((request) async {
        sentPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('', 202);
      });

      queue.addEvents([_event('purchase')]);
      final sender = _sender(client: client);

      await sender.flush();

      expect(sentPayload, isNotNull);
      expect(sentPayload!['app_key'], 'ak_ABCDEFGHIJKLMNOPqrstuv01');
      expect(sentPayload!['sdk_version'], '0.1.0');
      final events = sentPayload!['events'] as List;
      expect(events, hasLength(1));
      expect((events[0] as Map)['name'], 'purchase');
      sender.dispose();
    });

    test('flush posts to correct URL with required headers', () async {
      Uri? sentUri;
      Map<String, String>? sentHeaders;
      final client = http_testing.MockClient((request) async {
        sentUri = request.url;
        sentHeaders = request.headers;
        return http.Response('', 202);
      });

      queue.addEvents([_event()]);
      final sender = _sender(client: client);
      await sender.flush();

      expect(sentUri.toString(), 'https://api.adopture.com/api/v1/events');
      expect(sentHeaders!['content-type'], contains('application/json'));
      expect(sentHeaders!.containsKey('idempotency-key'), isTrue);
      sender.dispose();
    });

    test('flush is a no-op when queue is empty', () async {
      var requestCount = 0;
      final client = http_testing.MockClient((_) async {
        requestCount++;
        return http.Response('', 202);
      });

      final sender = _sender(client: client);
      await sender.flush();

      expect(requestCount, 0);
      sender.dispose();
    });

    test('flush requeues events on server error after retries', () async {
      final client = http_testing.MockClient((_) async {
        return http.Response('Internal Server Error', 500);
      });

      queue.addEvents([_event()]);
      final sender = _sender(client: client);

      await sender.flush();

      // Events should be requeued, not lost
      expect(queue.length, 1);
      expect(queue.removedFromDiskCount, 0);
      sender.dispose();
    });

    test('flush requeues events on network error', () async {
      final client = http_testing.MockClient((_) async {
        throw http.ClientException('Connection refused');
      });

      queue.addEvents([_event()]);
      final sender = _sender(client: client);

      await sender.flush();

      expect(queue.length, 1);
      expect(queue.removedFromDiskCount, 0);
      sender.dispose();
    });

    test('flush skips when no network available', () async {
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);

      var requestCount = 0;
      final client = http_testing.MockClient((_) async {
        requestCount++;
        return http.Response('', 202);
      });

      queue.addEvents([_event()]);
      final sender = _sender(client: client);

      await sender.flush();

      expect(requestCount, 0);
      // Events stay in queue
      expect(queue.length, 1);
      sender.dispose();
    });

    test('flush prevents concurrent flushes', () async {
      final completer = Completer<http.Response>();
      var requestCount = 0;
      final client = http_testing.MockClient((_) async {
        requestCount++;
        return completer.future;
      });

      queue.addEvents([_event(), _event()]);
      final sender = _sender(client: client);

      // Start two flushes concurrently
      final flush1 = sender.flush();
      final flush2 = sender.flush();

      completer.complete(http.Response('', 202));
      await Future.wait([flush1, flush2]);

      // Only one HTTP request should have been made
      expect(requestCount, 1);
      sender.dispose();
    });

    test('flush batches events in groups of 100', () async {
      var requestCount = 0;
      final batchSizes = <int>[];
      final client = http_testing.MockClient((request) async {
        requestCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        batchSizes.add((body['events'] as List).length);
        return http.Response('', 202);
      });

      // Add 150 events
      queue.addEvents(List.generate(150, (i) => _event('event_$i')));
      final sender = _sender(client: client);

      await sender.flush();

      expect(requestCount, 2);
      expect(batchSizes, [100, 50]);
      sender.dispose();
    });

    test('start creates periodic timer and connectivity listener', () async {
      final controller = StreamController<List<ConnectivityResult>>();
      when(() => connectivity.onConnectivityChanged)
          .thenAnswer((_) => controller.stream);

      final client = http_testing.MockClient((_) async {
        return http.Response('', 202);
      });

      final sender = _sender(client: client);
      sender.start();

      // Simulate going offline then back online
      queue.addEvents([_event()]);
      controller.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      controller.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      // The network-restored flush should have sent the event
      expect(queue.isEmpty, isTrue);

      sender.dispose();
      await controller.close();
    });

    test('stop cancels timer and connectivity subscription', () {
      final sender = _sender();
      sender.start();
      sender.stop();
      // No assertion needed — verifying no exceptions on stop
      sender.dispose();
    });
  });
}
