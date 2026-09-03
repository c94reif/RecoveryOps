class QueueWireType {
  static const String mainHello = 'main.hello';
  static const String mainEnqueue = 'main.enqueue';
  static const String mainOutcome = 'main.outcome';
  static const String mainPromptResponse = 'main.promptResponse';
  static const String mainExecuteResult = 'main.executeResult';
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

Map<String, Object?> mainEnqueue(Map<String, Object?> request) => {
      'type': QueueWireType.mainEnqueue,
      'request': request,
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
  required int requestId,
  required bool send,
}) =>
    {
      'type': QueueWireType.mainPromptResponse,
      'requestId': requestId,
      'send': send,
    };

Map<String, Object?> mainExecuteResult({
  required int requestId,
  required bool success,
}) =>
    {
      'type': QueueWireType.mainExecuteResult,
      'requestId': requestId,
      'success': success,
    };

Map<String, Object?> mainShutdown() => {'type': QueueWireType.mainShutdown};

Map<String, Object?> workerReady() => {'type': QueueWireType.workerReady};

Map<String, Object?> workerExecute({
  required int requestId,
  required Map<String, Object?> request,
}) =>
    {
      'type': QueueWireType.workerExecute,
      'requestId': requestId,
      'request': request,
    };

Map<String, Object?> workerPrompt({
  required int requestId,
  required Map<String, Object?> request,
}) =>
    {
      'type': QueueWireType.workerPrompt,
      'requestId': requestId,
      'request': request,
    };

Map<String, Object?> workerDelete(int requestId) => {
      'type': QueueWireType.workerDelete,
      'requestId': requestId,
    };

Map<String, Object?> workerLog(String message) => {
      'type': QueueWireType.workerLog,
      'message': message,
    };
