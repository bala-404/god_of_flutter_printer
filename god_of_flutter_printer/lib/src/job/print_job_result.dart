import '../models/enums.dart';
import '../models/models.dart';
import 'print_job_field_error.dart';

/// Outcome of [PrintWorker.printJob] — validation failure or print result.
class PrintJobResult {
  const PrintJobResult._({
    required this.status,
    this.jobId,
    this.validationErrors = const [],
    this.jobResult,
    this.failedInstantly = false,
  });

  /// Job failed validation before any I/O (instant, no hang).
  factory PrintJobResult.validationFailed(
    List<PrintJobFieldError> errors,
  ) {
    return PrintJobResult._(
      status: PrintJobStatus.validationFailed,
      validationErrors: errors,
      failedInstantly: true,
    );
  }

  factory PrintJobResult.fromJobResult(JobResult result) {
    return PrintJobResult._(
      status: result.isCompleted
          ? PrintJobStatus.completed
          : PrintJobStatus.failed,
      jobId: result.jobId,
      jobResult: result,
    );
  }

  factory PrintJobResult.failed({
    String? jobId,
    required String message,
    String? connectionSummary,
  }) {
    return PrintJobResult._(
      status: PrintJobStatus.failed,
      jobId: jobId,
      jobResult: JobResult(
        jobId: jobId ?? 'unknown',
        status: JobStatus.failed,
        createdAt: DateTime.now(),
        connectionSummary: connectionSummary ?? '',
        errorMessage: message,
      ),
    );
  }

  final PrintJobStatus status;
  final String? jobId;
  final List<PrintJobFieldError> validationErrors;
  final JobResult? jobResult;

  /// `true` when the job was rejected synchronously (no queue, no network).
  final bool failedInstantly;

  bool get isSuccess => status == PrintJobStatus.completed;
  bool get isValidationFailure => status == PrintJobStatus.validationFailed;
  bool get isQueued => status == PrintJobStatus.queued;

  factory PrintJobResult.queued(String jobId) {
    return PrintJobResult._(
      status: PrintJobStatus.queued,
      jobId: jobId,
    );
  }

  String? get errorMessage {
    if (validationErrors.isNotEmpty) {
      return validationErrors.map((e) => e.toString()).join('; ');
    }
    return jobResult?.errorMessage;
  }

  int get bytesSent => jobResult?.bytesSent ?? 0;
}

enum PrintJobStatus {
  validationFailed,
  queued,
  completed,
  failed,
}
