part of 'inspection_view_model.dart';

/// Checklist answers, fault notes, phase navigation, and summary review.
mixin _InspectionChecklist on _InspectionState {
  bool get isListening => dictation.isListening;
  String? get listeningItemId => dictation.listeningItemId;

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
      debugPrint('[CircleX] openPhase failed: $error');
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
      debugPrint('[CircleX] answer failed: $error');
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
      debugPrint('[CircleX] saveNote failed: $error');
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

      debugPrint('[CircleX] completeActivePhase — ${phase.wireName}, '
          '${outcome.faults.length} fault(s)');
    } catch (error) {
      debugPrint('[CircleX] completeActivePhase failed: $error');
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

  PmcsPhase? get activePhase => workspace?.phase;

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
