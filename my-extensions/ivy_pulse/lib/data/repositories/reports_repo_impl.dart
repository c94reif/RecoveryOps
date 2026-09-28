import 'package:ivy_pulse/data/mappers/pmcs_storage_codec.dart';

import 'package:flutter/foundation.dart';

import 'package:ivy_pulse/data/dao/reports/pmcs_reports_dao.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/repositories/reports_repo.dart';

class ReportsRepoImpl implements ReportsRepository {
  final PmcsReportsDao dao;

  ReportsRepoImpl(this.dao);

  @override
  Future<Set<String>> getDismissedFaultSuggestions() =>
      dao.getDismissedFaultSuggestions();

  @override
  Future<void> setFaultSuggestionDismissed(String id, bool dismissed) =>
      dao.setFaultSuggestionDismissed(id, dismissed);

  @override
  Future<List<PmcsReport>> getAllReports() async {
    final rows = await dao.getAllReports();
    final reports = rows.map(toEntity).whereType<PmcsReport>().toList();
    if (reports.length != rows.length) {
      debugPrint('[IvyPulse] getAllReports: skipped '
          '${rows.length - reports.length} row(s) for an unknown platform');
    }
    return reports;
  }

  @override
  Future<PmcsReport> insertReport(PmcsReport report) async {
    final id = await dao.insertReport(
      entityId: report.entityId,
      fromCallsign: report.fromCallsign,
      bumperNumber: report.bumperNumber,
      vehicleType: report.vehicleType.wireName,
      operator: report.operator,
      uic: report.uic,
      phases: PmcsStorageCodec.encodePhases(report.phases),
      faultsJson: PmcsStorageCodec.encodeFaults(report.faults),
      signatureJson: PmcsStorageCodec.encodeSignature(report.signature),
      latitude: report.latitude,
      longitude: report.longitude,
      timestamp: report.timestamp,
      isOutgoing: report.isOutgoing,
      isRead: report.isRead,
    );
    final stored = toEntity(await dao.getById(id));
    if (stored == null) {
      throw StateError('Stored report uses an unknown platform');
    }
    return stored;
  }

  @override
  Future<void> markAsRead(int id) => dao.markAsRead(id);

  @override
  Future<void> markAllAsRead() => dao.markAllAsRead();

  @override
  Future<void> deleteReport(int id) => dao.deleteReport(id);

  @override
  Future<Set<String>> getWithdrawnIds() => dao.getWithdrawnIds();

  @override
  Future<void> withdrawReport(String entityId) => dao.withdrawReport(entityId);

  static PmcsReport? toEntity(PmcsReportData row) {
    final vehicleType = VehicleType.tryFromWireName(row.vehicleType);
    if (vehicleType == null) return null;

    return PmcsReport(
      id: row.id,
      entityId: row.entityId,
      fromCallsign: row.fromCallsign,
      bumperNumber: row.bumperNumber,
      vehicleType: vehicleType,
      operator: row.operator,
      uic: row.uic,
      phases: PmcsStorageCodec.decodePhases(row.phases),
      faults: PmcsStorageCodec.decodeFaults(row.entityId, row.faultsJson),
      signature: PmcsStorageCodec.decodeSignature(row.signatureJson),
      latitude: row.latitude,
      longitude: row.longitude,
      timestamp: row.timestamp,
      isOutgoing: row.isOutgoing,
      isRead: row.isRead,
    );
  }
}
