import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'event.dart';

/// Manages event queuing with in-memory list backed by sqflite.
class EventQueue {
  final int maxQueueSize;

  Database? _db;
  final List<AnalyticsEvent> _memoryQueue = [];
  bool _initialized = false;

  EventQueue({this.maxQueueSize = 1000});

  /// Initializes the database and loads persisted events.
  Future<void> init() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/mobileanalytics_events.db';

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );

    // Load persisted events into memory
    final rows = await _db!.query(
      'events',
      orderBy: 'id ASC',
      limit: maxQueueSize,
    );
    for (final row in rows) {
      final json = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      _memoryQueue.add(AnalyticsEvent.fromJson(json));
    }

    _initialized = true;
  }

  /// Adds an event to the queue. Persists to disk immediately.
  Future<void> add(AnalyticsEvent event) async {
    _memoryQueue.add(event);

    // Persist to disk
    await _db?.insert('events', {
      'payload': jsonEncode(event.toJson()),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    // Prune if over limit (FIFO)
    await _prune();
  }

  /// Returns and removes up to [count] events from the queue.
  List<AnalyticsEvent> take(int count) {
    final batch = _memoryQueue.take(count).toList();
    _memoryQueue.removeRange(0, batch.length);
    return batch;
  }

  /// Re-adds events to the front of the queue (for retry).
  void requeue(List<AnalyticsEvent> events) {
    _memoryQueue.insertAll(0, events);
  }

  /// Removes the oldest [count] events from disk.
  Future<void> removeFromDisk(int count) async {
    if (_db == null) return;
    final rows = await _db!.query(
      'events',
      columns: ['id'],
      orderBy: 'id ASC',
      limit: count,
    );
    if (rows.isEmpty) return;

    final ids = rows.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db!.delete(
      'events',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// The number of events currently in the queue.
  int get length => _memoryQueue.length;

  /// Whether the queue is empty.
  bool get isEmpty => _memoryQueue.isEmpty;

  /// Closes the database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initialized = false;
  }

  /// Clears all events from memory and disk.
  Future<void> clear() async {
    _memoryQueue.clear();
    await _db?.delete('events');
  }

  Future<void> _prune() async {
    while (_memoryQueue.length > maxQueueSize) {
      _memoryQueue.removeAt(0);
    }
    // Also prune disk
    final diskCount = Sqflite.firstIntValue(
      await _db!.rawQuery('SELECT COUNT(*) FROM events'),
    );
    if (diskCount != null && diskCount > maxQueueSize) {
      final excess = diskCount - maxQueueSize;
      await _db!.rawDelete('''
        DELETE FROM events WHERE id IN (
          SELECT id FROM events ORDER BY id ASC LIMIT ?
        )
      ''', [excess]);
    }
  }
}
