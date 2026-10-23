import 'package:flutter/material.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_live_feedback.dart';
import 'package:cac_ocr/src/presentation/viewfinder/cac_diagnostics_view.dart';
import 'package:cac_ocr/src/presentation/cac_scan_controller.dart';
import 'package:cac_ocr/src/presentation/viewfinder/cac_viewfinder.dart';
import 'package:cac_ocr/src/presentation/ocr/cac_ocr_refused.dart';
import 'package:cac_ocr/src/presentation/ocr/cac_ocr_prompt.dart';
import 'package:cac_ocr/src/presentation/ocr/cac_ocr_scanning.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_text.dart';
import 'package:cac_ocr/src/presentation/ocr/cac_typed_identity_form.dart';
import 'package:cac_ocr/src/presentation/ocr/cac_ocr_verified.dart';

class CacOcr extends StatelessWidget {
  final CacScanController controller;
  final VoidCallback onSubmit;
  final VoidCallback? onSubmitUnverified;
  final CacTypedIdentitySubmit? onSubmitTyped;
  final bool scannerAvailable;
  final bool isBusy;
  final bool showAimGuide;
  final int maxLeadingRetries;
  final CacOcrText text;

  const CacOcr({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.onSubmitUnverified,
    this.onSubmitTyped,
    this.scannerAvailable = true,
    this.isBusy = false,
    this.showAimGuide = true,
    this.maxLeadingRetries = defaultMaxLeadingRetries,
    this.text = const CacOcrText(),
  });

  static const int defaultMaxLeadingRetries =
      CacOcrRefused.defaultMaxLeadingRetries;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final content = buildState();
        return switch (controller.cacScanner) {
          CacLiveFeedback(diagnostics: final diagnostics?) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [content, CacDiagnosticsView(diagnostics: diagnostics)],
            ),
          _ => content,
        };
      },
    );
  }

  Widget buildState() {
    final scanner = controller.cacScanner;
    final scansBothSides = scansBothCacSides(scanner);
    final fromPhoto = !hasCacLivePreview(scanner);
    final scan = controller.lastScan;
    if (controller.isScanning) {
      return CacOcrScanning(
        scanner: scanner,
        isBusy: isBusy,
        onCancel: controller.cancelScan,
        text: text,
      );
    }
    if (scan?.identity case final identity?) {
      return CacOcrVerified(
        identity: identity,
        fromPhoto: fromPhoto,
        isBusy: isBusy,
        onSubmit: onSubmit,
        onRescan: controller.scan,
        text: text,
      );
    }
    if (scan?.rejection case final rejection?) {
      final submitTyped = onSubmitTyped;
      return CacOcrRefused(
        rejection: rejection,
        expiredCard: scan?.expiredCard,
        scanAttempts: controller.scanAttempts,
        scansBothSides: scansBothSides,
        fromPhoto: fromPhoto,
        isBusy: isBusy,
        onScan: controller.scan,
        onSubmitUnverified: onSubmitUnverified,
        typedIdentityForm: submitTyped == null
            ? null
            : CacTypedIdentityForm(
                onSubmit: submitTyped,
                isBusy: isBusy,
                text: text,
              ),
        showAimGuide: showAimGuide,
        maxLeadingRetries: maxLeadingRetries,
        text: text,
      );
    }
    return CacOcrPrompt(
      scansBothSides: scansBothSides,
      scannerAvailable: scannerAvailable,
      isBusy: isBusy,
      onScan: controller.scan,
      showAimGuide: showAimGuide,
      text: text,
    );
  }
}
