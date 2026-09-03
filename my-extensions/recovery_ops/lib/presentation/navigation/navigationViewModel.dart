import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/entities/recoveryReport.dart';
import 'package:recovery_ops/domain/usecases/navigation/broadcastNavigatorLocation.dart';
import 'package:recovery_ops/domain/usecases/navigation/navigateToReport.dart';
import 'package:recovery_ops/domain/usecases/navigation/publishNavigationStopped.dart';
import 'package:recovery_ops/domain/usecases/navigation/publishNavigatorEntity.dart';

class NavigationViewModel extends ChangeNotifier {
  final sdk.LocationService location;
  final NavigateToReport navigateToReport;
  final BroadcastNavigatorLocation broadcastNavigatorLocationUseCase;
  final PublishNavigatorEntity publishNavigatorEntityUseCase;
  final PublishNavigationStopped publishNavigationStoppedUseCase;

  Timer? navigationBroadcastTimer;
  Timer? latticeEntityTimer;
  static const broadcastInterval = Duration(seconds: 30);
  static const latticeEntityInterval = Duration(minutes: 3);

  LatLng? currentLocation;
  RecoveryReport? navigatingReport;
  String activeRouteId = '';
  String? navigatingEntityId;

  NavigationViewModel(
    this.location,
    this.navigateToReport,
    this.broadcastNavigatorLocationUseCase,
    this.publishNavigatorEntityUseCase,
    this.publishNavigationStoppedUseCase,
  );

  bool get isNavigating => navigatingEntityId != null;
  bool get hasLocation => currentLocation != null;

  Future<void> refreshLocation() async {
    final loc = await location.getCurrentLocation();
    if (loc != null) {
      currentLocation = LatLng(loc.latitude, loc.longitude);
      notifyListeners();
    }
  }

  Future<RecoveryReport?> navigateTo(RecoveryReport report) async {
    await refreshLocation();
    if (currentLocation == null) return null;

    final result = await navigateToReport(
      report,
      currentLocation!,
      activeMarkerId: null,
      activeRouteId: activeRouteId,
    );

    activeRouteId = result.routeId;
    navigatingEntityId = report.entityId;
    navigatingReport = result.updatedReport;

    startNavigationUpdates(report);
    notifyListeners();
    return result.updatedReport;
  }

  void stopNavigation() {
    broadcastNavigationStopped();
    navigatingEntityId = null;
    navigatingReport = null;
    stopNavigationUpdates();
    notifyListeners();
  }

  void clearNavigation() {
    broadcastNavigationStopped();
    activeRouteId = '';
    navigatingEntityId = null;
    navigatingReport = null;
    stopNavigationUpdates();
    notifyListeners();
  }

  void broadcastNavigationStopped() {
    final entityId = navigatingEntityId;
    if (entityId != null) {
      publishNavigationStoppedUseCase(entityId: entityId);
    }
  }

  void startNavigationUpdates(RecoveryReport report) {
    stopNavigationUpdates();
    if (report.entityId == null || report.entityId!.isEmpty) return;

    navigationBroadcastTimer = Timer.periodic(
      broadcastInterval,
      (_) => broadcastNavigatorLocation(report),
    );
    latticeEntityTimer = Timer.periodic(
      latticeEntityInterval,
      (_) => publishNavigatorToLattice(report),
    );
  }

  void stopNavigationUpdates() {
    navigationBroadcastTimer?.cancel();
    navigationBroadcastTimer = null;
    latticeEntityTimer?.cancel();
    latticeEntityTimer = null;
  }

  Future<void> broadcastNavigatorLocation(RecoveryReport report) async {
    await refreshLocation();
    if (currentLocation == null) return;

    try {
      await broadcastNavigatorLocationUseCase(
        entityId: report.entityId!,
        navigatorPosition: currentLocation!,
        routeGeometry: report.routeGeometry,
      );
    } catch (e) {
      debugPrint('[RecoveryOps] Periodic navigator broadcast error: $e');
    }
  }

  Future<void> publishNavigatorToLattice(RecoveryReport report) async {
    await refreshLocation();
    if (currentLocation == null) return;

    try {
      await publishNavigatorEntityUseCase(
        entityId: report.entityId!,
        bumperNumber: report.bumperNumber,
        issue: report.issue,
        typeName: report.recoveryType,
        vehiclePosition: LatLng(report.latitude, report.longitude),
        navigatorPosition: currentLocation!,
        routeGeometry: report.routeGeometry,
      );
    } catch (e) {
      debugPrint('[RecoveryOps] Periodic navigator Lattice update error: $e');
    }
  }

  @override
  void dispose() {
    stopNavigationUpdates();
    super.dispose();
  }
}
