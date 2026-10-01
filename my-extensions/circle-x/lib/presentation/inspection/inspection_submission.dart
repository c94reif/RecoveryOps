part of 'inspection_view_model.dart';

/// CAC sign-off, report submission, and delivery status.
mixin _InspectionSubmission on _InspectionState {
  CacScan? get lastScan => identityScan.lastScan;
  set lastScan(CacScan? value) => identityScan.lastScan = value;
  bool get isScanning => identityScan.isScanning;
  int get scanAttempts => identityScan.scanAttempts;
  set scanAttempts(int value) => identityScan.scanAttempts = value;

  DeliveryStatus? deliveryStatus(TransportKind transport) => submittedReport ==
          null
      ? null
      : publishPmcsReport.delivery.status(submittedReport!.entityId, transport);

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
      debugPrint('[CircleX] submit failed: $error');
      snackBarService.enqueue('Could not submit PMCS — $error', isError: true);
      isBusy = false;
      notifyListeners();
      return;
    }
    debugPrint('[CircleX] submit — ${report.entityId} '
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
      debugPrint('[CircleX] Publish error: $error');
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
}
