import 'dart:async';

import '../models/enums.dart';
import '../models/models.dart';

/// In-memory job status store — no database, no API.
class JobStatusStore {
  JobStatusStore({this.maxEntries = 500});

  final int maxEntries;
  final Map<String, JobResult> _jobs = {};

  void upsert(JobResult result) {
    _jobs[result.jobId] = result;
    _evictIfNeeded();
  }

  JobResult? get(String jobId) => _jobs[jobId];

  List<JobResult> recent({int limit = 50}) {
    final list = _jobs.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (list.length <= limit) return list;
    return list.sublist(0, limit);
  }

  void clear() => _jobs.clear();

  void _evictIfNeeded() {
    if (_jobs.length <= maxEntries) return;
    final sorted = _jobs.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final removeCount = _jobs.length - maxEntries;
    for (var i = 0; i < removeCount; i++) {
      _jobs.remove(sorted[i].jobId);
    }
  }
}

/// Structured logger keyed by [jobId].
class PrintLogger {
  final StreamController<JobLogEntry> _controller =
      StreamController<JobLogEntry>.broadcast();
  final Map<String, List<JobLogEntry>> _logsByJob = {};
  final int maxEntriesPerJob;

  PrintLogger({this.maxEntriesPerJob = 200});

  Stream<JobLogEntry> get logStream => _controller.stream;

  void log({
    required String jobId,
    required LogLevel level,
    required String step,
    required String message,
    Map<String, dynamic>? meta,
  }) {
    final entry = JobLogEntry(
      jobId: jobId,
      timestamp: DateTime.now(),
      level: level,
      step: step,
      message: message,
      meta: meta,
    );
    final bucket = _logsByJob.putIfAbsent(jobId, () => []);
    bucket.add(entry);
    if (bucket.length > maxEntriesPerJob) {
      bucket.removeAt(0);
    }
    _controller.add(entry);
  }

  List<JobLogEntry> getLogs(String jobId) =>
      List.unmodifiable(_logsByJob[jobId] ?? const []);

  void clearJob(String jobId) => _logsByJob.remove(jobId);

  Future<void> dispose() async {
    await _controller.close();
  }
}

/// Limits concurrent print executions.
class JobQueue {
  JobQueue({this.maxConcurrent = 5});

  final int maxConcurrent;
  int _active = 0;
  final List<_QueuedTask> _pending = [];

  Future<T> run<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _pending.add(_QueuedTask(() async => completer.complete(await task())));
    _pump();
    return completer.future;
  }

  void _pump() {
    while (_active < maxConcurrent && _pending.isNotEmpty) {
      final item = _pending.removeAt(0);
      _active++;
      item.run().whenComplete(() {
        _active--;
        _pump();
      });
    }
  }
}

class _QueuedTask {
  _QueuedTask(this.run);
  final Future<void> Function() run;
}

/// Per-endpoint lock to serialize jobs targeting the same device.
class ConnectionLockRegistry {
  final Map<String, Future<void>> _locks = {};

  Future<T> runExclusive<T>(String key, Future<T> Function() action) async {
    while (_locks.containsKey(key)) {
      await _locks[key];
    }
    final completer = Completer<void>();
    _locks[key] = completer.future;
    try {
      return await action();
    } finally {
      completer.complete();
      _locks.remove(key);
    }
  }
}
