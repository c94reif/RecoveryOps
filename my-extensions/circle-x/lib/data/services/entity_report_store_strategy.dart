import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/data/services/lattice_pmcs_adapter.dart';
import 'package:circle_x/data/services/lattice_report_source.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/services/report_store_strategy.dart';

/// Retains the original entity implementation as an explicitly selected strategy.
class EntityReportStoreStrategy implements ReportStoreStrategy {
  final LatticePmcsAdapter writer;
  final LatticeReportSource reader;

  EntityReportStoreStrategy(sdk.EntityService entities)
      : writer = LatticePmcsAdapter(entities: entities),
        reader = LatticeReportSource(entities: entities);

  @override
  Future<bool> publishPmcsReport(PmcsReport report) =>
      writer.publishPmcsReport(report);

  @override
  Future<bool> publishEncodedReport(
          {required String entityId,
          required String payload,
          required LatLng position}) =>
      writer.publishEncodedReport(
          entityId: entityId, payload: payload, position: position);

  @override
  Future<bool> deletePmcsEntity(String entityId) =>
      writer.deletePmcsEntity(entityId);

  @override
  Future<List<PmcsReport>> fetchRemotePmcsReports() =>
      reader.fetchRemotePmcsReports();

  @override
  Future<Set<String>> fetchKnownPmcsEntityIds() =>
      reader.fetchKnownPmcsEntityIds();

  @override
  Future<Set<String>> fetchWithdrawnPmcsEntityIds() =>
      reader.fetchWithdrawnPmcsEntityIds();
}
