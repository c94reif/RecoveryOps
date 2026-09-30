import 'package:le_sdk/le_sdk.dart' as sdk;

class RecordingEntityService implements sdk.EntityService {
  final entities = <String, sdk.Entity>{};
  final upserts = <sdk.Entity>[];
  bool failRead = false;
  bool failWrite = false;
  bool persistWrites = true;

  @override
  Future<String> upsertEntity(sdk.Entity entity) async {
    if (failWrite) throw StateError('host unavailable');
    upserts.add(entity);
    if (persistWrites) entities[entity.id] = entity;
    return entity.id;
  }

  @override
  Future<sdk.Entity?> getEntity(String id) async {
    if (failRead) throw StateError('host unavailable');
    return entities[id];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingMessagingService implements sdk.MessagingService {
  final broadcasts = <String>[];
  bool failBroadcast = false;
  List<sdk.DeliveryResult> results = const [
    sdk.DeliveryResult(peerId: 'peer-1', success: true),
  ];

  @override
  Future<sdk.DeliveryReport> broadcast(String payload) async {
    broadcasts.add(payload);
    if (failBroadcast) throw StateError('radio unavailable');
    return sdk.DeliveryReport(results: results);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
