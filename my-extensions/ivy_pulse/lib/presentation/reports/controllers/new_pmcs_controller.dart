import 'package:flutter/foundation.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';

/// Starts a vehicle inspection or offers to continue the existing session.
class NewPmcsController extends ChangeNotifier {
  final InspectionViewModel? Function() resolveInspection;
  final VoidCallback openInspection;

  String? startingPmcsId;
  bool offeringContinuation = false;
  bool _disposed = false;

  NewPmcsController({
    required this.resolveInspection,
    required this.openInspection,
  });

  Future<void> start(
    PmcsReport report, {
    required Future<bool> Function(PmcsSession session) confirmContinue,
  }) async {
    if (_disposed || startingPmcsId != null || offeringContinuation) return;
    final inspection = resolveInspection();
    if (inspection == null || inspection.isBusy) return;
    final accepted = inspection.prefillVehicle(
      bumperNumber: report.bumperNumber,
      uic: report.uic,
      vehicleType: report.vehicleType,
    );
    if (!accepted) {
      final open = inspection.session;
      if (open == null) return;
      offeringContinuation = true;
      try {
        final shouldContinue = await confirmContinue(open);
        if (!_disposed &&
            shouldContinue &&
            inspection.session?.sessionId == open.sessionId) {
          openInspection();
        }
      } finally {
        offeringContinuation = false;
      }
      return;
    }
    startingPmcsId = report.entityId;
    notifyListeners();
    try {
      final started = await inspection.beginSession(
        bumperNumber: report.bumperNumber,
        uic: report.uic,
      );
      if (_disposed || !started) return;
      openInspection();
    } finally {
      if (!_disposed) {
        startingPmcsId = null;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
