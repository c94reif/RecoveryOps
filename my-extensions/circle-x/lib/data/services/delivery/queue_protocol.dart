class QueueWireType {
  static const String mainHello = 'main.hello';
  static const String mainEnqueue = 'main.enqueue';
  static const String mainOutcome = 'main.outcome';
  static const String mainDeleteResult = 'main.deleteResult';
  static const String mainExecuteResult = 'main.executeResult';
  static const String mainProbe = 'main.probe';
  static const String mainRetryNow = 'main.retryNow';
  static const String mainSendNow = 'main.sendNow';
  static const String mainShutdown = 'main.shutdown';

  static const String workerReady = 'worker.ready';
  static const String workerExecute = 'worker.execute';
  static const String workerDelete = 'worker.delete';
  static const String workerSendNowResult = 'worker.sendNowResult';
  static const String workerLog = 'worker.log';
}

Map<String, Object?> mainHello(List<Map<String, Object?>> resumed) => {
      'type': QueueWireType.mainHello,
      'resumed': resumed,
    };

Map<String, Object?> mainEnqueue(Map<String, Object?> submission) => {
      'type': QueueWireType.mainEnqueue,
      'submission': submission,
    };

Map<String, Object?> mainOutcome({
  required String transport,
  required bool success,
}) =>
    {
      'type': QueueWireType.mainOutcome,
      'transport': transport,
      'success': success,
    };

Map<String, Object?> mainDeleteResult({
  required int submissionId,
  required bool success,
}) =>
    {
      'type': QueueWireType.mainDeleteResult,
      'submissionId': submissionId,
      'success': success,
    };

Map<String, Object?> mainExecuteResult({
  required int submissionId,
  required bool success,
}) =>
    {
      'type': QueueWireType.mainExecuteResult,
      'submissionId': submissionId,
      'success': success,
    };

Map<String, Object?> mainRetryNow() => {'type': QueueWireType.mainRetryNow};

Map<String, Object?> mainSendNow(int submissionId) => {
      'type': QueueWireType.mainSendNow,
      'submissionId': submissionId,
    };

Map<String, Object?> mainProbe() => {'type': QueueWireType.mainProbe};

Map<String, Object?> mainShutdown() => {'type': QueueWireType.mainShutdown};

Map<String, Object?> workerReady() => {'type': QueueWireType.workerReady};

Map<String, Object?> workerExecute({
  required int submissionId,
  required Map<String, Object?> submission,
}) =>
    {
      'type': QueueWireType.workerExecute,
      'submissionId': submissionId,
      'submission': submission,
    };

Map<String, Object?> workerDelete(int submissionId) => {
      'type': QueueWireType.workerDelete,
      'submissionId': submissionId,
    };

Map<String, Object?> workerSendNowResult({
  required int submissionId,
  required bool delivered,
}) =>
    {
      'type': QueueWireType.workerSendNowResult,
      'submissionId': submissionId,
      'delivered': delivered,
    };

Map<String, Object?> workerLog(String message) => {
      'type': QueueWireType.workerLog,
      'message': message,
    };
