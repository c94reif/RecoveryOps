import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/core/config/report_store_config.dart';
import 'package:recovery_ops/data/mappers/recovery_item_mapper.dart';
import 'package:recovery_ops/data/services/mesh_report_collection.dart';
import 'package:recovery_ops/domain/entities/recovery_report.dart';
import 'package:recovery_ops/domain/services/report_store_strategy.dart';
import 'package:recovery_ops/domain/usecases/navigation/parse_navigator_update.dart';

class MeshItemReportStoreStrategy
    implements ReportStoreStrategy, NavigatorStateStore {
  final MeshReportCollection collection;
  final RecoveryItemMapper mapper;

  MeshItemReportStoreStrategy(
      {required sdk.MeshItemService items,
      sdk.MeshDataTypePath type = ReportStoreConfig.itemType,
      this.mapper = const RecoveryItemMapper()})
      : collection = MeshReportCollection(items: items, type: type);

  @override
  Future<bool> publishRecoveryEntity(
          {required String entityId,
          required String bumperNumber,
          required String issue,
          required String typeName,
          required LatLng position}) =>
      _write(() => collection.save(
          entityId,
          mapper.body(
              entityId: entityId,
              bumperNumber: bumperNumber,
              issue: issue,
              typeName: typeName,
              position: position),
          merge: true));

  @override
  Future<bool> publishNavigatorEntity(
          {required String entityId,
          required String bumperNumber,
          required String issue,
          required String typeName,
          required LatLng vehiclePosition,
          required LatLng navigatorPosition,
          List<LatLng>? routeGeometry}) =>
      _write(() => collection.save(
          entityId,
          {
            ...mapper.body(
                entityId: entityId,
                bumperNumber: bumperNumber,
                issue: issue,
                typeName: typeName,
                position: vehiclePosition),
            'navigatorLatitude': navigatorPosition.latitude,
            'navigatorLongitude': navigatorPosition.longitude,
            'navigationStopped': false,
            if (routeGeometry != null)
              'routeGeometry': [
                for (final p in routeGeometry) [p.latitude, p.longitude]
              ],
          },
          merge: true));

  @override
  Future<bool> stopNavigator(String entityId) =>
      _write(() => collection.patch(entityId, {
            'navigatorLatitude': null,
            'navigatorLongitude': null,
            'routeGeometry': null,
            'navigationStopped': true,
          }));

  @override
  Future<bool> deleteRecoveryEntity(String entityId) =>
      _write(() => collection.withdraw(entityId));

  @override
  Future<List<RecoveryReport>> fetchRemoteRecoveryReports() async {
    final records = await collection.snapshot();
    final reports = <RecoveryReport>[];
    for (final entry in records.entries) {
      if (MeshReportCollection.withdrawn(entry.value)) continue;
      final report = mapper.parse(entry.key,
          MeshReportCollection.body(entry.value), entry.value.createdAt);
      if (report != null) reports.add(report);
    }
    return reports;
  }

  @override
  Future<Set<String>> fetchKnownRecoveryEntityIds() async =>
      (await collection.snapshot()).keys.toSet();

  @override
  Future<Set<String>> fetchWithdrawnRecoveryEntityIds() async => {
        for (final entry in (await collection.snapshot()).entries)
          if (MeshReportCollection.withdrawn(entry.value)) entry.key,
      };

  @override
  Future<NavigatorUpdate?> fetchNavigatorState(String entityId) async {
    final item = (await collection.snapshot())[entityId];
    if (item == null || MeshReportCollection.withdrawn(item)) return null;
    final body = MeshReportCollection.body(item);
    if (body?['entityId'] != entityId) return null;
    if (body?['navigationStopped'] == true) {
      return NavigatorUpdate.stopped(entityId: entityId);
    }
    final report = mapper.parse(entityId, body, item.createdAt);
    if (report?.navigatorLatitude == null ||
        report?.navigatorLongitude == null) {
      return null;
    }
    return NavigatorUpdate(
        entityId: entityId,
        navigatorLatitude: report!.navigatorLatitude!,
        navigatorLongitude: report.navigatorLongitude!,
        routeGeometry: report.routeGeometry);
  }

  @override
  Future<List<LatLng>?> fetchEntityGeometry(String entityId) async {
    final item = (await collection.snapshot())[entityId];
    if (item == null || MeshReportCollection.withdrawn(item)) return null;
    return mapper
        .parse(entityId, MeshReportCollection.body(item), item.createdAt)
        ?.routeGeometry;
  }

  Future<bool> _write(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (error) {
      debugPrint('[RecoveryOps] Mesh item store: $error');
      return false;
    }
  }
}
