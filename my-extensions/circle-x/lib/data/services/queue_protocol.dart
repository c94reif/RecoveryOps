class QueueWireType {
  static const String mainHello = 'main.hello';
  static const String mainEnqueue = 'main.enqueue';
  static const String mainOutcome = 'main.outcome';
  static const String mainPromptResponse = 'main.promptResponse';
  static const String mainPromptDeferred = 'main.promptDeferred';
  static const String mainExecuteResult = 'main.executeResult';
  static const String mainProbe = 'main.probe';
  static const String mainShutdown = 'main.shutdown';

  static const String workerReady = 'worker.ready';
  static const String workerExecute = 'worker.execute';
  static const String workerPrompt = 'worker.prompt';
  static const String workerDelete = 'worker.delete';
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

Map<String, Object?> mainPromptResponse({
  required int submissionId,
  required bool send,
}) =>
    {
      'type': QueueWireType.mainPromptResponse,
      'submissionId': submissionId,
      'send': send,
    };

Map<String, Object?> mainPromptDeferred(int submissionId) => {
      'type': QueueWireType.mainPromptDeferred,
      'submissionId': submissionId,
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

Map<String, Object?> workerPrompt({
  required int submissionId,
  required Map<String, Object?> submission,
}) =>
    {
      'type': QueueWireType.workerPrompt,
      'submissionId': submissionId,
      'submission': submission,
    };

Map<String, Object?> workerDelete(int submissionId) => {
      'type': QueueWireType.workerDelete,
      'submissionId': submissionId,
    };

Map<String, Object?> workerLog(String message) => {
      'type': QueueWireType.workerLog,
      'message': message,
    };
