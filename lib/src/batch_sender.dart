import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  static const _uuid = Uuid();

  final AnalyticsConfig config;
  final EventQueue queue;
  final http.Client _httpClient;

  Timer? _flushTimer;
  bool _isFlushing = false;

  BatchSender({
    required this.config,
    required this.queue,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Starts the periodic flush timer.
  void start() {
    _flushTimer?.cancel();
    if (config.debug) return; // Debug mode sends immediately
    _flushTimer = Timer.periodic(config.flushInterval, (_) => flush());
  }

  /// Stops the periodic flush timer.
  void stop() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  /// Flushes all queued events to the server.
  Future<void> flush() async {
    if (_isFlushing || queue.isEmpty) return;
    _isFlushing = true;

    try {
      while (queue.length > 0) {
        final batchSize =
            queue.length > _maxBatchSize ? _maxBatchSize : queue.length;
        final events = queue.take(batchSize);

        final result = await _sendWithRetry(events);

        if (result == SendResult.success) {
          await queue.removeFromDisk(events.length);
        } else {
          // Re-queue events for next attempt
          queue.requeue(events);
          break;
        }
      }
    } finally {
      _isFlushing = false;
    }
  }

  /// Sends a single event immediately (for debug mode).
  Future<void> sendImmediate(List<AnalyticsEvent> events) async {
    await _send(events);
    await queue.removeFromDisk(events.length);
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
            final delay = Duration(seconds: 1 << attempt); // 1, 2, 4, 8, 16
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

    List<int> body;

    // GZip compress if payload >1KB
    if (payload.length > 1024) {
      body = gzip.encode(utf8.encode(payload));
      headers['Content-Encoding'] = 'gzip';
    } else {
      body = utf8.encode(payload);
    }

    try {
      final response = await _httpClient.post(
        uri,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 202) {
        return SendResult.success;
      } else if (response.statusCode == 429) {
        final retryAfter = response.headers['retry-after'];
        if (retryAfter != null) {
          final seconds = int.tryParse(retryAfter) ?? 60;
          await Future<void>.delayed(Duration(seconds: seconds));
        }
        return SendResult.rateLimited;
      } else if (response.statusCode == 503) {
        await Future<void>.delayed(const Duration(seconds: 30));
        return SendResult.serverError;
      } else {
        return SendResult.serverError;
      }
    } on SocketException {
      return SendResult.networkError;
    } on HttpException {
      return SendResult.networkError;
    } catch (_) {
      return SendResult.networkError;
    }
  }

  /// Disposes the sender and its HTTP client.
  void dispose() {
    stop();
    _httpClient.close();
  }
}
