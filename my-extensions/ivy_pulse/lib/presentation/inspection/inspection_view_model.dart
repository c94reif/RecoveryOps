import 'package:flutter/foundation.dart';
import 'package:characters/characters.dart';
import 'package:ivy_pulse/domain/entities/fault_description.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';
import 'package:ivy_pulse/domain/entities/pmcs_category.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/entities/pmcs_signature.dart';
import 'package:ivy_pulse/domain/entities/attested_identity.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
import 'package:ivy_pulse/domain/entities/publish_result.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/repositories/faults_repo.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';
import 'package:ivy_pulse/domain/repositories/results_repo.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';
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
import 'package:ivy_pulse/presentation/common/widgets/custom_snack_bar.dart';
import 'package:ivy_pulse/presentation/inspection/phase_workspace.dart';

/// Where the operator is in the walk-around. One view model drives all four
/// screens so an interrupted PMCS never loses the session it is holding.
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

  /// Told about every PMCS this device submits, with the row as stored.
  ///
  /// The reports screen keeps its own list and only reads the database at
  /// start, so without this hand-off a walk-around just submitted was not on
  /// the YOURS tab until the next launch. Optional so the flow can be built
  /// without a reports screen behind it, as the tests do.
  final void Function(PmcsReport report)? onReportSubmitted;
  final SnackBarService snackBarService;

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
    this.onReportSubmitted,
    SnackBarService? snackBarService,
  }) : snackBarService = snackBarService ?? SnackBarService.instance {
    final vehicles = catalogSource.supportedVehicles;
    if (vehicles.isNotEmpty) selectedVehicle = vehicles.first;
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
  bool isListening = false;
  String? listeningItemId;
  int dictationGeneration = 0;

  /// The most recent CAC read, or the reason it did not happen. Null means
  /// the operator has not tried yet.
  CacScan? lastScan;

  /// True while the camera is open or the frame is being decoded. Separate
  /// from [isBusy] so the sign-off card can show its own progress without
  /// greying out the rest of the summary.
  bool isScanning = false;

  /// Whether this build can reach a camera at all. Resolved once at [load],
  /// so a Soldier on a device without one is told at the summary rather than
  /// after they have tapped scan.
  bool cacScannerAvailable = true;

  /// How many scans have been tried since the last CAC actually read. Zeroed
  /// on a verified read, not on a rejection — the escalating advice under the
  /// refused card is counting misses in a row, and a Soldier who finally got
  /// the card in frame should not be lectured about glare on the next one.
  int scanAttempts = 0;

  /// Serial number of the scan currently owed an answer.
  ///
  /// Every path that walks away from a scan bumps this — [cancelScan],
  /// [backToPhases], [resetToSetup] — and [scanCac] refuses to write anything
  /// once its own number is stale. Without it the realistic sequence is a
  /// latch: the operator cancels a camera that never came back, taps SCAN
  /// AGAIN, and the abandoned capture finally lands and overwrites the live
  /// scan with an answer nobody is waiting for.
  int scanGeneration = 0;

  Future<void> load() async {
    isBusy = true;
    notifyListeners();
    try {
      profile = await profileRepository.getProfile();
      openSessions = await loadOpenSessions();
      cacScannerAvailable = await cacScanner.isAvailable();
    } catch (e) {
      debugPrint('[IvyPulse] load error: $e');
    }
    isBusy = false;
    notifyListeners();
  }

  void selectVehicle(VehicleType vehicleType) {
    selectedVehicle = vehicleType;
    notifyListeners();
  }

  /// Bumper number and UIC waiting to be dropped into the setup fields —
  /// handed over from a report card by "New PMCS on this vehicle". Consumed
  /// by the setup page the next time it builds, via [takePrefill].
  ({String bumperNumber, String uic})? pendingPrefill;

  /// Queue up a walk-around of a known vehicle. Returns false, and changes
  /// nothing, while an inspection is already open: the operator has to finish
  /// or discard that one first, and silently swapping the vehicle out from
  /// under it would be worse than making them do so.
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

  /// The pending prefill, cleared as it is handed over so a later build of
  /// the setup page does not overwrite what the operator has since typed.
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
      sessionFaults = [];
      workspace = null;
      phaseAnswerCounts.clear();
      submittedReport = null;
      submissionDelivery = null;
      submissionDeliveryFailed = false;
      reviewingSummaryFault = false;
      stage = InspectionStage.phaseSelect;
    } catch (e) {
      debugPrint('[IvyPulse] beginSession failed: $e');
      snackBarService.enqueue('Could not start PMCS — $e', isError: true);
      return false;
    } finally {
      // Cleared in a finally throughout this class: a latched isBusy disables
      // the very button that would let the operator try again, and there is no
      // way out of that short of restarting the extension.
      isBusy = false;
      notifyListeners();
    }

    debugPrint('[IvyPulse] beginSession — ${session!.sessionId} '
        '${session!.displayTitle}');
    return true;
  }

  Future<void> resumeSession(PmcsSession open) async {
    isBusy = true;
    notifyListeners();

    try {
      catalog = catalogSource.catalogFor(open.vehicleType);
    } on StateError catch (e) {
      // A session stored by a build that carried a platform this one does not
      // cannot be walked — say so rather than opening an empty checklist.
      debugPrint('[IvyPulse] resumeSession — no catalog: $e');
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
      selectedVehicle = open.vehicleType;
      sessionFaults = await faultsRepository.getForSession(open.sessionId);
      final counts = await Future.wait(PmcsPhase.values.map((phase) async {
        final saved = await resultsRepository.getResults(open.sessionId, phase);
        return MapEntry(
          phase,
          PhaseWorkspace(
            phase: phase,
            categories: catalog!.categoriesFor(phase),
            results: saved,
          ).answeredCount,
        );
      }));
      phaseAnswerCounts
        ..clear()
        ..addEntries(counts);
      workspace = null;
      stage = InspectionStage.phaseSelect;

      debugPrint('[IvyPulse] resumeSession — ${open.sessionId}, '
          '${open.remainingPhases.length} phase(s) remaining');
    } catch (e) {
      debugPrint('[IvyPulse] resumeSession failed: $e');
      snackBarService.enqueue('Could not resume PMCS — $e', isError: true);
      session = null;
      catalog = null;
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
      // Anything already answered arrives folded away, so a resumed phase
      // opens on the first check still owed, not a wall of finished ones.
      workspace = PhaseWorkspace(
        phase: phase,
        categories: catalog?.categoriesFor(phase) ?? const [],
        results: await resultsRepository.getResults(current.sessionId, phase),
      );
      phaseAnswerCounts[phase] = workspace!.answeredCount;
      pendingScrollItemId = nextUnansweredItemId;
      stage = InspectionStage.inspecting;
    } catch (e) {
      debugPrint('[IvyPulse] openPhase failed: $e');
      snackBarService.enqueue('Could not open ${phase.label} — $e',
          isError: true);
      workspace = null;
      stage = InspectionStage.phaseSelect;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> answer(PmcsCheckItem item, int faultIndex) async {
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
        // Calling the component serviceable also retires its fault note.
        note: faultIndex == 0 ? null : open.resultFor(item.id)?.note,
      );
      open.record(result);
      phaseAnswerCounts[open.phase] = open.answeredCount;
      pendingScrollItemId = open.expandedItemId;
    } catch (e) {
      debugPrint('[IvyPulse] answer failed: $e');
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
    if (isListening && listeningItemId == item.id) {
      await stopNoteDictation();
      return;
    }
    if (isListening) await stopNoteDictation(discardResult: true);

    final generation = ++dictationGeneration;
    isListening = true;
    listeningItemId = item.id;
    notifyListeners();

    try {
      await speechStrategy.startListening(
        onResult: (text) async {
          if (dictationGeneration != generation ||
              !identical(workspace, open) ||
              listeningItemId != item.id) {
            return;
          }
          isListening = false;
          listeningItemId = null;
          notifyListeners();
          await attachNote(item, text);
        },
      );
      if (dictationGeneration == generation &&
          isListening &&
          !speechStrategy.isListening) {
        isListening = false;
        listeningItemId = null;
        snackBarService
            .enqueue('Dictation unavailable — use Add description to type.');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[IvyPulse] dictation failed: $e');
      if (dictationGeneration != generation) return;
      isListening = false;
      listeningItemId = null;
      snackBarService
          .enqueue('Dictation unavailable — use Add description to type.');
      notifyListeners();
    }
  }

  Future<void> stopNoteDictation({bool discardResult = false}) async {
    final generation =
        discardResult ? ++dictationGeneration : dictationGeneration;
    if (discardResult) {
      isListening = false;
      listeningItemId = null;
      notifyListeners();
    }
    try {
      await speechStrategy.stopListening();
    } catch (e) {
      debugPrint('[IvyPulse] stop dictation failed: $e');
    } finally {
      if (dictationGeneration == generation) {
        isListening = false;
        listeningItemId = null;
        notifyListeners();
      }
    }
  }

  /// Re-records the existing answer with [note] attached — the note rides the
  /// fault onto the 5988-E, so it has to live on the stored result.
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

  /// Saving a note leaves the operator on the check they were reviewing.
  /// An empty typed note removes the old note; an empty transcript does not.
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
    } catch (e) {
      debugPrint('[IvyPulse] saveNote failed: $e');
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Hands the page the item it should scroll to, once. Scrolling needs a
  /// [BuildContext] the view model must never hold.
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
      stage = reviewingSummaryFault || outcome.session.allPhasesComplete
          ? InspectionStage.summary
          : InspectionStage.phaseSelect;
      reviewingSummaryFault = false;

      debugPrint('[IvyPulse] completeActivePhase — ${phase.wireName}, '
          '${outcome.faults.length} fault(s)');
    } catch (e) {
      // The answers are already on disk, so the phase is not lost — the
      // operator stays on it and can close it out again.
      debugPrint('[IvyPulse] completeActivePhase failed: $e');
      snackBarService.enqueue('Could not close out ${phase.label} — $e',
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
    await openPhase(fault.phase);
    final open = workspace;
    if (stage != InspectionStage.inspecting || open == null) return;
    if (!open.items.any((item) => item.id == fault.itemId)) return;
    reviewingSummaryFault = true;
    open.expand(fault.itemId);
    pendingScrollItemId = fault.itemId;
    notifyListeners();
  }

  Future<void> returnToSummary() async {
    // Rebuild faults before showing the summary so edits made during review
    // are included in the report, including description changes.
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
    lastScan = null;
    // Every scan-shaped field goes together. Leaving isScanning set here was
    // an unrecoverable latch: scanCac's own guard then refused every retry,
    // the scanning card renders no buttons, and the view model is a lazy
    // singleton — the only way out was killing the extension with a walked
    // PMCS inside it.
    isScanning = false;
    scanAttempts = 0;
    scanGeneration++;
    stage = InspectionStage.phaseSelect;
    notifyListeners();
  }

  /// Reads the operator's CAC. Leaves the result on [lastScan] for the
  /// sign-off card to render — a rejection is information the operator acts
  /// on, not an error to swallow.
  Future<void> scanCac() async {
    if (isScanning) return;

    final generation = ++scanGeneration;
    isScanning = true;
    scanAttempts++;
    lastScan = null;
    notifyListeners();

    CacScan outcome;
    try {
      outcome = await verifyOperatorIdentity();
      debugPrint('[IvyPulse] scanCac — attempt $scanAttempts, '
          '${outcome.isVerified ? 'verified' : outcome.rejection!.name}');
    } catch (e) {
      // A thrown scanner is still just a scan that did not happen; the
      // operator keeps every way out they had before.
      debugPrint('[IvyPulse] scanCac failed: $e');
      outcome = const CacScan.rejected(CacRejection.noCodeFound);
    }

    // The operator gave up on this scan while it was still open — cancelled
    // it, or backed out to the phases. The camera is a separate activity that
    // can deliver its photo long afterwards, and writing it here would drag
    // them back onto a scan they have already left, or re-latch isScanning
    // over a capture that has since been replaced by a live one.
    if (generation != scanGeneration) {
      debugPrint('[IvyPulse] scanCac — result for abandoned scan, dropped');
      return;
    }

    lastScan = outcome;
    if (outcome.isVerified) {
      scanAttempts = 0;
    } else if (outcome.rejection == CacRejection.cameraTimedOut) {
      // The camera never came back, so no frame was ever judged. Counting it
      // would spend one of the operator's attempts on advice about how they
      // held the card — see [cancelScan] for why that is worse than useless.
      untallyAttempt();
    }
    isScanning = false;
    notifyListeners();
  }

  /// Takes back the attempt [scanCac] optimistically counted when a scan ends
  /// without the camera ever judging a frame.
  ///
  /// [scanAttempts] drives two things that must only ever answer to frames the
  /// decoder actually looked at: the escalating retry hint, and whether SCAN
  /// AGAIN or SUBMIT UNVERIFIED leads the refused card. A Soldier who backs out
  /// of the chooser twice has photographed nothing, so telling them to turn the
  /// card sideways to kill glare is a confident instruction about a frame that
  /// does not exist — and steering them to an unverified 5988-E because the
  /// camera was fumbled, rather than because the card would not read, is worse.
  void untallyAttempt() {
    if (scanAttempts > 0) scanAttempts--;
  }

  /// Gives up on a scan the operator is tired of waiting for.
  ///
  /// Deliberately not routed through [scanCac]: that method's
  /// `if (isScanning) return` guard is what stops a double tap opening two
  /// cameras, and it would swallow this too.
  ///
  /// Lands the operator on the refused card — SCAN AGAIN and SUBMIT
  /// UNVERIFIED, the two things they can actually do — rather than inventing
  /// a fifth sign-off state that would say the same thing with no controls on
  /// it. The scanner is told as well, but nothing waits on it: the camera is
  /// a full-screen activity the WebView does not own, so [CacScannerStrategy]
  /// cannot close it and only promises to drop whatever lands later.
  void cancelScan() {
    if (!isScanning) return;

    scanGeneration++;
    isScanning = false;
    untallyAttempt();
    lastScan = const CacScan.rejected(CacRejection.cancelled);
    notifyListeners();

    cacScanner.cancel().catchError((Object e) {
      debugPrint('[IvyPulse] cancelScan — scanner refused the cancel: $e');
    });
  }

  /// True once a CAC has been read and accepted — the only state from which
  /// an ordinary submit is allowed.
  bool get isSignedOff => lastScan?.isVerified ?? false;

  /// True when the operator has tried and been refused, which is the only
  /// state that may be overridden.
  bool get canSubmitUnverified => lastScan != null && !lastScan!.isVerified;

  /// Submits under the scanned CAC.
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

  /// Submits with the signature block explicitly marked unverified, carrying
  /// the reason the scan could not happen.
  ///
  /// The report still goes to the maintainer — a deadlining fault nobody can
  /// see is worse than one signed by a name the app could not check — but it
  /// goes out saying so, on disk and on both transports.
  Future<void> submitUnverified() async {
    if (session == null) return;

    final rejection = lastScan?.rejection;
    if (rejection == null) {
      snackBarService.enqueue('Scan a CAC before submitting', isError: true);
      return;
    }

    await submitWith(PmcsSignature.unverified(
      blockedBy: rejection,
      signedAt: DateTime.now().toUtc(),
    ));
  }

  /// Submits with the operator's name and DoD ID typed in by hand — the
  /// fallback for a scan that failed.
  ///
  /// Goes out *unverified*, carrying both the reason the scan could not
  /// happen and the typed identity, so a maintainer gets a 5988-E they can
  /// chase without ever being shown a green tick this device cannot stand
  /// behind. The same gate as [submitUnverified]: there has to have been a
  /// refused scan, or the operator is sent to scan first.
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
      signedAt: DateTime.now().toUtc(),
      attestedBy: identity,
    ));
  }

  Future<void> submitWith(PmcsSignature signature) async {
    final current = session;
    if (current == null || isBusy) return;

    isBusy = true;
    notifyListeners();

    // Stamped on the session before it is closed out, so the signature lands
    // on the stored report, the session row, and both wire payloads from the
    // single object all three are built from.
    final signed = current.copyWith(
      signature: signature,
      operator: signature.displayName,
    );
    session = signed;

    final PmcsReport report;
    try {
      report = await submitSession(signed);
    } catch (e) {
      // Nothing was stored, so the session is intact and still submittable.
      debugPrint('[IvyPulse] submit failed: $e');
      snackBarService.enqueue('Could not submit PMCS — $e', isError: true);
      isBusy = false;
      notifyListeners();
      return;
    }
    debugPrint('[IvyPulse] submit — ${report.entityId} '
        '${report.statusLabel}, ${report.faults.length} fault(s)');

    // Before the publish, not after: the row is stored and the YOURS tab
    // should show it whether or not the transports are up.
    onReportSubmitted?.call(report);

    await resetToSetup();
    submittedReport = report;
    stage = InspectionStage.submitted;
    notifyListeners();

    // The receipt is available as soon as the local save succeeds. Network
    // callbacks only update the receipt that belongs to this report.
    publishPmcsReport(report).then((outcome) {
      if (!identical(submittedReport, report)) return;
      submissionDelivery = outcome;
      notifyListeners();
    }).catchError((e) {
      debugPrint('[IvyPulse] Publish error: $e');
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
    } catch (e) {
      debugPrint('[IvyPulse] discardSession failed: $e');
      snackBarService.enqueue('Could not discard PMCS — $e', isError: true);
      isBusy = false;
      notifyListeners();
      return;
    }
    await resetToSetup();
  }

  Future<void> resetToSetup() async {
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
    lastScan = null;
    // Same three as backToPhases, for the same reason, and because this runs
    // after every submit: a scan state left standing here bleeds one vehicle's
    // sign-off into the next vehicle's PMCS.
    isScanning = false;
    scanAttempts = 0;
    scanGeneration++;
    stage = InspectionStage.setup;
    try {
      openSessions = await loadOpenSessions();
    } catch (e) {
      debugPrint('[IvyPulse] resetToSetup: could not reload sessions: $e');
      openSessions = [];
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  PmcsPhase? get activePhase => workspace?.phase;

  Map<String, CheckResult> get results => workspace?.results ?? const {};

  Set<String> get collapsedItemIds => workspace?.collapsedItemIds ?? const {};

  /// The one check open at full size, if any.
  String? get expandedItemId => workspace?.expandedItemId;

  bool isItemExpanded(String itemId) => workspace?.isExpanded(itemId) ?? false;

  List<PmcsCategory> get phaseCategories => workspace?.categories ?? const [];

  List<PmcsCheckItem> get phaseItems => workspace?.items ?? const [];

  int get answeredCount => workspace?.answeredCount ?? 0;

  /// Counts survive closing a phase and are restored from saved answers when
  /// resuming a session. Only items in the current catalog count as progress.
  int answeredCountFor(PmcsPhase phase) => phaseAnswerCounts[phase] ?? 0;

  int get totalCount => workspace?.totalCount ?? 0;

  FaultTally get phaseTally => workspace?.tally ?? const FaultTally();

  FaultTally get sessionTally => FaultTally.from(sessionFaults);

  bool get isPhaseComplete => workspace?.isComplete ?? false;

  String? get nextUnansweredItemId => workspace?.nextUnansweredItemId;
}
