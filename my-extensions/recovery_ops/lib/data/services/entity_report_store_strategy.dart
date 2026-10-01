import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/data/mappers/recovery_entity_mapper.dart';
import 'package:recovery_ops/data/services/lattice_entity_adapter.dart';
import 'package:recovery_ops/data/services/lattice_report_source.dart';
import 'package:recovery_ops/domain/entities/recovery_report.dart';
import 'package:recovery_ops/domain/services/report_store_strategy.dart';
import 'package:recovery_ops/domain/usecases/navigation/parse_navigator_update.dart';

class EntityReportStoreStrategy implements ReportStoreStrategy {
  final sdk.EntityService entities;
  final LatticeEntityAdapter writer;
  final LatticeReportSource reader;

  EntityReportStoreStrategy(this.entities)
      : writer = LatticeEntityAdapter(entities: entities),
        reader = LatticeReportSource(entities: entities);

  @override
  Future<bool> publishRecoveryEntity(
          {required String entityId,
          required String bumperNumber,
          required String issue,
          required String typeName,
          required LatLng position}) =>
      writer.publishRecoveryEntity(
          entityId: entityId,
          bumperNumber: bumperNumber,
          issue: issue,
          typeName: typeName,
          position: position);

  @override
  Future<bool> publishNavigatorEntity(
          {required String entityId,
          required String bumperNumber,
          required String issue,
          required String typeName,
          required LatLng vehiclePosition,
          required LatLng navigatorPosition,
          List<LatLng>? routeGeometry}) =>
      writer.publishNavigatorEntity(
          entityId: entityId,
          bumperNumber: bumperNumber,
          issue: issue,
          typeName: typeName,
          vehiclePosition: vehiclePosition,
          navigatorPosition: navigatorPosition,
          routeGeometry: routeGeometry);

  @override
  Future<bool> deleteRecoveryEntity(String entityId) =>
      writer.deleteRecoveryEntity(entityId);

  @override
  Future<List<RecoveryReport>> fetchRemoteRecoveryReports() =>
      reader.fetchRemoteRecoveryReports();

  @override
  Future<Set<String>> fetchKnownRecoveryEntityIds() =>
      reader.fetchKnownRecoveryEntityIds();

  @override
  Future<NavigatorUpdate?> fetchNavigatorState(String entityId) =>
      reader.fetchNavigatorState(entityId);

  @override
  Future<List<LatLng>?> fetchEntityGeometry(String entityId) =>
      reader.fetchEntityGeometry(entityId);

  @override
  Future<Set<String>> fetchWithdrawnRecoveryEntityIds() async => {
        for (final entity in await entities.getEntities())
          if (const RecoveryEntityMapper().isOwnedRecoveryEntity(entity) &&
              entity.isLive == false)
            entity.id,
      };
}
