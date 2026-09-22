import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:ivy_pulse/data/dao/reports/pmcs_reports_dao.dart';
import 'package:ivy_pulse/data/repositories/sessions_repo_impl.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/repositories/reports_repo.dart';

class ReportsRepoImpl implements ReportsRepository {
  final PmcsReportsDao dao;

  ReportsRepoImpl(this.dao);

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
      phases: encodePhases(report.phases),
      faultsJson: encodeFaults(report.faults),
      signatureJson: SessionsRepoImpl.encodeSignature(report.signature),
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

  /// Null when the row names a platform this build does not know — the report
  /// is left on disk, but one unreadable row must not take the whole list with
  /// it. The rest of the decoding is tolerant for the same reason.
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
      phases: decodePhases(row.phases),
      faults: decodeFaults(row.entityId, row.faultsJson),
      signature: SessionsRepoImpl.decodeSignature(row.signatureJson),
      latitude: row.latitude,
      longitude: row.longitude,
      timestamp: row.timestamp,
      isOutgoing: row.isOutgoing,
      isRead: row.isRead,
    );
  }

  static String encodePhases(List<PmcsPhase> phases) =>
      phases.map((p) => p.wireName).join(',');

  static List<PmcsPhase> decodePhases(String value) {
    if (value.isEmpty) return const [];
    return value
        .split(',')
        .map(PmcsPhase.tryFromWireName)
        .whereType<PmcsPhase>()
        .toList();
  }

  static String encodeFaults(List<PmcsFault> faults) =>
      jsonEncode(faults.map((f) => f.toMap()).toList());

  /// A received report's faults belong to the *sender's* session, which only
  /// reaches us as the entity id — so that is what they are re-keyed to.
  /// A malformed blob costs the fault detail, never the whole report.
  static List<PmcsFault> decodeFaults(String entityId, String json) {
    if (json.isEmpty) return const [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((f) => PmcsFault.fromMap(entityId, f as Map<String, Object?>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
