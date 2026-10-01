import 'dart:typed_data';
import 'package:le_sdk/le_sdk.dart' as sdk;

class FakeMeshItems implements sdk.MeshItemService {
  final records = <String, sdk.MeshItem>{};
  final created = <Map<String, Object?>>[];
  final updated = <String>[];
  bool schemaRegistered = true;
  bool failList = false;
  bool loseCreateResponse = false;
  bool loseUpdateResponse = false;
  bool dropWrites = false;
  bool failWrites = false;
  Duration? lastTtl;
  int nextId = 0;

  @override
  Future<sdk.MeshDataType?> getDataType(sdk.MeshDataTypePath path) async =>
      schemaRegistered
          ? sdk.MeshDataType(
              path: path,
              schema: Uint8List.fromList([]),
              isDeprecated: false,
              createdAt: DateTime.utc(2026))
          : null;

  @override
  Future<List<sdk.MeshItem>> listItems(sdk.MeshDataTypePath type,
      {Map<String, Object?>? filter}) async {
    if (failList) throw StateError('disconnected');
    return records.values.toList();
  }

  @override
  Future<sdk.MeshItem> createItem(
      sdk.MeshDataTypePath type, Map<String, Object?> data,
      {Duration? ttl}) async {
    if (failWrites) throw StateError('write failed');
    lastTtl = ttl;
    created.add(data);
    final item = seed(type, data, persist: !dropWrites);
    if (loseCreateResponse) {
      loseCreateResponse = false;
      throw StateError('response lost after commit');
    }
    return item;
  }

  sdk.MeshItem seed(sdk.MeshDataTypePath type, Map<String, Object?> data,
      {bool persist = true}) {
    final item = sdk.MeshItem(
        path: sdk.MeshItemPath(type: type, id: 'server-${++nextId}'),
        data: data,
        createdAt: DateTime.utc(2026));
    if (persist) records[item.path.id] = item;
    return item;
  }

  @override
  Future<sdk.MeshItem> updateItem(
      sdk.MeshItemPath path, Map<String, Object?> data,
      {Duration? ttl}) async {
    if (failWrites) throw StateError('write failed');
    lastTtl = ttl;
    updated.add(path.id);
    final item = sdk.MeshItem(
        path: path, data: data, createdAt: records[path.id]!.createdAt);
    if (!dropWrites) records[path.id] = item;
    if (loseUpdateResponse) {
      loseUpdateResponse = false;
      throw StateError('response lost after update');
    }
    return item;
  }

  @override
  Future<sdk.MeshItem?> getItem(sdk.MeshItemPath path) async =>
      records[path.id];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
