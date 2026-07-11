import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:god_of_flutter_printer_platform_interface/god_of_flutter_printer_platform_interface.dart';

import '../connectors/connectors.dart';
import '../job/job.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../template/payload_encoder.dart';
import '../template/template_engine.dart';
import 'worker_internals.dart';

/// Generates unique job identifiers.
abstract class JobIdGenerator {
  String next();
}

class UuidJobIdGenerator implements JobIdGenerator {
  UuidJobIdGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  String next() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final rand = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '$time-$rand';
  }
}

/// Stateless async print worker — no DB, no API, no printer registry.
class PrintWorker {
  PrintWorker({
    JobStatusStore? statusStore,
    PrintLogger? logger,
    JobQueue? queue,
    ConnectionLockRegistry? lockRegistry,
    PayloadEncoder? payloadEncoder,
    JobIdGenerator? jobIdGenerator,
    int maxConcurrent = 5,
  })  : _statusStore = statusStore ?? JobStatusStore(),
        _logger = logger ?? PrintLogger(),
        _queue = queue ?? JobQueue(maxConcurrent: maxConcurrent),
        _lockRegistry = lockRegistry ?? ConnectionLockRegistry(),
        _payloadEncoder = payloadEncoder ??
            PayloadEncoder(
              templateEngine: TemplateEngine(TemplateRepository()),
            ),
        _jobIdGenerator = jobIdGenerator ?? UuidJobIdGenerator() {
    _eventsController = StreamController<JobEvent>.broadcast();
  }

  static final PrintWorker instance = PrintWorker();

  final JobStatusStore _statusStore;
  final PrintLogger _logger;
  final JobQueue _queue;
  final ConnectionLockRegistry _lockRegistry;
  final PayloadEncoder _payloadEncoder;
  final JobIdGenerator _jobIdGenerator;
  late final StreamController<JobEvent> _eventsController;

  Stream<JobEvent> get jobEvents => _eventsController.stream;
  Stream<JobLogEntry> get logStream => _logger.logStream;

  /// Lists installed Windows printer names for USB/raw printing.
  ///
  /// Returns an empty list on platforms where USB enumeration is unavailable.
  Future<List<String>> listUsbPrinters() {
    return PrintWorkerPlatform.instance.listUsbPrinters();
  }

  /// Probes a local print-agent webhook (for Chrome/web → USB printing).
  ///
  /// Run [print_agent] on the Windows PC with the USB printer before calling
  /// this from a web app. On web, [discover] tries localhost URLs automatically.
  Future<AgentProbeResult> probePrintAgent(
    String baseUrl, {
    bool discover = false,
  }) {
    if (discover || baseUrl.trim().isEmpty) {
      return PrintAgentClient.discoverAndProbe(preferred: baseUrl);
    }
    return PrintAgentClient(baseUrl: baseUrl).probe();
  }

  /// Resolves a reachable local print-agent URL on this PC (web helper).
  Future<String?> discoverPrintAgentUrl({String? preferred}) async {
    final result = await PrintAgentClient.discoverAndProbe(preferred: preferred);
    return result.online ? result.baseUrl : null;
  }

  /// Lists USB printers via a running print-agent webhook.
  Future<List<String>> listPrintAgentPrinters(String baseUrl) {
    return WebhookPrintConnector.listPrinters(baseUrl);
  }

  /// Lists paired/bonded Bluetooth devices for printing.
  ///
  /// On web, pass [agentBaseUrl] pointing at a running [print_agent] on the
  /// Windows PC that has the paired Bluetooth printer.
  Future<List<BluetoothDeviceInfo>> listBluetoothDevices({
    String? agentBaseUrl,
  }) async {
    if (kIsWeb &&
        agentBaseUrl != null &&
        agentBaseUrl.trim().isNotEmpty) {
      final resolved = await PrintAgentClient.discoverAndProbe(
        preferred: agentBaseUrl.trim(),
      );
      if (!resolved.online || resolved.baseUrl == null) {
        throw StateError(
          resolved.error ?? 'Print agent is not reachable for Bluetooth.',
        );
      }
      return PrintAgentClient(baseUrl: resolved.baseUrl!)
          .listBluetoothDevices();
    }
    return PrintWorkerPlatform.instance.listBluetoothDevices();
  }

  /// Synchronous validation only — no I/O, returns immediately.
  PrintJobValidationResult validateJob(PrintJobSpec spec) {
    return PrintJobValidator.validate(spec);
  }

  /// Print from unified DB JSON ([PrintJobBody] shape).
  Future<PrintJobResult> printFromMap(Map<String, dynamic> map) {
    return printJob(PrintJobSpec.fromMap(map));
  }

  /// Print from a typed [PrintJobBody] (same JSON your DB stores).
  Future<PrintJobResult> printBody(PrintJobBody body) {
    return printJob(PrintJobResolver.toSpec(body));
  }

  /// Validates, then prints. Every job must include its own [PrintJobSpec.connection].
  ///
  /// Invalid jobs fail instantly ([PrintJobResult.failedInstantly]) — no queue,
  /// network, or native calls.
  Future<PrintJobResult> printJob(PrintJobSpec spec) async {
    final validation = validateJob(spec);
    if (!validation.isValid) {
      return PrintJobResult.validationFailed(validation.errors);
    }

    final request = PrintJobBuilder.toRequest(spec);
    try {
      final result = await executeAndWait(request);
      return PrintJobResult.fromJobResult(result);
    } catch (error) {
      final jobId = request.jobId;
      if (jobId != null) {
        final stored = getJobStatus(jobId);
        if (stored != null) {
          return PrintJobResult.fromJobResult(stored);
        }
      }
      return PrintJobResult.failed(
        jobId: jobId,
        message: error.toString(),
        connectionSummary: request.connection.summary,
      );
    }
  }

  /// Queues a job after sync validation. Invalid jobs return immediately.
  Future<PrintJobResult> submitPrintJob(PrintJobSpec spec) async {
    final validation = validateJob(spec);
    if (!validation.isValid) {
      return PrintJobResult.validationFailed(validation.errors);
    }

    final request = PrintJobBuilder.toRequest(spec);
    final jobId = await execute(request);
    return PrintJobResult.queued(jobId);
  }

  /// Submits a job and returns [jobId] immediately while printing async.
  Future<String> execute(PrintRequest request) async {
    final jobId = request.jobId ?? _jobIdGenerator.next();
    final result = JobResult(
      jobId: jobId,
      status: JobStatus.queued,
      createdAt: DateTime.now(),
      connectionSummary: request.connection.summary,
      protocol: request.protocol,
      paperWidthMm: request.paperWidthMm,
    );
    _statusStore.upsert(result);
    _log(
      jobId: jobId,
      step: 'queued',
      level: LogLevel.info,
      message: 'Job queued',
      meta: {
        'connection': request.connection.summary,
        'mode': request.mode.name,
        'protocol': request.protocol.name,
        'paperWidthMm': request.paperWidthMm,
      },
    );
    _emit(jobId, JobStatus.queued, 'Job queued');

    unawaited(
      _queue.run(() => _runJob(jobId, request)),
    );

    return jobId;
  }

  /// Submits a job and waits until completion or failure.
  Future<JobResult> executeAndWait(PrintRequest request) async {
    final jobId = await execute(request);
    return waitForJob(jobId, timeout: request.options.timeout * request.options.retries + const Duration(seconds: 5));
  }

  /// Executes multiple independent jobs concurrently (subject to queue limit).
  Future<List<String>> executeBatch(List<PrintRequest> requests) async {
    final ids = <String>[];
    for (final request in requests) {
      ids.add(await execute(request));
    }
    return ids;
  }

  JobResult? getJobStatus(String jobId) => _statusStore.get(jobId);

  List<JobResult> recentJobs({int limit = 50}) => _statusStore.recent(limit: limit);

  List<JobLogEntry> getJobLogs(String jobId) => _logger.getLogs(jobId);

  Future<JobResult> waitForJob(
    String jobId, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final status = _statusStore.get(jobId);
      if (status == null) {
        throw StateError('Unknown jobId: $jobId');
      }
      if (status.isCompleted || status.isFailed || status.status == JobStatus.cancelled) {
        return status;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException('Timed out waiting for job $jobId');
  }

  Future<void> dispose() async {
    await _eventsController.close();
    await _logger.dispose();
  }

  Future<void> _runJob(String jobId, PrintRequest request) async {
    final lockKey = connectionLockKey(request.connection);
    await _lockRegistry.runExclusive(lockKey, () async {
      await _runJobWithRetry(jobId, request);
    });
  }

  Future<void> _runJobWithRetry(String jobId, PrintRequest request) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        await _runJobOnce(jobId, request);
        return;
      } catch (error, stackTrace) {
        _log(
          jobId: jobId,
          step: 'retry',
          level: LogLevel.warn,
          message: 'Attempt $attempt failed: $error',
        );
        if (attempt >= request.options.retries) {
          _fail(jobId, error, stackTrace);
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }

  Future<void> _runJobOnce(String jobId, PrintRequest request) async {
    _markStarted(jobId);

    _updateStatus(jobId, JobStatus.encoding);
    _emit(jobId, JobStatus.encoding, 'Encoding payload');
    _log(jobId: jobId, step: 'encoding', level: LogLevel.info, message: 'Encoding payload');

    final bytes = await _payloadEncoder.encode(request);
    _log(
      jobId: jobId,
      step: 'encoded',
      level: LogLevel.info,
      message: 'Payload encoded',
      meta: {'bytes': bytes.length},
    );

    PrintConnector? connector;
    try {
      _updateStatus(jobId, JobStatus.connecting);
      _emit(jobId, JobStatus.connecting, 'Connecting');
      _log(
        jobId: jobId,
        step: 'connecting',
        level: LogLevel.info,
        message: 'Connecting to ${request.connection.summary}',
      );

      connector = createConnector(request.connection);
      await connector.connect(timeout: request.options.timeout);

      _log(jobId: jobId, step: 'connected', level: LogLevel.info, message: 'Connected');
      _updateStatus(jobId, JobStatus.sending);
      _emit(jobId, JobStatus.sending, 'Sending ${bytes.length} bytes');

      await connector.write(bytes);

      _complete(jobId, bytes.length);
    } catch (error, stackTrace) {
      _fail(jobId, error, stackTrace);
      rethrow;
    } finally {
      try {
        await connector?.disconnect();
        _log(jobId: jobId, step: 'disconnect', level: LogLevel.info, message: 'Disconnected');
      } catch (_) {
        // Ignore disconnect errors during cleanup.
      }
    }
  }

  void _markStarted(String jobId) {
    final current = _statusStore.get(jobId);
    if (current == null) return;
    _statusStore.upsert(
      current.copyWith(startedAt: DateTime.now()),
    );
  }

  void _updateStatus(String jobId, JobStatus status) {
    final current = _statusStore.get(jobId);
    if (current == null) return;
    current.status = status;
    _statusStore.upsert(current);
  }

  void _complete(String jobId, int bytesSent) {
    final current = _statusStore.get(jobId);
    if (current == null) return;
    _statusStore.upsert(
      current.copyWith(
        status: JobStatus.completed,
        completedAt: DateTime.now(),
        bytesSent: bytesSent,
      ),
    );
    _emit(jobId, JobStatus.completed, 'Completed ($bytesSent bytes)');
    _log(
      jobId: jobId,
      step: 'completed',
      level: LogLevel.info,
      message: 'Job completed',
      meta: {'bytesSent': bytesSent},
    );
  }

  void _fail(String jobId, Object error, StackTrace stackTrace) {
    final current = _statusStore.get(jobId);
    if (current == null) return;
    _statusStore.upsert(
      current.copyWith(
        status: JobStatus.failed,
        completedAt: DateTime.now(),
        errorMessage: error.toString(),
        errorCode: error.runtimeType.toString(),
      ),
    );
    _emit(jobId, JobStatus.failed, error.toString());
    _log(
      jobId: jobId,
      step: 'failed',
      level: LogLevel.error,
      message: error.toString(),
      meta: {'stackTrace': stackTrace.toString()},
    );
  }

  void _emit(String jobId, JobStatus status, String message) {
    _eventsController.add(
      JobEvent(
        jobId: jobId,
        status: status,
        timestamp: DateTime.now(),
        message: message,
      ),
    );
  }

  void _log({
    required String jobId,
    required String step,
    required LogLevel level,
    required String message,
    Map<String, dynamic>? meta,
  }) {
    _logger.log(
      jobId: jobId,
      level: level,
      step: step,
      message: message,
      meta: meta,
    );
  }
}
