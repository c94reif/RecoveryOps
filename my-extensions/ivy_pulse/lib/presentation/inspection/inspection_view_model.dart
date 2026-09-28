import 'package:ivy_pulse/presentation/inspection/controllers/cac_scan_controller.dart';
import 'package:ivy_pulse/presentation/inspection/controllers/fault_dictation_controller.dart';
import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import 'package:ivy_pulse/domain/entities/attested_identity.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/fault_description.dart';
import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';
import 'package:ivy_pulse/domain/entities/pmcs_category.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/pmcs_history.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/entities/pmcs_signature.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
import 'package:ivy_pulse/domain/entities/publish_result.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/repositories/faults_repo.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';
import 'package:ivy_pulse/domain/repositories/reports_repo.dart';
import 'package:ivy_pulse/domain/repositories/results_repo.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';
import 'package:ivy_pulse/domain/services/delivery_coordinator.dart';
import 'package:ivy_pulse/domain/services/pmcs_catalog_source.dart';
import 'package:ivy_pulse/domain/services/speech_recognition_strategy.dart';
import 'package:ivy_pulse/domain/usecases/identity/verify_operator_identity.dart';
import 'package:ivy_pulse/domain/usecases/publishing/publish_pmcs_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/submit_session.dart';
import 'package:ivy_pulse/domain/usecases/session/abandon_session.dart';
import 'package:ivy_pulse/domain/usecases/session/complete_phase.dart';
import 'package:ivy_pulse/domain/usecases/session/load_open_sessions.dart';
import 'package:ivy_pulse/domain/usecases/session/record_check_result.dart';
import 'package:ivy_pulse/domain/usecases/session/start_session.dart';
import 'package:ivy_pulse/presentation/common/services/snack_bar_service.dart';
import 'package:ivy_pulse/domain/services/user_notification_sink.dart';
import 'package:ivy_pulse/presentation/common/services/fault_suggestion_controller.dart';
import 'package:ivy_pulse/presentation/inspection/phase_workspace.dart';

enum InspectionStage {
  setup,
  phaseSelect,
  inspecting,
  summary,
  submitted,
}

class InspectionViewModel extends ChangeNotifier {
  final PmcsCatalogSource catalogSource;
  final StartSession startSession;
  final LoadOpenSessions loadOpenSessions;
  final RecordCheckResult recordCheckResult;
  final CompletePhase completePhase;
  final AbandonSession abandonSession;
  final SubmitSession submitSession;
  final PublishPmcsReport publishPmcsReport;
  final ResultsRepository resultsRepository;
  final FaultsRepository faultsRepository;
  final SpeechRecognitionStrategy speechStrategy;
  final VerifyOperatorIdentity verifyOperatorIdentity;
  final CacScannerStrategy cacScanner;
  final ProfileRepository profileRepository;
  final ReportsRepository reportsRepository;
  final Clock clock;
  final FaultSuggestionController suggestions;
  final bool _ownsSuggestions;
  PmcsHistory? history;
  bool historyUnavailable = false;

  final void Function(PmcsReport report)? onReportSubmitted;
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

  DeliveryStatus? deliveryStatus(TransportKind transport) => submittedReport ==
          null
      ? null
      : publishPmcsReport.delivery.status(submittedReport!.entityId, transport);

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

  InspectionStage stage = InspectionStage.setup;
  PmcsSession? session;
  PmcsCatalog? catalog;
  VehicleType selectedVehicle = VehicleType.stryker;
  PhaseWorkspace? workspace;
  bool reviewingSummaryFault = false;
  PmcsReport? submittedReport;
  PublishResult? submissionDelivery;
  bool submissionDeliveryFailed = false;
  Profile? profile;
  List<PmcsFault> sessionFaults = [];
  List<PmcsSession> openSessions = [];
  final Map<PmcsPhase, int> phaseAnswerCounts = {};
  String? pendingScrollItemId;
  bool isBusy = false;
  late final FaultDictationController dictation;
  bool get isListening => dictation.isListening;
  String? get listeningItemId => dictation.listeningItemId;

  late final CacScanController identityScan;

  CacScan? get lastScan => identityScan.lastScan;
  set lastScan(CacScan? value) => identityScan.lastScan = value;
  bool get isScanning => identityScan.isScanning;
  int get scanAttempts => identityScan.scanAttempts;
  set scanAttempts(int value) => identityScan.scanAttempts = value;
  bool cacScannerAvailable = true;

  Future<void> load() async {
    isBusy = true;
    notifyListeners();
    try {
      profile = await profileRepository.getProfile();
      openSessions = await loadOpenSessions();
      cacScannerAvailable = await cacScanner.isAvailable();
    } catch (error) {
      debugPrint('[IvyPulse] load error: $error');
    }
    isBusy = false;
    notifyListeners();
  }

  void selectVehicle(VehicleType vehicleType) {
    selectedVehicle = vehicleType;
    notifyListeners();
  }

  ({String bumperNumber, String uic})? pendingPrefill;

  bool prefillVehicle({
    required String bumperNumber,
    required String uic,
    required VehicleType vehicleType,
  }) {
    if (stage != InspectionStage.setup && stage != InspectionStage.submitted) {
      return false;
    }
    selectedVehicle = vehicleType;
    pendingPrefill = (bumperNumber: bumperNumber, uic: uic);
    notifyListeners();
    return true;
  }

  ({String bumperNumber, String uic})? takePrefill() {
    final prefill = pendingPrefill;
    pendingPrefill = null;
    return prefill;
  }

  Future<bool> beginSession({
    required String bumperNumber,
    required String uic,
  }) async {
    if (bumperNumber.trim().isEmpty || uic.trim().isEmpty) {
      snackBarService.enqueue(
        'Bumper number and UIC are required',
        isError: true,
      );
      return false;
    }

    isBusy = true;
    notifyListeners();

    try {
      session = await startSession(
        bumperNumber: bumperNumber,
        vehicleType: selectedVehicle,
        uic: uic,
      );
      catalog = catalogSource.catalogFor(selectedVehicle);
      await loadHistory();
      sessionFaults = [];
      workspace = null;
      phaseAnswerCounts.clear();
      submittedReport = null;
      submissionDelivery = null;
      submissionDeliveryFailed = false;
      reviewingSummaryFault = false;
      stage = InspectionStage.phaseSelect;
    } catch (error) {
      debugPrint('[IvyPulse] beginSession failed: $error');
      snackBarService.enqueue('Could not start PMCS — $error', isError: true);
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }

    debugPrint('[IvyPulse] beginSession — ${session!.sessionId} '
        '${session!.displayTitle}');
    return true;
  }

  Future<void> resumeSession(PmcsSession open) async {
    if (isBusy) return;
    isBusy = true;
    notifyListeners();

    try {
      catalog = catalogSource.catalogFor(open.vehicleType);
    } on StateError catch (error) {
      debugPrint('[IvyPulse] resumeSession — no catalog: $error');
      snackBarService.enqueue(
        'No PMCS catalog for ${open.vehicleType.displayName}',
        isError: true,
      );
      isBusy = false;
      notifyListeners();
      return;
    }

    try {
      session = open;
      await loadHistory();
      selectedVehicle = open.vehicleType;
      sessionFaults = await faultsRepository.getForSession(open.sessionId);
      final savedWorkspaces =
          await Future.wait(PmcsPhase.values.map((phase) async {
        final saved = await resultsRepository.getResults(open.sessionId, phase);
        return PhaseWorkspace(
          phase: phase,
          categories: catalog!.categoriesFor(phase),
          results: saved,
        );
      }));
      phaseAnswerCounts
        ..clear()
        ..addEntries(savedWorkspaces
            .map((saved) => MapEntry(saved.phase, saved.answeredCount)));

      workspace = null;
      DateTime? latestAnswerAt;
      for (final saved in savedWorkspaces) {
        if (open.isPhaseComplete(saved.phase)) continue;
        for (final item in saved.items) {
          final answer = saved.resultFor(item.id);
          if (answer == null) continue;
          if (latestAnswerAt == null ||
              answer.recordedAt.isAfter(latestAnswerAt)) {
            latestAnswerAt = answer.recordedAt;
            workspace = saved;
          }
        }
      }
      pendingScrollItemId = workspace?.nextUnansweredItemId;
      reviewingSummaryFault = false;
      stage = workspace != null
          ? InspectionStage.inspecting
          : open.hasStartedAnyPhase
              ? InspectionStage.summary
              : InspectionStage.phaseSelect;

      debugPrint('[IvyPulse] resumeSession — ${open.sessionId}, '
          '${workspace?.phase.wireName ?? stage.name}');
    } catch (error) {
      debugPrint('[IvyPulse] resumeSession failed: $error');
      snackBarService.enqueue('Could not resume PMCS — $error', isError: true);
      session = null;
      catalog = null;
      workspace = null;
      pendingScrollItemId = null;
      reviewingSummaryFault = false;
      phaseAnswerCounts.clear();
      stage = InspectionStage.setup;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> openPhase(PmcsPhase phase) async {
    final current = session;
    if (current == null || isBusy) return;

    isBusy = true;
    notifyListeners();

    try {
      workspace = PhaseWorkspace(
        phase: phase,
        categories: catalog?.categoriesFor(phase) ?? const [],
        results: await resultsRepository.getResults(current.sessionId, phase),
      );
      phaseAnswerCounts[phase] = workspace!.answeredCount;
      pendingScrollItemId = nextUnansweredItemId;
      stage = InspectionStage.inspecting;
    } catch (error) {
      debugPrint('[IvyPulse] openPhase failed: $error');
      snackBarService.enqueue('Could not open ${phase.label} — $error',
          isError: true);
      workspace = null;
      stage = InspectionStage.phaseSelect;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> answer(PmcsCheckItem item, int faultIndex,
      {String? suggestedNote}) async {
    final current = session;
    final open = workspace;
    if (current == null || open == null || isBusy) return;

    isBusy = true;
    notifyListeners();
    try {
      if (isListening) await stopNoteDictation(discardResult: true);
      final result = await recordCheckResult(
        sessionId: current.sessionId,
        phase: open.phase,
        item: item,
        faultIndex: faultIndex,
        note: faultIndex == 0
            ? null
            : (suggestedNote ?? open.resultFor(item.id)?.note),
      );
      open.record(result);
      phaseAnswerCounts[open.phase] = open.answeredCount;
      pendingScrollItemId = open.expandedItemId;
    } catch (error) {
      debugPrint('[IvyPulse] answer failed: $error');
      snackBarService.enqueue(
        'Could not save ${item.item}. Your previous answers are kept. '
        'Tap the condition again to retry.',
        isError: true,
      );
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void expandItem(String itemId) {
    if (isBusy) return;
    workspace?.expand(itemId);
    notifyListeners();
  }

  void collapseItem(String itemId) {
    if (isBusy) return;
    workspace?.collapse(itemId);
    notifyListeners();
  }

  void continueToNextCheck() {
    final next = nextUnansweredItemId;
    if (next == null || isBusy) return;
    workspace?.expand(next);
    pendingScrollItemId = next;
    notifyListeners();
  }

  Future<void> toggleNoteDictation(PmcsCheckItem item) async {
    final open = workspace;
    if (open == null || open.resultFor(item.id)?.isFault != true || isBusy) {
      return;
    }
    await dictation.toggle(
      itemId: item.id,
      isCurrent: () => identical(workspace, open),
      onResult: (text) => attachNote(item, text),
    );
  }

  Future<void> stopNoteDictation({bool discardResult = false}) =>
      dictation.stop(discardResult: discardResult);

  Future<void> attachNote(PmcsCheckItem item, String note) async {
    if (note.trim().isEmpty) return;
    final description = note.trim().characters;
    if (!await saveNote(
        item, description.take(maxFaultDescriptionLength).toString())) {
      snackBarService.enqueue(
          'Could not save the description. Try typing it again.',
          isError: true);
    } else if (description.length > maxFaultDescriptionLength) {
      snackBarService.enqueue(
          'Description limited to 155 characters. Use Edit description to review it.');
    }
  }

  Future<bool> saveNote(PmcsCheckItem item, String note) async {
    final current = session;
    final open = workspace;
    final existing = open?.resultFor(item.id);
    if (current == null ||
        open == null ||
        existing?.isFault != true ||
        isBusy) {
      return false;
    }
    isBusy = true;
    notifyListeners();
    try {
      final trimmed = note.trim();
      open.results[item.id] = await recordCheckResult(
        sessionId: current.sessionId,
        phase: open.phase,
        item: item,
        faultIndex: existing!.faultIndex,
        note: trimmed.isEmpty ? null : trimmed,
      );
      return true;
    } catch (error) {
      debugPrint('[IvyPulse] saveNote failed: $error');
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  String? consumePendingScroll() {
    final itemId = pendingScrollItemId;
    pendingScrollItemId = null;
    return itemId;
  }

  Future<void> completeActivePhase() async {
    final current = session;
    final open = workspace;
    final loaded = catalog;
    if (current == null || open == null || loaded == null || isBusy) return;
    final phase = open.phase;

    isBusy = true;
    notifyListeners();

    try {
      if (isListening) await stopNoteDictation(discardResult: true);
      final outcome = await completePhase(
        session: current,
        phase: phase,
        catalog: loaded,
        results: open.results,
      );

      session = outcome.session;
      sessionFaults = await faultsRepository.getForSession(current.sessionId);
      workspace = null;
      pendingScrollItemId = null;
      stage = InspectionStage.summary;
      reviewingSummaryFault = false;

      debugPrint('[IvyPulse] completeActivePhase — ${phase.wireName}, '
          '${outcome.faults.length} fault(s)');
    } catch (error) {
      debugPrint('[IvyPulse] completeActivePhase failed: $error');
      snackBarService.enqueue('Could not close out ${phase.label} — $error',
          isError: true);
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void openSummary() {
    stage = InspectionStage.summary;
    notifyListeners();
  }

  Future<void> reviewFault(PmcsFault fault) async {
    if (isBusy || session == null) return;
    await reviewPhase(fault.phase);
    final open = workspace;
    if (!reviewingSummaryFault || open == null) return;
    if (!open.items.any((item) => item.id == fault.itemId)) return;
    open.expand(fault.itemId);
    pendingScrollItemId = fault.itemId;
    notifyListeners();
  }

  Future<void> reviewPhase(PmcsPhase phase) async {
    if (isBusy || session == null) return;
    await openPhase(phase);
    final open = workspace;
    if (stage != InspectionStage.inspecting || open == null) return;
    reviewingSummaryFault = true;
    notifyListeners();
  }

  Future<void> returnToSummary() async {
    if (isBusy) return;
    if (workspace?.isComplete == true) {
      await completeActivePhase();
    } else {
      backToPhases();
    }
  }

  void backToPhases() {
    if (isBusy) return;
    if (isListening) stopNoteDictation(discardResult: true);
    workspace = null;
    reviewingSummaryFault = false;
    pendingScrollItemId = null;
    identityScan.reset();
    stage = InspectionStage.phaseSelect;
    notifyListeners();
  }

  Future<void> scanCac() => identityScan.scan();

  void untallyAttempt() => identityScan.untallyAttempt();

  void cancelScan() => identityScan.cancelScan();

  bool get isSignedOff => lastScan?.isVerified ?? false;

  bool get canSubmitUnverified => lastScan != null && !lastScan!.isVerified;

  Future<void> submit() async {
    if (session == null) return;

    final identity = lastScan?.identity;
    if (identity == null) {
      snackBarService.enqueue(
        'Scan a CAC before submitting',
        isError: true,
      );
      return;
    }

    await submitWith(PmcsSignature.verified(
      identity: identity,
      signedAt: identity.verifiedAt,
    ));
  }

  Future<void> submitUnverified() async {
    if (session == null) return;

    final rejection = lastScan?.rejection;
    if (rejection == null) {
      snackBarService.enqueue('Scan a CAC before submitting', isError: true);
      return;
    }

    await submitWith(PmcsSignature.unverified(
      blockedBy: rejection,
      signedAt: clock.nowUtc(),
    ));
  }

  Future<void> submitAttested({
    required String lastName,
    required String firstName,
    required String edipi,
  }) async {
    if (session == null) return;

    final rejection = lastScan?.rejection;
    if (rejection == null) {
      snackBarService.enqueue('Scan a CAC before submitting', isError: true);
      return;
    }

    final parsed = AttestedIdentity.parse(
      lastName: lastName,
      firstName: firstName,
      edipi: edipi,
    );
    final identity = parsed.identity;
    if (identity == null) {
      snackBarService.enqueue(parsed.error!, isError: true);
      return;
    }

    await submitWith(PmcsSignature.unverified(
      blockedBy: rejection,
      signedAt: clock.nowUtc(),
      attestedBy: identity,
    ));
  }

  Future<void> submitWith(PmcsSignature signature) async {
    final current = session;
    if (current == null || isBusy) return;

    isBusy = true;
    notifyListeners();

    final signed = current.copyWith(
      signature: signature,
      operator: signature.displayName,
    );
    session = signed;

    final PmcsReport report;
    try {
      report = await submitSession(signed);
    } catch (error) {
      debugPrint('[IvyPulse] submit failed: $error');
      snackBarService.enqueue('Could not submit PMCS — $error', isError: true);
      isBusy = false;
      notifyListeners();
      return;
    }
    debugPrint('[IvyPulse] submit — ${report.entityId} '
        '${report.statusLabel}, ${report.faults.length} fault(s)');

    onReportSubmitted?.call(report);

    await resetToSetup();
    submittedReport = report;
    stage = InspectionStage.submitted;
    notifyListeners();

    publishPmcsReport(report).then((outcome) {
      if (!identical(submittedReport, report)) return;
      submissionDelivery = outcome;
      notifyListeners();
    }).catchError((error) {
      debugPrint('[IvyPulse] Publish error: $error');
      if (!identical(submittedReport, report)) return;
      submissionDeliveryFailed = true;
      notifyListeners();
    });

    snackBarService.enqueue(
      signature.isVerified
          ? 'PMCS submitted — ${report.statusLabel}'
          : 'PMCS submitted UNVERIFIED — ${report.statusLabel}',
      isError: !signature.isVerified,
    );
  }

  void announceLegOutcomes(PublishResult outcome) {
    if (outcome.latticeOk) {
      snackBarService.enqueue(
        '${TransportKind.lattice.displayName}: passed',
        isError: false,
      );
    }
    if (outcome.meshOk) {
      snackBarService.enqueue(
        '${TransportKind.mesh.displayName}: passed',
        isError: false,
      );
    }
  }

  Future<void> discardSession() async {
    final current = session;
    if (current == null) return;

    isBusy = true;
    notifyListeners();

    try {
      await abandonSession(current.sessionId);
      debugPrint('[IvyPulse] discardSession — ${current.sessionId}');
    } catch (error) {
      debugPrint('[IvyPulse] discardSession failed: $error');
      snackBarService.enqueue('Could not discard PMCS — $error', isError: true);
      isBusy = false;
      notifyListeners();
      return;
    }
    await resetToSetup();
  }

  Future<void> resetToSetup() async {
    history = null;
    historyUnavailable = false;
    session = null;
    catalog = null;
    workspace = null;
    reviewingSummaryFault = false;
    submittedReport = null;
    submissionDelivery = null;
    submissionDeliveryFailed = false;
    sessionFaults = [];
    phaseAnswerCounts.clear();
    pendingScrollItemId = null;
    identityScan.reset();
    stage = InspectionStage.setup;
    try {
      openSessions = await loadOpenSessions();
    } catch (error) {
      debugPrint('[IvyPulse] resetToSetup: could not reload sessions: $error');
      openSessions = [];
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  PmcsPhase? get activePhase => workspace?.phase;

  Future<void> loadHistory() async {
    final current = session;
    history = null;
    historyUnavailable = false;
    if (current == null) return;
    try {
      final reports = await reportsRepository.getAllReports();
      final withdrawn = await reportsRepository.getWithdrawnIds();
      if (session?.sessionId != current.sessionId) return;
      history = PmcsHistory.forVehicle(
        reports.where((report) => !withdrawn.contains(report.entityId)),
        bumperNumber: current.bumperNumber,
        uic: current.uic,
        vehicleType: current.vehicleType,
        before: current.startedAt,
        excluding: current.sessionId,
      );
    } catch (_) {
      historyUnavailable = true;
    }
    await suggestions.load();
  }

  List<HistoricalFault> get summarySuggestions =>
      history?.suggestedUnresolved
          .where((suggestion) =>
              session?.completedPhases.contains(suggestion.fault.phase) != true)
          .toList() ??
      const [];

  List<PhaseComparison> get comparisons => [
        if (history != null)
          for (final phase in session?.completedPhases ?? <PmcsPhase>[])
            history!.compare(phase, sessionFaults),
      ];

  Map<String, CheckResult> get results => workspace?.results ?? const {};

  Set<String> get collapsedItemIds => workspace?.collapsedItemIds ?? const {};

  String? get expandedItemId => workspace?.expandedItemId;

  bool isItemExpanded(String itemId) => workspace?.isExpanded(itemId) ?? false;

  List<PmcsCategory> get phaseCategories => workspace?.categories ?? const [];

  List<PmcsCheckItem> get phaseItems => workspace?.items ?? const [];

  int get answeredCount => workspace?.answeredCount ?? 0;

  int answeredCountFor(PmcsPhase phase) => phaseAnswerCounts[phase] ?? 0;

  int get totalCount => workspace?.totalCount ?? 0;

  FaultTally get phaseTally => workspace?.tally ?? const FaultTally();

  FaultTally get sessionTally => FaultTally.from(sessionFaults);

  bool get isPhaseComplete => workspace?.isComplete ?? false;

  String? get nextUnansweredItemId => workspace?.nextUnansweredItemId;
}
