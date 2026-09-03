import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:recovery_ops/domain/entities/recoveryReport.dart';
import 'package:recovery_ops/domain/repositories/reportsRepo.dart';
import 'package:recovery_ops/domain/services/remoteReportSource.dart';

class GeometryUpdate {
  final int index;
  final RecoveryReport updatedReport;

  GeometryUpdate(this.index, this.updatedReport);
}

class PollRouteGeometry {
  final RemoteReportSource source;
  final ReportsRepository repository;

  PollRouteGeometry(this.source, this.repository);

  Future<List<GeometryUpdate>> call(List<RecoveryReport> reports) async {
    final updates = <GeometryUpdate>[];

    for (var i = 0; i < reports.length; i++) {
      final report = reports[i];
      if (report.hasGeometry) continue;
      if (report.entityId == null || report.entityId!.isEmpty) continue;

      try {
        final geometry = await source.fetchEntityGeometry(report.entityId!);
        if (geometry != null && geometry.isNotEmpty) {
          final updated = report.copyWith(routeGeometry: geometry);
          if (report.id != null) {
            final json = jsonEncode(
              geometry
                  .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                  .toList(),
            );
            repository.updateRouteGeometry(report.id!, json);
          }
          updates.add(GeometryUpdate(i, updated));
        }
      } catch (e) {
        debugPrint(
            '[RecoveryOps] geometry poll error for ${report.entityId}: $e');
      }
    }
    return updates;
  }
}
