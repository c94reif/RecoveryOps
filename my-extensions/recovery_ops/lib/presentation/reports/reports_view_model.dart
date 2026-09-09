import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/entities/recovery_report.dart';
import 'package:recovery_ops/domain/repositories/reports_repo.dart';
import 'package:recovery_ops/domain/usecases/recovery/publish_recovery_deletion.dart';
import 'package:recovery_ops/domain/usecases/reporting/parse_incoming_deletion.dart';
import 'package:recovery_ops/domain/usecases/reporting/parse_incoming_report.dart';
import 'package:recovery_ops/domain/usecases/reporting/sync_local_reports_to_lattice.dart';
import 'package:recovery_ops/domain/usecases/reporting/sync_remote_reports.dart';
import 'package:recovery_ops/domain/usecases/navigation/view_report_on_map.dart';
import 'package:recovery_ops/domain/usecases/navigation/parse_navigator_update.dart';
import 'package:recovery_ops/domain/usecases/navigation/poll_route_geometry.dart';
import 'package:recovery_ops/domain/usecases/navigation/sync_navigator_states.dart';
import 'package:recovery_ops/presentation/common/widgets/custom_snack_bar.dart';
import 'package:recovery_ops/presentation/navigation/navigation_view_model.dart';

export 'package:recovery_ops/domain/entities/recovery_report.dart';

enum DistanceBracket {
  under1km('< 1 km'),
  from1to2km('1 - 2 km'),
  from2to5km('2 - 5 km'),
  from5to10km('5 - 10 km'),
  from10to20km('10 - 20 km'),
  over20km('20+ km'),
  unknown('Unknown distance');

  const DistanceBracket(this.label);
  final String label;

  static DistanceBracket fromKm(double? km) {
    if (km == null) return unknown;
    if (km < 1) return under1km;
    if (km < 2) return from1to2km;
    if (km < 5) return from2to5km;
    if (km < 10) return from5to10km;
    if (km < 20) return from10to20km;
    return over20km;
  }
}

class ReportsViewModel extends ChangeNotifier {
  final sdk.MessagingService messaging;
  final ReportsRepository repository;
  final ParseIncomingReport parseIncomingReport;
  final ParseIncomingDeletion parseIncomingDeletion;
  final ViewReportOnMap viewReportOnMap;
  final ParseNavigatorUpdate parseNavigatorUpdate;
  final PollRouteGeometry pollRouteGeometry;
  final SyncRemoteReports syncRemoteReports;
  final SyncLocalReportsToLattice syncLocalReportsToLattice;
  final SyncNavigatorStates syncNavigatorStates;
  final sdk.MapService mapService;
  final NavigationViewModel navigationViewModel;
  final PublishRecoveryDeletion publishRecoveryDeletion;
  final SnackBarService snackBarService;

  StreamSubscription<sdk.IncomingMessage>? sub;
  Timer? geometryPollTimer;
  Timer? remoteSyncTimer;
  Timer? navigatorSyncTimer;

  static const pollInterval = Duration(seconds: 30);
  static const remoteSyncInterval = Duration(minutes: 5);
  static const navigatorSyncInterval = Duration(minutes: 3);

  final List<RecoveryReport> reports = [];
  final ValueNotifier<int> unreadCount = ValueNotifier(0);
  String? responderMarkerId;
  String responderRouteId = '';
  final Map<String, double> initialNavigatorDistances = {};

  ReportsViewModel(
    this.messaging,
    this.repository,
    this.parseIncomingReport,
    this.parseIncomingDeletion,
    this.viewReportOnMap,
    this.parseNavigatorUpdate,
    this.pollRouteGeometry,
    this.syncRemoteReports,
    this.syncLocalReportsToLattice,
    this.syncNavigatorStates,
    this.mapService,
    this.navigationViewModel,
    this.publishRecoveryDeletion, {
    SnackBarService? snackBarService,
  }) : snackBarService = snackBarService ?? SnackBarService.instance {
    sub = messaging.onMessageReceived.listen(onMessage);
    loadFromDb();
    startGeometryPolling();
    startRemoteSyncPolling();
    startNavigatorSyncPolling();
  }

  double? navigatorProgress(RecoveryReport report) {
    if (report.navigatorLatitude == null || report.navigatorLongitude == null) {
      return null;
    }

    final navigatorPos =
        LatLng(report.navigatorLatitude!, report.navigatorLongitude!);
    final vehiclePos = LatLng(report.latitude, report.longitude);

    final remaining = const Distance(roundResult: false)
        .as(LengthUnit.Meter, navigatorPos, vehiclePos);

    if (remaining <= 100) return 1.0;

    final initial = report.entityId != null
        ? initialNavigatorDistances[report.entityId]
        : null;

    if (initial == null || initial <= 100) {
      const maxDistance = 50000.0;
      return 1.0 - (remaining.clamp(0.0, maxDistance) / maxDistance);
    }

    return (1.0 - (remaining / initial)).clamp(0.0, 1.0);
  }

  String? navigatorDistanceRemaining(RecoveryReport report) {
    if (report.navigatorLatitude == null || report.navigatorLongitude == null) {
      return null;
    }

    final navigatorPos =
        LatLng(report.navigatorLatitude!, report.navigatorLongitude!);
    final vehiclePos = LatLng(report.latitude, report.longitude);

    final meters = const Distance(roundResult: false)
        .as(LengthUnit.Meter, navigatorPos, vehiclePos);

    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  double? distanceToKm(RecoveryReport report) {
    final currentLocation = navigationViewModel.currentLocation;
    if (currentLocation == null) return null;
    final to = LatLng(report.latitude, report.longitude);
    return const Distance(roundResult: false)
        .as(LengthUnit.Kilometer, currentLocation, to);
  }

  String? distanceTo(RecoveryReport report) {
    final km = distanceToKm(report);
    if (km == null) return null;
    return '${km.toStringAsFixed(2)} km';
  }

  Future<void> loadFromDb() async {
    final rows = await repository.getAllReports();
    reports.addAll(rows);
    updateUnread();
    notifyListeners();
  }

  void updateUnread() {
    unreadCount.value = reports.where((r) => !r.isRead && !r.isOutgoing).length;
  }

  void onMessage(sdk.IncomingMessage msg) {
    final report = parseIncomingReport(msg);
    if (report != null) {
      reports.insert(0, report);
      updateUnread();
      repository.insertReport(report);
      notifyListeners();
      return;
    }

    final deletedEntityId = parseIncomingDeletion(msg);
    if (deletedEntityId != null) {
      applyRemoteDeletion(deletedEntityId);
      return;
    }

    final update = parseNavigatorUpdate(msg);
    if (update != null) {
      applyNavigatorUpdate(update);
    }
  }

  Future<void> applyRemoteDeletion(String entityId) async {
    final index = reports.indexWhere((r) => r.entityId == entityId);
    if (index == -1) return;
    final removed = reports.removeAt(index);
    updateUnread();
    if (removed.id != null) {
      await repository.deleteReport(removed.id!);
    }
    notifyListeners();
  }

  void applyNavigatorUpdate(NavigatorUpdate update) {
    final index = reports
        .indexWhere((r) => r.entityId == update.entityId && r.isOutgoing);
    if (index == -1) return;

    final report = reports[index];

    if (update.stopped) {
      reports[index] = report.copyWith(clearNavigatorLocation: true);
      initialNavigatorDistances.remove(update.entityId);
      if (report.id != null) {
        repository.clearNavigatorLocation(report.id!);
      }
      removeResponderFromMap();
      final label =
          report.bumperNumber.isNotEmpty ? report.bumperNumber : 'Your report';
      snackBarService.enqueue(
        '$label — responder has stopped navigation',
        persistent: true,
      );
      notifyListeners();
      return;
    }

    if (update.entityId.isNotEmpty &&
        !initialNavigatorDistances.containsKey(update.entityId)) {
      final navigatorPos =
          LatLng(update.navigatorLatitude, update.navigatorLongitude);
      final vehiclePos = LatLng(report.latitude, report.longitude);
      final meters = const Distance(roundResult: false)
          .as(LengthUnit.Meter, navigatorPos, vehiclePos);
      initialNavigatorDistances[update.entityId] = meters;
    }

    reports[index] = report.copyWith(
      navigatorLatitude: update.navigatorLatitude,
      navigatorLongitude: update.navigatorLongitude,
      routeGeometry: update.routeGeometry ?? report.routeGeometry,
    );

    if (report.id != null) {
      repository.updateNavigatorLocation(
        report.id!,
        update.navigatorLatitude,
        update.navigatorLongitude,
      );
    }

    showResponderOnMap(reports[index]);
    notifyListeners();
  }

  Future<void> removeResponderFromMap() async {
    try {
      if (responderMarkerId != null) {
        await mapService.removeMarker(responderMarkerId!);
        responderMarkerId = null;
      }
      if (responderRouteId.isNotEmpty) {
        await mapService.removePolyline(responderRouteId);
        responderRouteId = '';
      }
    } catch (e) {
      debugPrint('[RecoveryOps] removeResponderFromMap error: $e');
    }
  }

  Future<void> showResponderOnMap(RecoveryReport report) async {
    try {
      if (responderMarkerId != null) {
        await mapService.removeMarker(responderMarkerId!);
      }
      if (responderRouteId.isNotEmpty) {
        await mapService.removePolyline(responderRouteId);
      }

      final responderPos = sdk.LatLng(
        report.navigatorLatitude!,
        report.navigatorLongitude!,
      );

      final label = report.bumperNumber.isNotEmpty
          ? 'Responder Moving to--> ${report.bumperNumber} '
          : 'Responder';

      responderMarkerId = await mapService.addMarker(
        responderPos,
        label: label,
        icon: sdk.MarkerIcon.vehicle,
        disposition: sdk.MarkerDisposition.friendly,
      );

      if (report.hasGeometry) {
        responderRouteId = 'responder-route-${report.id}';
        final points = report.routeGeometry!
            .map((p) => sdk.LatLng(p.latitude, p.longitude))
            .toList();
        await mapService.addPolyline(
          responderRouteId,
          points,
        );
      } else {
        responderRouteId = '';
      }

      await mapService.flyTo(responderPos, zoom: 13);
    } catch (e) {
      debugPrint('[RecoveryOps] showResponderOnMap error: $e');
    }
  }

  Future<void> markReportAsRead(RecoveryReport report) async {
    if (report.isRead) return;
    final index = reports.indexOf(report);
    if (index == -1) return;
    reports[index] = report.copyWith(isRead: true);
    updateUnread();
    if (report.id != null) {
      await repository.markAsRead(report.id!);
    }
    notifyListeners();
  }

  Future<void> markBracketAsRead(DistanceBracket bracket) async {
    var changed = false;
    for (var i = 0; i < reports.length; i++) {
      if (reports[i].isOutgoing || reports[i].isRead) continue;
      if (DistanceBracket.fromKm(distanceToKm(reports[i])) != bracket) continue;
      reports[i] = reports[i].copyWith(isRead: true);
      if (reports[i].id != null) {
        await repository.markAsRead(reports[i].id!);
      }
      changed = true;
    }
    if (changed) {
      updateUnread();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    var changed = false;
    for (var i = 0; i < reports.length; i++) {
      if (!reports[i].isRead) {
        reports[i] = reports[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) {
      updateUnread();
      await repository.markAllAsRead();
      notifyListeners();
    }
  }

  Future<void> deleteReport(RecoveryReport report) async {
    final index = reports.indexOf(report);
    if (index == -1) return;
    reports.removeAt(index);
    updateUnread();
    if (report.id != null) {
      await repository.deleteReport(report.id!);
    }
    notifyListeners();

    if (report.isOutgoing &&
        report.entityId != null &&
        report.entityId!.isNotEmpty) {
      final outcome = await publishRecoveryDeletion(entityId: report.entityId!);
      snackBarService.enqueue(
        'Deletion — Lattice: ${outcome.latticeOk ? 'sent' : 'FAILED'} | '
        'Mesh: ${outcome.meshOk ? 'sent' : 'FAILED'}',
        isError: !outcome.allSucceeded,
      );
    }
  }

  Future<void> viewReport(RecoveryReport report) async {
    await viewReportOnMap(
      report,
      activeMarkerId: null,
      activeRouteId: navigationViewModel.activeRouteId,
    );
    navigationViewModel.clearNavigation();
    notifyListeners();
  }

  Future<void> navigateTo(RecoveryReport report) async {
    final updatedReport = await navigationViewModel.navigateTo(report);
    if (updatedReport == null) return;

    final index = reports.indexOf(report);
    if (index != -1) {
      reports[index] = updatedReport;
    }
    notifyListeners();
  }

  List<RecoveryReport> get yourReports =>
      reports.where((r) => r.isOutgoing).toList();

  List<RecoveryReport> get externalReports =>
      reports.where((r) => !r.isOutgoing).toList();

  Map<DistanceBracket, List<RecoveryReport>> get groupedExternalReports {
    final result = {
      for (final b in DistanceBracket.values) b: <RecoveryReport>[],
    };
    for (final report in externalReports) {
      final bracket = DistanceBracket.fromKm(distanceToKm(report));
      result[bracket]!.add(report);
    }
    for (final list in result.values) {
      list.sort((a, b) {
        final da = distanceToKm(a) ?? double.infinity;
        final db = distanceToKm(b) ?? double.infinity;
        return da.compareTo(db);
      });
    }
    return result;
  }

  Map<DistanceBracket, int> get unreadPerBracket {
    final result = {for (final b in DistanceBracket.values) b: 0};
    for (final report in externalReports) {
      if (!report.isRead) {
        final bracket = DistanceBracket.fromKm(distanceToKm(report));
        result[bracket] = result[bracket]! + 1;
      }
    }
    return result;
  }

  void startGeometryPolling() {
    geometryPollTimer = Timer.periodic(pollInterval, (_) => pollForGeometry());
  }

  Future<void> pollForGeometry() async {
    final updates = await pollRouteGeometry(reports);
    for (final update in updates) {
      reports[update.index] = update.updatedReport;
    }
    if (updates.isNotEmpty) {
      notifyListeners();
    }
  }

  void startRemoteSyncPolling() {
    remoteSyncTimer =
        Timer.periodic(remoteSyncInterval, (_) => syncRemoteLatticeReports());
  }

  Future<void> syncRemoteLatticeReports() async {
    final newReports = await syncRemoteReports(reports);
    if (newReports.isNotEmpty) {
      for (final report in newReports) {
        reports.insert(0, report);
      }
      updateUnread();
      notifyListeners();
    }

    await syncLocalReportsToLattice(reports);
  }

  void startNavigatorSyncPolling() {
    navigatorSyncTimer = Timer.periodic(
      navigatorSyncInterval,
      (_) => syncNavigatorsFromLattice(),
    );
  }

  Future<void> syncNavigatorsFromLattice() async {
    final updates = await syncNavigatorStates(reports);
    for (final update in updates) {
      applyNavigatorUpdate(update);
    }
  }

  @override
  void dispose() {
    geometryPollTimer?.cancel();
    remoteSyncTimer?.cancel();
    navigatorSyncTimer?.cancel();
    sub?.cancel();
    unreadCount.dispose();
    super.dispose();
  }
}
