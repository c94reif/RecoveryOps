import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import 'package:cac_ocr/cac_ocr.dart';
import 'package:circle_x/domain/vehicle/entities/bumper_number.dart';
import 'package:circle_x/domain/vehicle/entities/mileage_reading.dart';
import 'package:circle_x/domain/inspection/entities/check_result.dart';
import 'package:circle_x/domain/inspection/entities/fault_description.dart';
import 'package:circle_x/domain/catalog/entities/pmcs_catalog.dart';
import 'package:circle_x/domain/catalog/entities/pmcs_category.dart';
import 'package:circle_x/domain/catalog/entities/pmcs_check_item.dart';
import 'package:circle_x/domain/inspection/entities/pmcs_fault.dart';
import 'package:circle_x/domain/reporting/entities/pmcs_history.dart';
import 'package:circle_x/domain/catalog/entities/pmcs_phase.dart';
import 'package:circle_x/domain/reporting/entities/pmcs_report.dart';
import 'package:circle_x/domain/inspection/entities/pmcs_session.dart';
import 'package:circle_x/domain/inspection/entities/pmcs_signature.dart';
import 'package:circle_x/domain/profile/entities/profile.dart';
import 'package:circle_x/domain/delivery/entities/publish_result.dart';
import 'package:circle_x/domain/delivery/entities/transport_kind.dart';
import 'package:circle_x/domain/catalog/entities/vehicle_type.dart';
import 'package:circle_x/domain/profile/entities/uic.dart';
import 'package:circle_x/domain/inspection/repositories/faults_repo.dart';
import 'package:circle_x/domain/profile/repositories/profile_repo.dart';
import 'package:circle_x/domain/reporting/repositories/reports_repo.dart';
import 'package:circle_x/domain/inspection/repositories/results_repo.dart';
import 'package:circle_x/domain/shared/services/clock.dart';
import 'package:circle_x/domain/delivery/services/delivery_coordinator.dart';
import 'package:circle_x/domain/catalog/services/pmcs_catalog_source.dart';
import 'package:circle_x/domain/shared/services/speech_recognition_strategy.dart';
import 'package:circle_x/domain/shared/services/user_notification_sink.dart';
import 'package:circle_x/domain/delivery/usecases/publish_pmcs_report.dart';
import 'package:circle_x/domain/reporting/usecases/submit_session.dart';
import 'package:circle_x/domain/inspection/usecases/abandon_session.dart';
import 'package:circle_x/domain/inspection/usecases/complete_phase.dart';
import 'package:circle_x/domain/inspection/usecases/load_open_sessions.dart';
import 'package:circle_x/domain/inspection/usecases/record_check_result.dart';
import 'package:circle_x/domain/inspection/usecases/start_session.dart';
import 'package:circle_x/presentation/common/services/snack_bar_service.dart';
import 'package:circle_x/presentation/common/services/fault_suggestion_controller.dart';
import 'package:circle_x/presentation/inspection/controllers/fault_dictation_controller.dart';
import 'package:circle_x/presentation/inspection/phase_workspace.dart';

part 'inspection_state.dart';
part 'inspection_session.dart';
part 'inspection_checklist.dart';
part 'inspection_history.dart';
part 'inspection_submission.dart';

enum InspectionStage {
  setup,
  phaseSelect,
  inspecting,
  summary,
  submitted,
}

class InspectionViewModel extends _InspectionState
    with
        _InspectionSession,
        _InspectionChecklist,
        _InspectionHistory,
        _InspectionSubmission {
  @override
  final PmcsCatalogSource catalogSource;
  @override
  final StartSession startSession;
  @override
  final LoadOpenSessions loadOpenSessions;
  @override
  final RecordCheckResult recordCheckResult;
  @override
  final CompletePhase completePhase;
  @override
  final AbandonSession abandonSession;
  @override
  final SubmitSession submitSession;
  @override
  final PublishPmcsReport publishPmcsReport;
  @override
  final ResultsRepository resultsRepository;
  @override
  final FaultsRepository faultsRepository;
  final SpeechRecognitionStrategy speechStrategy;
  final VerifyOperatorIdentity verifyOperatorIdentity;
  @override
  final CacScannerStrategy cacScanner;
  @override
  final ProfileRepository profileRepository;
  @override
  final ReportsRepository reportsRepository;
  @override
  final Clock clock;
  @override
  final FaultSuggestionController suggestions;
  final bool _ownsSuggestions;

  @override
  final void Function(PmcsReport report)? onReportSubmitted;
  @override
  final UserNotificationSink snackBarService;

  InspectionViewModel({
    required this.catalogSource,
    required this.startSession,
    required this.loadOpenSessions,
    required this.recordCheckResult,
    required this.completePhase,
    required this.abandonSession,
    required this.submitSession,
    required this.publishPmcsReport,
    required this.resultsRepository,
    required this.faultsRepository,
    required this.speechStrategy,
    required this.verifyOperatorIdentity,
    required this.cacScanner,
    required this.profileRepository,
    required this.reportsRepository,
    this.clock = const SystemClock(),
    this.onReportSubmitted,
    FaultSuggestionController? suggestions,
    UserNotificationSink? snackBarService,
  })  : suggestions = suggestions ??
            FaultSuggestionController(reportsRepository,
                notifications: snackBarService),
        _ownsSuggestions = suggestions == null,
        snackBarService = snackBarService ?? SnackBarService.instance {
    identityScan = CacScanController(
      cacScanner: cacScanner,
      verifyOperatorIdentity: verifyOperatorIdentity,
    )..addListener(notifyListeners);
    dictation = FaultDictationController(
      speech: speechStrategy,
      notifications: this.snackBarService,
    )..addListener(notifyListeners);
    deliverySubscription = publishPmcsReport.delivery.changes.listen((_) {
      if (submittedReport != null) notifyListeners();
    });
    final vehicles = catalogSource.supportedVehicles;
    if (vehicles.isNotEmpty) selectedVehicle = vehicles.first;
  }

  late final StreamSubscription<void> deliverySubscription;

  @override
  void dispose() {
    if (_ownsSuggestions) suggestions.dispose();
    deliverySubscription.cancel();
    identityScan.removeListener(notifyListeners);
    identityScan.dispose();
    dictation.removeListener(notifyListeners);
    dictation.dispose();
    submittedReport = null;
    super.dispose();
  }
}
