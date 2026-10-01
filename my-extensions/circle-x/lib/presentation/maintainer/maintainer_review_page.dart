import 'package:flutter/material.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';
import 'package:circle_x/domain/services/cac_scanner_strategy.dart';
import 'package:circle_x/domain/services/id_generator.dart';
import 'package:circle_x/domain/services/speech_recognition_strategy.dart';
import 'package:circle_x/domain/usecases/identity/verify_operator_identity.dart';
import 'package:circle_x/domain/usecases/publishing/publish_pmcs_report.dart';
import 'package:circle_x/domain/usecases/reporting/submit_maintainer_review.dart';
import 'package:circle_x/presentation/common/widgets/confirm_dialog.dart';
import 'package:circle_x/presentation/inspection/viewfinder/cac_viewfinder.dart';
import 'package:circle_x/presentation/maintainer/maintainer_review_summary.dart';
import 'package:circle_x/presentation/maintainer/maintainer_description_field.dart';
import 'package:circle_x/presentation/maintainer/maintainer_fault_search.dart';
import 'package:circle_x/presentation/maintainer/maintainer_review_view_model.dart';
import 'package:circle_x/presentation/maintainer/review_completion_dialog.dart';
import 'package:circle_x/presentation/maintainer/swipe_fault_card.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';

class MaintainerReviewPage extends StatefulWidget {
  final PmcsReport report;
  final VoidCallback onExit;
  const MaintainerReviewPage(
      {super.key, required this.report, required this.onExit});

  @override
  State<MaintainerReviewPage> createState() => _MaintainerReviewPageState();
}

class _MaintainerReviewPageState extends State<MaintainerReviewPage> {
  late final MaintainerReviewViewModel model;
  final reviewScroll = ScrollController();
  bool searching = false;
  bool showingCompletion = false;

  @override
  void initState() {
    super.initState();
    model = MaintainerReviewViewModel(
      report: widget.report,
      reviewId: getIt<IdGenerator>().newId(),
      submitReview: getIt<SubmitMaintainerReview>(),
      publish: getIt<PublishPmcsReport>(),
      onSaved: getIt<ReportsViewModel>().addOutgoing,
      scanner: getIt<CacScannerStrategy>(),
      speech: getIt<SpeechRecognitionStrategy>(),
      verifyIdentity: getIt<VerifyOperatorIdentity>(),
    );
  }

  @override
  void dispose() {
    reviewScroll.dispose();
    model.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (model.busy) return;
    if (model.saved == null &&
        (model.reviewedCount > 0 ||
            model.descriptions.any((text) => text.trim().isNotEmpty))) {
      final discard = await showConfirmDialog(context,
          title: 'Discard this review?',
          message:
              'Your unsent maintainer notes and decisions will be discarded.',
          confirmLabel: 'Discard',
          destructive: true);
      if (!discard || !mounted) return;
    }
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    widget.onExit();
  }

  Future<void> searchFaults() async {
    if (searching || model.busy || model.signing || model.saved != null) return;
    FocusScope.of(context).unfocus();
    setState(() => searching = true);
    try {
      final selected = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => MaintainerFaultSearch(
          report: model.report,
          decisions: List.of(model.decisions),
          descriptions: List.of(model.descriptions),
        ),
      );
      if (!mounted || selected == null) return;
      model.select(selected);
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> decide(bool verified) async {
    if (showingCompletion || model.busy) return;
    FocusScope.of(context).unfocus();
    final wasComplete = model.complete;
    final wasAllVerified = model.allVerified;
    model.decide(verified);
    final justFinished = !wasComplete && model.complete;
    final justVerifiedAll = !wasAllVerified && model.allVerified;
    if (!justFinished && !justVerifiedAll) return;
    showingCompletion = true;
    final sign = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .8),
      builder: (_) => ReviewCompletionDialog(
        vehicle: model.report.summary,
        verifiedCount: model.verifiedCount,
        total: model.decisions.length,
      ),
    );
    if (!mounted) return;
    showingCompletion = false;
    if (sign == true) model.requestSignature();
  }

  Widget buildFault() {
    final index = model.index;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Fault ${index + 1} of ${model.report.faults.length}',
          style:
              const TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      LinearProgressIndicator(
          value: model.reviewedCount / model.decisions.length),
      const SizedBox(height: 10),
      Semantics(
        liveRegion: true,
        child: Text(
          model.decisions[index] == null
              ? 'Not reviewed'
              : 'Reviewed · not submitted',
          style: TextStyle(
              color: model.decisions[index] == null ? circleXAmber : dashBlue,
              fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 16),
      SwipeFaultCard(
        key: ValueKey(index),
        enabled: !model.isDictating,
        onAnimatingChanged: model.setDecisionAnimating,
        hasNext: model.complete && model.decisions.length > 1 ||
            model.decisions
                .asMap()
                .entries
                .any((entry) => entry.key != index && entry.value == null),
        fault: model.report.faults[index],
        decision: model.decisions[index],
        onDecision: decide,
      ),
      const SizedBox(height: 16),
      MaintainerDescriptionField(
        key: ValueKey(('maintainer-description', index)),
        value: model.descriptions[index],
        onChanged: model.describe,
        onDictate: model.toggleDictation,
        isListening: model.isDictating,
        enabled: !model.decisionAnimating,
        message: model.dictationMessage,
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        TextButton(
            onPressed:
                !model.busy && index > 0 ? () => model.select(index - 1) : null,
            child: const Text('Previous')),
        TextButton(
            onPressed: !model.busy && index + 1 < model.decisions.length
                ? () => model.select(index + 1)
                : null,
            child: const Text('Next')),
      ]),
      if (model.complete) ...[
        Text(model.allVerified ? 'All faults verified' : 'All faults reviewed',
            style: const TextStyle(
                color: serviceableGreen,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        const SizedBox(height: 6),
      ],
      Text(
          '${model.reviewedCount} of ${model.decisions.length} reviewed. '
          'Decisions remain a draft until you CAC-sign the batch.',
          style: const TextStyle(color: textSecondary, fontSize: 12)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: model.complete && !model.busy
            ? () {
                FocusScope.of(context).unfocus();
                model.requestSignature();
              }
            : null,
        icon: const Icon(Icons.badge_outlined),
        label: const Text('Submit review'),
      ),
    ]);
  }

  String rejectionMessage(CacRejection rejection) => switch (rejection) {
        CacRejection.noCamera =>
          'No camera is available. A CAC scan is required to submit this review.',
        CacRejection.expired =>
          'This CAC is expired. Scan a current CAC to submit this review.',
        CacRejection.cameraTimedOut =>
          'The camera did not respond. Retry the CAC scan.',
        _ => rejection.message,
      };

  Widget buildSignature() {
    final rejection = model.scan.lastScan?.rejection;
    final scanner = model.scan.cacScanner;
    final verified = model.verifiedCount;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Sign the review batch',
          style: TextStyle(
              color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(
          '$verified verified · ${model.decisions.length - verified} not verified'),
      const SizedBox(height: 12),
      Text(
          scansBothCacSides(scanner)
              ? 'Scan the front of your CAC for your name, then the back for your DoD ID. A successful scan signs and submits all ${model.decisions.length} decisions and your notes.'
              : 'Scan the back of your CAC. A successful scan signs and submits all ${model.decisions.length} decisions and your notes.',
          style: const TextStyle(color: textPrimary, height: 1.4)),
      const SizedBox(height: 16),
      if (model.scan.isScanning) ...[
        buildCacViewfinder(scanner) ??
            const Column(children: [
              LinearProgressIndicator(),
              SizedBox(height: 12),
              Text('Reading your CAC…'),
            ]),
        TextButton(
            onPressed: model.cancelScan, child: const Text('Cancel scan')),
      ] else if (model.saving) ...[
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        const Text('Saving signed review…'),
      ] else ...[
        if (rejection != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(rejectionMessage(rejection),
                style: const TextStyle(color: circleXAmber)),
          ),
        if (model.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(model.error!, style: const TextStyle(color: redXRed)),
          ),
        ElevatedButton.icon(
            onPressed: model.scanAndSubmit,
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Scan CAC & submit')),
        TextButton(onPressed: model.edit, child: const Text('Back to review')),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: model,
        builder: (context, _) => SafeArea(
            child: Column(children: [
          Row(children: [
            IconButton(
                tooltip: 'Back to maintainer',
                onPressed: model.busy ? null : leave,
                icon: const Icon(Icons.arrow_back)),
            Expanded(
                child: Text(model.report.summary,
                    style: const TextStyle(
                        color: textPrimary, fontWeight: FontWeight.w700))),
            if (!model.signing && model.saved == null)
              IconButton(
                tooltip: 'Search faults',
                onPressed: model.busy || searching ? null : searchFaults,
                icon: const Icon(Icons.search),
              ),
          ]),
          Expanded(child: LayoutBuilder(builder: (context, constraints) {
            final reviewing = model.saved == null && !model.signing;
            final bottomPadding = 12 + MediaQuery.viewInsetsOf(context).bottom;
            // Keep the current offset valid even when the next fault is shorter.
            final minimumHeight = reviewing && reviewScroll.hasClients
                ? (constraints.maxHeight +
                        reviewScroll.offset -
                        12 -
                        bottomPadding)
                    .clamp(0.0, double.infinity)
                : 0.0;
            return SingleChildScrollView(
              key: ValueKey(model.saved != null
                  ? 'submitted-review'
                  : model.signing
                      ? 'sign-review'
                      : 'review-faults'),
              controller: reviewing ? reviewScroll : null,
              padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minimumHeight),
                child: model.saved != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            MaintainerReviewSummary(
                                review: model.saved!.maintainerReview!,
                                faults: model.report.faults),
                            const SizedBox(height: 12),
                            Text(model.delivery == null
                                ? 'Review saved on this device. Sending…'
                                : model.delivery!.allSucceeded
                                    ? 'Review sent.'
                                    : 'Review saved. Pending delivery will retry on reconnect.'),
                            const SizedBox(height: 12),
                            ElevatedButton(
                                onPressed: widget.onExit,
                                child: const Text('Done')),
                          ])
                    : model.signing
                        ? buildSignature()
                        : buildFault(),
              ),
            );
          })),
        ])),
      );
}
