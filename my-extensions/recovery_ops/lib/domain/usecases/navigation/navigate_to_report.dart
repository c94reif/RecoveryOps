import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/entities/recovery_report.dart';
import 'package:recovery_ops/domain/repositories/reports_repo.dart';
import 'package:recovery_ops/domain/usecases/navigation/broadcast_navigator_location.dart';
import 'package:recovery_ops/domain/usecases/navigation/publish_navigator_entity.dart';

class NavigateToReportResult {
  final String routeId;
  final RecoveryReport updatedReport;

  NavigateToReportResult({
    required this.routeId,
    required this.updatedReport,
  });
}

class NavigateToReport {
  final sdk.MapService map;
  final ReportsRepository repository;
  final BroadcastNavigatorLocation broadcastNavigatorLocation;
  final PublishNavigatorEntity publishNavigatorEntity;

  NavigateToReport(
    this.map,
    this.repository,
    this.broadcastNavigatorLocation,
    this.publishNavigatorEntity,
  );

  Future<NavigateToReportResult> call(
    RecoveryReport report,
    LatLng currentLocation, {
    String? activeMarkerId,
    String activeRouteId = '',
  }) async {
    if (activeMarkerId != null) {
      await map.removeMarker(activeMarkerId);
    }
    if (activeRouteId.isNotEmpty) {
      await map.removePolyline(activeRouteId);
    }

    final dest = sdk.LatLng(report.latitude, report.longitude);
    final origin =
        sdk.LatLng(currentLocation.latitude, currentLocation.longitude);

    final routeId = 'nav-${DateTime.now().millisecondsSinceEpoch}';

    final List<sdk.LatLng> polylinePoints;
    if (report.hasGeometry) {
      polylinePoints = report.routeGeometry!
          .map((p) => sdk.LatLng(p.latitude, p.longitude))
          .toList();
    } else {
      polylinePoints = [origin, dest];
    }

    await map.addPolyline(routeId, polylinePoints,
        color: report.hasGeometry ? '#FF8C00' : '#4A7820');

    await fitBounds(polylinePoints);

    final updatedReport = report.copyWith(
      navigatorLatitude: currentLocation.latitude,
      navigatorLongitude: currentLocation.longitude,
    );
    if (report.id != null) {
      repository.updateNavigatorLocation(
        report.id!,
        currentLocation.latitude,
        currentLocation.longitude,
      );
    }

    if (report.entityId != null && report.entityId!.isNotEmpty) {
      broadcastNavigatorLocation
          .call(
            entityId: report.entityId!,
            navigatorPosition: currentLocation,
            routeGeometry: report.routeGeometry,
          )
          .then((_) => debugPrint('[RecoveryOps] Navigator broadcast sent'))
          .catchError(
              (e) => debugPrint('[RecoveryOps] Navigator broadcast error: $e'));

      publishNavigatorEntity
          .call(
            entityId: report.entityId!,
            bumperNumber: report.bumperNumber,
            issue: report.issue,
            typeName: report.recoveryType,
            vehiclePosition: LatLng(report.latitude, report.longitude),
            navigatorPosition: currentLocation,
            routeGeometry: report.routeGeometry,
          )
          .then((_) => debugPrint('[RecoveryOps] Navigator entity published'))
          .catchError(
              (e) => debugPrint('[RecoveryOps] Navigator entity error: $e'));
    }

    return NavigateToReportResult(
      routeId: routeId,
      updatedReport: updatedReport,
    );
  }

  Future<void> fitBounds(List<sdk.LatLng> points) async {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final midLat = (minLat + maxLat) / 2;
    final midLng = (minLng + maxLng) / 2;
    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final span = max(latSpan, lngSpan);
    final zoom =
        span > 0 ? (log(360 / (span * 2.5)) / ln2).clamp(2.0, 18.0) : 15.0;
    await map.flyTo(sdk.LatLng(midLat, midLng), zoom: zoom);
  }
}
