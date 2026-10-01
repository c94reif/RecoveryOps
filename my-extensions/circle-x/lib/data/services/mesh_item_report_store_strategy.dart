import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/core/config/report_store_config.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/data/services/mesh_report_collection.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/services/report_store_strategy.dart';

class MeshItemReportStoreStrategy implements ReportStoreStrategy {
  final MeshReportCollection collection;
  final PmcsReportCodec codec;

  MeshItemReportStoreStrategy(
      {required sdk.MeshItemService items,
      sdk.MeshDataTypePath type = ReportStoreConfig.itemType,
      this.codec = const PmcsReportCodec()})
      : collection = MeshReportCollection(items: items, type: type);

  @override
  Future<bool> publishPmcsReport(PmcsReport report) =>
      _write(() => collection.save(report.entityId, codec.reportBody(report)));

  @override
  Future<bool> publishEncodedReport(
      {required String entityId,
      required String payload,
      required LatLng position}) async {
    final report = codec.decodeReport(payload, fromCallsign: 'Mesh item store');
    if (report == null || report.entityId != entityId) return false;
    return publishPmcsReport(report);
  }

  @override
  Future<bool> deletePmcsEntity(String entityId) =>
      _write(() => collection.withdraw(entityId));

  @override
  Future<List<PmcsReport>> fetchRemotePmcsReports() async {
    final records = await collection.snapshot();
    final reports = <PmcsReport>[];
    for (final entry in records.entries) {
      final report = _readReport(entry.key, entry.value);
      if (report != null) reports.add(report);
    }
    return reports;
  }

  @override
  Future<Set<String>> fetchKnownPmcsEntityIds() async => {
        for (final entry in (await collection.snapshot()).entries)
          if (MeshReportCollection.withdrawn(entry.value) ||
              _readReport(entry.key, entry.value) != null)
            entry.key,
      };

  // Import and reconciliation must agree about which live records are usable.
  // Withdrawals stay known even when no report body can be decoded.
  PmcsReport? _readReport(String reportId, sdk.MeshItem item) {
    if (item.data['withdrawn'] != false) return null;
    final body = MeshReportCollection.body(item);
    if (body == null || body['entityId'] != reportId) return null;
    return codec.reportFromBody(body, fromCallsign: 'Mesh item store');
  }

  @override
  Future<Set<String>> fetchWithdrawnPmcsEntityIds() async => {
        for (final entry in (await collection.snapshot()).entries)
          if (MeshReportCollection.withdrawn(entry.value)) entry.key,
      };

  Future<bool> _write(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (error) {
      debugPrint('[CircleX] Mesh item store: $error');
      return false;
    }
  }
}
