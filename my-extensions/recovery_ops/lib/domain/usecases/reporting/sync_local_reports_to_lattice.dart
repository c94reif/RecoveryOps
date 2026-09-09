import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/entities/recovery_report.dart';
import 'package:recovery_ops/domain/services/recovery_entity_port.dart';
import 'package:recovery_ops/domain/services/remote_report_source.dart';

class SyncLocalReportsToLattice {
  final RemoteReportSource source;
  final RecoveryEntityPort entityPort;

  SyncLocalReportsToLattice(this.source, this.entityPort);

  Future<List<String>> call(List<RecoveryReport> localReports) async {
    try {
      final knownIds = await source.fetchKnownRecoveryEntityIds();

      final pushed = <String>[];
      for (final report in localReports) {
        if (!report.isOutgoing) continue;
        final entityId = report.entityId;
        if (entityId == null || entityId.isEmpty) continue;
        if (knownIds.contains(entityId)) continue;

        final ok = await _push(entityId, report);
        if (ok) pushed.add(entityId);
      }
      return pushed;
    } catch (e) {
      debugPrint('[RecoveryOps] SyncLocalReportsToLattice error: $e');
      return const [];
    }
  }

  Future<bool> _push(String entityId, RecoveryReport report) async {
    try {
      final navLat = report.navigatorLatitude;
      final navLng = report.navigatorLongitude;
      final hasNavigator = navLat != null && navLng != null;

      if (hasNavigator) {
        return await entityPort.publishNavigatorEntity(
          entityId: entityId,
          bumperNumber: report.bumperNumber,
          issue: report.issue,
          typeName: report.recoveryType,
          vehiclePosition: LatLng(report.latitude, report.longitude),
          navigatorPosition: LatLng(navLat, navLng),
          routeGeometry: report.routeGeometry,
        );
      }

      return await entityPort.publishRecoveryEntity(
        entityId: entityId,
        bumperNumber: report.bumperNumber,
        issue: report.issue,
        typeName: report.recoveryType,
        position: LatLng(report.latitude, report.longitude),
      );
    } catch (e) {
      debugPrint(
          '[RecoveryOps] SyncLocalReportsToLattice push error for $entityId: $e');
      return false;
    }
  }
}
