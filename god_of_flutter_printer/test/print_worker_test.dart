import 'package:flutter_test/flutter_test.dart';
import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';

void main() {
  group('EscPosEncoder', () {
    test('encodes text with init command', () async {
      final bytes = await EscPosEncoder(paperWidthMm: 80).encodeText('Hello');
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x40);
      expect(bytes.contains('Hello'.codeUnitAt(0)), isTrue);
    });
  });

  group('JobStatusStore', () {
    test('stores and retrieves job results', () {
      final store = JobStatusStore(maxEntries: 10);
      final result = JobResult(
        jobId: 'job-1',
        status: JobStatus.completed,
        createdAt: DateTime.now(),
        connectionSummary: '192.168.1.1:9100',
      );
      store.upsert(result);
      expect(store.get('job-1')?.status, JobStatus.completed);
    });
  });

  group('PrintWorker', () {
    test('queues job and returns jobId', () async {
      final worker = PrintWorker();
      final jobId = await worker.execute(
        PrintRequest(
          connection: const PrintConnection.network(host: '127.0.0.1', port: 9100),
          protocol: PrintProtocol.escPos,
          paperWidthMm: 80,
          mode: PrintMode.text,
          payload: const PrintPayload.text('Test'),
          options: const PrintOptions(retries: 1, timeout: Duration(milliseconds: 200)),
        ),
      );
      expect(jobId, isNotEmpty);
      expect(worker.getJobStatus(jobId)?.status, isNotNull);
    });
  });
}
