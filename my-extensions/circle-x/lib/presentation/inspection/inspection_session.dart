part of 'inspection_view_model.dart';

mixin _InspectionSession on _InspectionState {
  Future<void> load() async {
    isBusy = true;
    notifyListeners();
    try {
      profile = await profileRepository.getProfile();
      openSessions = await loadOpenSessions();
      cacScannerAvailable = await cacScanner.isAvailable();
    } catch (error) {
      debugPrint('[CircleX] load error: $error');
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

    final uicError = Uic.validate(uic);
    if (uicError != null) {
      snackBarService.enqueue(uicError, isError: true);
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
      debugPrint('[CircleX] beginSession failed: $error');
      snackBarService.enqueue('Could not start PMCS — $error', isError: true);
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }

    debugPrint('[CircleX] beginSession — ${session!.sessionId} '
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
      debugPrint('[CircleX] resumeSession — no catalog: $error');
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

      debugPrint('[CircleX] resumeSession — ${open.sessionId}, '
          '${workspace?.phase.wireName ?? stage.name}');
    } catch (error) {
      debugPrint('[CircleX] resumeSession failed: $error');
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

  Future<void> discardSession() async {
    final current = session;
    if (current == null) return;

    isBusy = true;
    notifyListeners();

    try {
      await abandonSession(current.sessionId);
      debugPrint('[CircleX] discardSession — ${current.sessionId}');
    } catch (error) {
      debugPrint('[CircleX] discardSession failed: $error');
      snackBarService.enqueue('Could not discard PMCS — $error', isError: true);
      isBusy = false;
      notifyListeners();
      return;
    }
    await resetToSetup();
  }

  @override
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
      debugPrint('[CircleX] resetToSetup: could not reload sessions: $error');
      openSessions = [];
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
