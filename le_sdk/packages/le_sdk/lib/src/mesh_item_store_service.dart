import 'dart:async';
import 'dart:typed_data';

// ---------- shared types ----------------------------------------------------

/// 4-segment path identifying a mesh-item-store data type (schema).
///
/// Mirrors the upstream service's `namespace/domain/datatype/version`
/// addressing (see `internal/service/routes.go`).
class MeshDataTypePath {
  final String namespace;
  final String domain;
  final String dataType;
  final String version; // 'v1', 'v2', ...

  const MeshDataTypePath({
    required this.namespace,
    required this.domain,
    required this.dataType,
    required this.version,
  });

  Map<String, dynamic> toJson() => {
        'namespace': namespace,
        'domain': domain,
        'dataType': dataType,
        'version': version,
      };

  factory MeshDataTypePath.fromJson(Map<String, dynamic> j) => MeshDataTypePath(
        namespace: j['namespace'] as String,
        domain: j['domain'] as String,
        dataType: j['dataType'] as String,
        version: j['version'] as String,
      );
}

/// Path to a single item: a [MeshDataTypePath] plus the server-assigned id.
class MeshItemPath {
  final MeshDataTypePath type;
  final String id;

  const MeshItemPath({required this.type, required this.id});

  Map<String, dynamic> toJson() => {'type': type.toJson(), 'id': id};

  factory MeshItemPath.fromJson(Map<String, dynamic> j) => MeshItemPath(
        type: MeshDataTypePath.fromJson(j['type'] as Map<String, dynamic>),
        id: j['id'] as String,
      );
}

/// A registered data type. [schema] is the raw JSON-Schema bytes — the SDK
/// does not parse it. Plugins are expected to know the schema for the types
/// they consume and decode the bytes themselves.
class MeshDataType {
  final MeshDataTypePath path;

  /// Raw JSON-Schema bytes. Transmitted as base64 on the wire; the SDK
  /// decodes back to [Uint8List] before surfacing here.
  final Uint8List schema;
  final bool isDeprecated;
  final DateTime createdAt;

  const MeshDataType({
    required this.path,
    required this.schema,
    required this.isDeprecated,
    required this.createdAt,
  });
}

/// A schema-valid item stored at [path].
class MeshItem {
  final MeshItemPath path;
  final Map<String, Object?> data;
  final DateTime createdAt;
  final DateTime? expiryTime;

  const MeshItem({
    required this.path,
    required this.data,
    required this.createdAt,
    this.expiryTime,
  });
}

/// A live message received from a mesh-item-store stream.
class MeshStreamMessage {
  final MeshDataTypePath path;
  final Map<String, Object?> data;
  final DateTime receivedAt;

  const MeshStreamMessage({
    required this.path,
    required this.data,
    required this.receivedAt,
  });

  Map<String, dynamic> toJson() => {
        'path': path.toJson(),
        'data': data,
        'receivedAt': receivedAt.toIso8601String(),
      };

  factory MeshStreamMessage.fromJson(Map<String, dynamic> j) =>
      MeshStreamMessage(
        path: MeshDataTypePath.fromJson(j['path'] as Map<String, dynamic>),
        data: (j['data'] as Map<String, dynamic>).cast<String, Object?>(),
        receivedAt: DateTime.parse(j['receivedAt'] as String),
      );
}

/// Per-input result for a batch operation. Matches the upstream
/// `BatchItemResult` / `StreamPublishResult` shape (partial-success semantics).
class MeshBatchEntry<T> {
  final int index;
  final bool success;
  final T? value;
  final String? error;

  const MeshBatchEntry({
    required this.index,
    required this.success,
    this.value,
    this.error,
  });
}

class MeshBatchResult<T> {
  final List<MeshBatchEntry<T>> results;
  final int total;
  final int succeeded;
  final int failed;

  const MeshBatchResult({
    required this.results,
    required this.total,
    required this.succeeded,
    required this.failed,
  });
}

// ---------- services --------------------------------------------------------

/// Read/write access to schema-validated **items** on mesh-item-store.
///
/// All calls authenticate as the current AE operator. Schema administration
/// (create / delete data types) is intentionally not exposed — those calls
/// require elevated privilege on the upstream service. Plugins assume the
/// types they target already exist.
abstract class MeshItemService {
  // ---- schema discovery (read-only) ----
  Future<List<MeshDataType>> listDataTypes();
  Future<MeshDataType?> getDataType(MeshDataTypePath path);

  // ---- items CRUD ----

  /// Create a single item under [type]. Returns the assigned id and timestamps.
  Future<MeshItem> createItem(
    MeshDataTypePath type,
    Map<String, Object?> data, {
    Duration? ttl,
  });

  /// Bulk-create. Per-item success/failure is reported via [MeshBatchResult].
  Future<MeshBatchResult<MeshItem>> createItems(
    MeshDataTypePath type,
    List<Map<String, Object?>> data, {
    Duration? ttl,
  });

  /// Fetch a single item or null if not found.
  Future<MeshItem?> getItem(MeshItemPath path);

  /// List all items under [type]. [filter] is forwarded verbatim to the
  /// upstream `util.FilterItemMap`. The dialect is narrow:
  ///
  /// - `created_at` — keep items with created-at **at or after** this
  ///   `"YYYY-MM-DD HH:MM:SS"` value.
  /// - `expiry_time` — keep items with expiry-time **at or before** this value.
  /// - Any other top-level key with a scalar value — exact equality (via
  ///   `fmt.Sprintf("%v", ...)`).
  /// - Any other top-level key with a `Map` value — recursive application of
  ///   the same rules on the nested map.
  ///
  /// There are no operators (`$gt`, `$in`, `$or`), no array matching, no regex.
  Future<List<MeshItem>> listItems(
    MeshDataTypePath type, {
    Map<String, Object?>? filter,
  });

  /// Replace the item at [path]. Validated against the schema.
  Future<MeshItem> updateItem(
    MeshItemPath path,
    Map<String, Object?> data, {
    Duration? ttl,
  });

  Future<void> deleteItem(MeshItemPath path);
}

/// Pub/sub access to mesh-item-store **streams**.
///
/// Subscriptions are **live from now** — no replay, no cursor. Each subscribe
/// opens an SSE channel through the host; the host pushes decoded messages
/// over the JS bridge.
abstract class MeshStreamService {
  // ---- stream-schema discovery (read-only) ----
  Future<List<MeshDataType>> listStreamDataTypes();
  Future<MeshDataType?> getStreamDataType(MeshDataTypePath path);

  // ---- pub/sub ----

  /// Publish [messages] to the stream identified by [type]. Per-message
  /// success/failure is reported via [MeshBatchResult]; the value of a
  /// successful entry is the host-side publish timestamp.
  Future<MeshBatchResult<DateTime>> publish(
    MeshDataTypePath type,
    List<Map<String, Object?>> messages,
  );

  /// Live subscribe. The returned stream emits as messages arrive on the
  /// upstream Flux subscription. Cancel the [StreamSubscription] to tear
  /// down the host-side SSE channel.
  Stream<MeshStreamMessage> subscribe(MeshDataTypePath type);
}

/// Aggregates the two `mesh-item-store` capabilities — schema-validated item
/// CRUD ([items]) and pub/sub streams ([streams]) — under a single accessor
/// on [ExtensionContext]. Both views share the same upstream service, the
/// same auth via the active Lattice connection, and the same data-type
/// addressing ([MeshDataTypePath]); grouping them under one accessor keeps
/// `ExtensionContext` flat and makes the `mesh-item-store` boundary obvious
/// at the API surface.
abstract class MeshItemStoreService {
  /// Schema-validated item CRUD.
  MeshItemService get items;

  /// Pub/sub streams.
  MeshStreamService get streams;
}
