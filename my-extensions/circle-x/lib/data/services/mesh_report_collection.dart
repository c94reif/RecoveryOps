import 'dart:async';

import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/core/constants/app_constants.dart';

/// Resolves stable report IDs to server-assigned item paths on every write.
/// Kept inside each extension so its source package remains self-contained.
class MeshReportCollection {
  final sdk.MeshItemService items;
  final sdk.MeshDataTypePath type;
  final Duration requestTimeout;
  final Map<String, Future<void>> _pending = {};

  MeshReportCollection({
    required this.items,
    required this.type,
    this.requestTimeout = AppConstants.transportRequestTimeout,
  });

  Future<List<sdk.MeshItem>> _list() async {
    // Do not interpret an unavailable/unregistered collection as an empty one.
    if (await items.getDataType(type).timeout(requestTimeout) == null) {
      throw StateError('Register mesh item schema '
          '${type.namespace}/${type.domain}/${type.dataType}/${type.version}');
    }
    // Read the typed collection, without relying on upstream filter dialects.
    return items.listItems(type).timeout(requestTimeout);
  }

  /// Withdrawal records are immutable and dominate all live duplicates.
  Future<Map<String, sdk.MeshItem>> snapshot() async {
    final records = <String, sdk.MeshItem>{};
    for (final item in await _list()) {
      if (!_sameType(item.path.type)) continue;
      final id = item.data['reportId'];
      if (id is! String || id.isEmpty) continue;
      final previous = records[id];
      if (previous == null || _compare(item, previous) > 0) records[id] = item;
    }
    return records;
  }

  static bool withdrawn(sdk.MeshItem item) => item.data['withdrawn'] == true;

  static Map<String, Object?>? body(sdk.MeshItem? item) {
    final value = item?.data['report'];
    return value is Map ? value.cast<String, Object?>() : null;
  }

  Future<void> save(String reportId, Map<String, Object?> report,
          {bool merge = false, String? sourceReportId}) =>
      _serial(reportId, () async {
        final records = await snapshot();
        final existing = records[reportId];
        if (existing != null && withdrawn(existing)) return;
        // A queued review can run before this device imports remote withdrawals.
        // Check its source in this same snapshot before persisting the review.
        final source = records[sourceReportId];
        if (source != null && withdrawn(source)) return;
        final bodyToSave = <String, Object?>{
          if (merge) ...?body(existing),
          ...report,
        };
        final updatedAt = existing?.data['updatedAt'];
        if (existing != null &&
            existing.data['withdrawn'] == false &&
            updatedAt is String &&
            DateTime.tryParse(updatedAt) != null &&
            _equal(body(existing), bodyToSave)) {
          // Another relay may already have committed this immutable report.
          // Verify it without rewriting updatedAt or producing replication churn.
          await _verify(existing, existing.data);
          return;
        }
        final data = <String, Object?>{
          'reportId': reportId,
          'withdrawn': false,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'report': bodyToSave,
        };
        final saved = existing == null
            ? await items.createItem(type, data).timeout(requestTimeout)
            : await items
                .updateItem(existing.path, data)
                .timeout(requestTimeout);
        await _verify(saved, data);
      });

  Future<void> withdraw(String reportId) => _serial(reportId, () async {
        final existing = (await snapshot())[reportId];
        if (existing != null && withdrawn(existing)) return;
        // Never replace the live item: an in-flight update on another device
        // must not overwrite the withdrawal. No TTL on either record type.
        final data = <String, Object?>{
          'reportId': reportId,
          'withdrawn': true,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        };
        final saved =
            await items.createItem(type, data).timeout(requestTimeout);
        await _verify(saved, data);
      });

  Future<void> _verify(sdk.MeshItem saved, Map<String, Object?> data) async {
    if (saved.path.id.isEmpty || !_sameType(saved.path.type)) {
      throw StateError('Mesh item store returned an invalid item path');
    }
    final persisted = await items.getItem(saved.path).timeout(requestTimeout);
    if (persisted == null || !_equal(persisted.data, data)) {
      throw StateError('Mesh item store did not persist the report');
    }
  }

  bool _sameType(sdk.MeshDataTypePath other) =>
      other.namespace == type.namespace &&
      other.domain == type.domain &&
      other.dataType == type.dataType &&
      other.version == type.version;

  int _compare(sdk.MeshItem a, sdk.MeshItem b) {
    if (withdrawn(a) != withdrawn(b)) return withdrawn(a) ? 1 : -1;
    final aTime = _updatedAt(a);
    final bTime = _updatedAt(b);
    final time = aTime.compareTo(bTime);
    return time != 0 ? time : a.path.id.compareTo(b.path.id);
  }

  DateTime _updatedAt(sdk.MeshItem item) {
    final raw = item.data['updatedAt'];
    return (raw is String ? DateTime.tryParse(raw) : null) ?? item.createdAt;
  }

  bool _equal(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every((key) => b.containsKey(key) && _equal(a[key], b[key]));
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(a.length, (i) => i).every((i) => _equal(a[i], b[i]));
    }
    return a == b;
  }

  Future<void> _serial(String id, Future<void> Function() operation) async {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'reportId', 'must not be empty');
    }
    final previous = _pending[id] ?? Future<void>.value();
    final done = Completer<void>();
    _pending[id] = done.future;
    await previous;
    try {
      await operation();
    } finally {
      // A timed-out bridge write may still commit. Release the local lock so a
      // retry can resolve the stable report ID and verify the remote outcome.
      done.complete();
      if (identical(_pending[id], done.future)) _pending.remove(id);
    }
  }
}
