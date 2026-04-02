import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException, HttpException;
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'event.dart';
import 'event_queue.dart';

/// Result of a batch send attempt.
enum SendResult {
  success,
  rateLimited,
  serverError,
  networkError,
}

/// Sends batched events to the ingestion endpoint with retry logic.
class BatchSender {
  static const _maxBatchSize = 100;
  static const _maxRetries = 5;
  static const _maxBackoffMs = 30000;
  static const _uuid = Uuid();
  static final _random = Random();

  final AnalyticsConfig config;
  final EventQueue queue;
  final http.Client _httpClient;
  final Connectivity _connectivity;

  Timer? _flushTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isFlushing = false;
  bool _wasOffline = false;

  BatchSender({
    required this.config,
    required this.queue,
    http.Client? httpClient,
    Connectivity? connectivity,
  })  : _httpClient = httpClient ?? http.Client(),
        _connectivity = connectivity ?? Connectivity();

  void _log(String message) {
    if (config.debug) {
      debugPrint('[Mobileanalytics] $message');
    }
  }

  /// Starts the periodic flush timer and connectivity listener.
  void start() {
    _flushTimer?.cancel();
    _connectivitySub?.cancel();

    if (config.debug) return; // Debug mode sends immediately

    _flushTimer = Timer.periodic(config.flushInterval, (_) => flush());

    // Flush immediately when connectivity returns after being offline
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final isOffline = results.every((r) => r == ConnectivityResult.none);
      if (_wasOffline && !isOffline) {
        _log('Network restored — flushing queued events');
        flush();
      }
      _wasOffline = isOffline;
    });
  }

  /// Stops the periodic flush timer and connectivity listener.
  void stop() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Flushes all queued events to the server.
  Future<void> flush() async {
    if (_isFlushing || queue.isEmpty) return;

    // Skip flush if no network available
    try {
      final connectivity = await _connectivity.checkConnectivity();
      if (connectivity.every((r) => r == ConnectivityResult.none)) {
        _log('No network — skipping flush (${queue.length} events queued)');
        _wasOffline = true;
        return;
      }
    } catch (_) {
      // connectivity_plus may fail on some platforms — proceed with flush
    }

    _isFlushing = true;
    _log('Flush started (${queue.length} events in queue)');

    try {
      while (queue.length > 0) {
        final batchSize =
            queue.length > _maxBatchSize ? _maxBatchSize : queue.length;
        final events = queue.take(batchSize);

        _log('Sending batch of ${events.length} events...');
        final result = await _sendWithRetry(events);

        if (result == SendResult.success) {
          await queue.removeFromDisk(events.length);
          _log('Batch sent successfully (${events.length} events)');
        } else {
          _log('Batch failed: ${result.name} — re-queuing ${events.length} events');
          queue.requeue(events);
          break;
        }
      }
    } finally {
      _isFlushing = false;
      _log('Flush complete (${queue.length} events remaining)');
    }
  }

  Future<SendResult> _sendWithRetry(List<AnalyticsEvent> events) async {
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      final result = await _send(events);

      switch (result) {
        case SendResult.success:
          return result;
        case SendResult.rateLimited:
          // Respect retry-after, handled in _send
          return result;
        case SendResult.serverError:
        case SendResult.networkError:
          if (attempt < _maxRetries - 1) {
            // Full jitter: random(0, min(cap, base * 2^attempt))
            final maxMs = min((1 << attempt) * 1000, _maxBackoffMs);
            final jitteredMs = _random.nextInt(maxMs);
            final delay = Duration(milliseconds: jitteredMs);
            _log('Retry ${attempt + 1}/$_maxRetries in ${delay.inMilliseconds}ms (${result.name})');
            await Future<void>.delayed(delay);
          }
      }
    }
    return SendResult.networkError;
  }

  Future<SendResult> _send(List<AnalyticsEvent> events) async {
    final payload = jsonEncode({
      'app_key': config.appKey,
      'sdk_version': config.sdkVersion,
      'events': events.map((e) => e.toJson()).toList(),
    });

    final uri = Uri.parse('${config.endpoint}/api/v1/events');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Idempotency-Key': _uuid.v4(),
    };

    // TODO: Enable gzip when backend supports Content-Encoding (MOB-62)
    final body = utf8.encode(payload);
    _log('Payload: ${body.length} bytes');

    try {
      final response = await _httpClient.post(
        uri,
        headers: headers,
        body: body,
      );

      _log('HTTP ${response.statusCode} from ${uri.host}${uri.path}');

      if (response.statusCode == 202) {
        return SendResult.success;
      } else if (response.statusCode == 429) {
        final retryAfter = response.headers['retry-after'];
        final seconds = int.tryParse(retryAfter ?? '') ?? 60;
        _log('Rate limited — retry after ${seconds}s');
        await Future<void>.delayed(Duration(seconds: seconds));
        return SendResult.rateLimited;
      } else if (response.statusCode == 503) {
        _log('Server overloaded — retry after 30s');
        await Future<void>.delayed(const Duration(seconds: 30));
        return SendResult.serverError;
      } else {
        _log('Unexpected response: ${response.statusCode} ${response.body}');
        return SendResult.serverError;
      }
    } on SocketException catch (e) {
      _log('Network error: $e');
      return SendResult.networkError;
    } on HttpException catch (e) {
      _log('HTTP error: $e');
      return SendResult.networkError;
    } catch (e) {
      _log('Unexpected error: $e');
      return SendResult.networkError;
    }
  }

  /// Disposes the sender and its HTTP client.
  void dispose() {
    stop();
    _httpClient.close();
  }
}
