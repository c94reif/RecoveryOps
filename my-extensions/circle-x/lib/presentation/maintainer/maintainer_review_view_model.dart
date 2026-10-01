import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/entities/publish_result.dart';
import 'package:circle_x/domain/services/cac_scanner_strategy.dart';
import 'package:circle_x/domain/services/speech_recognition_strategy.dart';
import 'package:circle_x/domain/services/user_notification_sink.dart';
import 'package:circle_x/domain/usecases/identity/verify_operator_identity.dart';
import 'package:circle_x/domain/usecases/publishing/publish_pmcs_report.dart';
import 'package:circle_x/domain/usecases/reporting/submit_maintainer_review.dart';
import 'package:circle_x/presentation/inspection/controllers/cac_scan_controller.dart';
import 'package:circle_x/presentation/inspection/controllers/fault_dictation_controller.dart';

class MaintainerReviewViewModel extends ChangeNotifier
    implements UserNotificationSink {
  static const maxDescriptionLength = 2000;
  final PmcsReport report;
  final String reviewId;
  final SubmitMaintainerReview submitReview;
  final PublishPmcsReport publish;
  final Future<void> Function(PmcsReport) onSaved;
  final CacScanController scan;
  late final FaultDictationController dictation;
  final List<bool?> decisions;
  final List<String> descriptions;
  int index = 0;
  bool signing = false;
  bool saving = false;
  bool decisionAnimating = false;
  bool disposed = false;
  int submissionGeneration = 0;
  String? error;
  String? dictationMessage;
  PmcsReport? saved;
  PublishResult? delivery;

  MaintainerReviewViewModel({
    required this.report,
    required this.reviewId,
    required this.submitReview,
    required this.publish,
    required this.onSaved,
    required CacScannerStrategy scanner,
    required SpeechRecognitionStrategy speech,
    required VerifyOperatorIdentity verifyIdentity,
  })  : decisions = List.filled(report.faults.length, null),
        descriptions = List.filled(report.faults.length, ''),
        scan = CacScanController(
            cacScanner: scanner, verifyOperatorIdentity: verifyIdentity) {
    scan.addListener(notifyListeners);
    dictation = FaultDictationController(speech: speech, notifications: this)
      ..addListener(notifyListeners);
  }

  bool get isDictating => dictation.isListening;
  bool get busy =>
      scan.isScanning || saving || isDictating || decisionAnimating;
  int get reviewedCount => decisions.whereType<bool>().length;
  bool get complete =>
      decisions.isNotEmpty && reviewedCount == decisions.length;

  void describe(String description) {
    if (signing || saved != null || busy) return;
    descriptions[index] = description;
  }

  void setDecisionAnimating(bool value) {
    if (disposed) return;
    decisionAnimating = value;
    notifyListeners();
  }

  @override
  void enqueue(String message,
      {bool isError = false, bool persistent = false}) {
    if (disposed) return;
    dictationMessage = message;
    notifyListeners();
  }

  Future<void> toggleDictation() async {
    if (disposed || signing || saved != null || decisionAnimating) {
      return;
    }
    final target = index;
    dictationMessage = null;
    await dictation.toggle(
      itemId: '$target',
      isCurrent: () =>
          !disposed && !signing && saved == null && index == target,
      onResult: (text) async {
        if (text.trim().isEmpty) return;
        final draft = [descriptions[target].trim(), text.trim()]
            .where((part) => part.isNotEmpty)
            .join(' ');
        // Match the submission limit without splitting Unicode characters.
        final limited = StringBuffer();
        for (final character in draft.characters) {
          if (limited.length + character.length > maxDescriptionLength) break;
          limited.write(character);
        }
        descriptions[target] = limited.toString();
        if (draft.length > descriptions[target].length) {
          dictationMessage =
              'Description limited to 2,000 characters. Review before submitting.';
        }
        notifyListeners();
      },
    );
  }

  void decide(bool verified) {
    if (signing || saved != null || busy) return;
    final alreadyComplete = complete;
    decisions[index] = verified;
    dictationMessage = null;
    final next = decisions.indexOf(null);
    if (next >= 0) index = next;
    if (next < 0 && alreadyComplete) index = (index + 1) % decisions.length;
    notifyListeners();
  }

  void select(int next) {
    if (signing ||
        saved != null ||
        busy ||
        next < 0 ||
        next >= decisions.length) {
      return;
    }
    index = next;
    dictationMessage = null;
    notifyListeners();
  }

  void requestSignature() {
    if (!complete || busy || saved != null) return;
    signing = true;
    error = null;
    scan.reset();
    notifyListeners();
  }

  void edit() {
    if (busy || saved != null) return;
    signing = false;
    submissionGeneration++;
    error = null;
    scan.reset();
    notifyListeners();
  }

  Future<void> scanAndSubmit() async {
    if (!signing || !complete || busy || saved != null || disposed) return;
    error = null;
    final generation = ++submissionGeneration;
    await scan.scan();
    if (disposed || generation != submissionGeneration || !signing) return;
    final identity = scan.lastScan?.identity;
    if (identity == null) return;
    saving = true;
    notifyListeners();
    try {
      saved = await submitReview(
        reviewId: reviewId,
        sourceReportId: report.entityId,
        identity: identity,
        faults: [
          for (var i = 0; i < report.faults.length; i++)
            FaultReview(
              itemId: report.faults[i].itemId,
              phase: report.faults[i].phase,
              verified: decisions[i]!,
              description: descriptions[i].trim(),
            ),
        ],
      );
    } catch (failure) {
      error =
          'Could not save the review. Your notes and decisions are still here. Try again.';
      debugPrint('[CircleX] Maintainer review save failed: $failure');
    } finally {
      saving = false;
    }
    final record = saved;
    if (record != null) {
      // The durable outbox already exists, even if the user closes this screen.
      unawaited(send(record));
      try {
        await onSaved(record);
      } catch (failure) {
        debugPrint(
            '[CircleX] Saved maintainer review refresh failed: $failure');
      }
    }
    if (!disposed) notifyListeners();
  }

  Future<void> send(PmcsReport record) async {
    try {
      delivery = await publish.publishPersisted(record);
    } catch (failure) {
      debugPrint('[CircleX] Review delivery is queued: $failure');
      delivery = const PublishResult(latticeOk: false, meshOk: false);
    }
    if (!disposed) notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    submissionGeneration++;
    scan.removeListener(notifyListeners);
    scan.dispose();
    dictation.removeListener(notifyListeners);
    dictation.dispose();
    super.dispose();
  }

  void cancelScan() {
    submissionGeneration++;
    scan.cancelScan();
  }
}
