import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/data/dao/reports/reports_dao.dart';
import 'package:recovery_ops/domain/entities/recovery_report.dart';
import 'package:recovery_ops/domain/repositories/reports_repo.dart';

class ReportsRepoImpl implements ReportsRepository {
  final ReportsDao dao;

  ReportsRepoImpl(this.dao);

  @override
  Future<List<RecoveryReport>> getAllReports() async {
    final rows = await dao.getAllReports();
    return rows
        .map((r) => RecoveryReport(
              id: r.id,
              entityId: r.entityId,
              fromCallsign: r.fromCallsign,
              bumperNumber: r.bumperNumber,
              issue: r.issue,
              recoveryType: r.recoveryType,
              latitude: r.latitude,
              longitude: r.longitude,
              navigatorLatitude: r.navigatorLatitude,
              navigatorLongitude: r.navigatorLongitude,
              routeGeometry: parseGeometry(r.routeGeometry),
              timestamp: r.timestamp,
              isOutgoing: r.isOutgoing,
              isRead: r.isRead,
            ))
        .toList();
  }

  @override
  Future<void> insertReport(RecoveryReport report) async {
    await dao.insertReport(
      entityId: report.entityId,
      fromCallsign: report.fromCallsign,
      bumperNumber: report.bumperNumber,
      issue: report.issue,
      recoveryType: report.recoveryType,
      latitude: report.latitude,
      longitude: report.longitude,
      navigatorLatitude: report.navigatorLatitude,
      navigatorLongitude: report.navigatorLongitude,
      timestamp: report.timestamp,
      isOutgoing: report.isOutgoing,
      isRead: report.isRead,
    );
  }

  @override
  Future<void> updateNavigatorLocation(
      int id, double latitude, double longitude) async {
    await dao.updateNavigatorLocation(id, latitude, longitude);
  }

  @override
  Future<void> clearNavigatorLocation(int id) async {
    await dao.clearNavigatorLocation(id);
  }

  @override
  Future<void> markAsRead(int id) async {
    await dao.markAsRead(id);
  }

  @override
  Future<void> markAllAsRead() async {
    await dao.markAllAsRead();
  }

  @override
  Future<void> updateRouteGeometry(int id, String geometryJson) async {
    await dao.updateRouteGeometry(id, geometryJson);
  }

  @override
  Future<void> deleteReport(int id) async {
    await dao.deleteReport(id);
  }

  static List<LatLng>? parseGeometry(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((p) => LatLng(
                (p['lat'] as num).toDouble(),
                (p['lng'] as num).toDouble(),
              ))
          .toList();
    } catch (_) {
      return null;
    }
  }
}
