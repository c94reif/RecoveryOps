import 'package:flutter/material.dart';
import 'package:ivy_pulse/presentation/common/widgets/confirm_dialog.dart';
import 'package:ivy_pulse/presentation/common/widgets/section_label.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/sign_off/refused_sign_off.dart';
import 'package:ivy_pulse/presentation/inspection/sign_off/scan_guidance.dart';
import 'package:ivy_pulse/presentation/inspection/sign_off/scan_progress.dart';
import 'package:ivy_pulse/presentation/inspection/sign_off/scan_prompt.dart';
import 'package:ivy_pulse/presentation/inspection/sign_off/verified_sign_off.dart';
import 'package:ivy_pulse/presentation/inspection/typed_identity_form.dart';
import 'package:ivy_pulse/presentation/inspection/viewfinder/cac_viewfinder.dart';

export 'package:ivy_pulse/presentation/inspection/sign_off/scan_guidance.dart'
    show AimGuideLine;
export 'package:ivy_pulse/presentation/inspection/sign_off/verified_sign_off.dart'
    show formatCardDate;

/// Selects the sign-off state and connects its actions to the inspection.
class SignOffCard extends StatelessWidget {
  final InspectionViewModel viewModel;

  const SignOffCard({super.key, required this.viewModel});

  static const int maxLeadingRetries = RefusedSignOff.maxLeadingRetries;
  static const double cardWidth = CacAimGuide.cardWidth;
  static const double cardHeight = CacAimGuide.cardHeight;

  bool get scansBothSides => scansBothCacSides(viewModel.cacScanner);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(text: 'SIGN OFF'),
        const SizedBox(height: 8),
        if (viewModel.isScanning)
          SignOffScanning(
            scanner: viewModel.cacScanner,
            isBusy: viewModel.isBusy,
            onCancel: viewModel.cancelScan,
          )
        else if (viewModel.isSignedOff)
          VerifiedSignOff(
            identity: viewModel.lastScan!.identity!,
            scansBothSides: scansBothSides,
            isBusy: viewModel.isBusy,
            onSubmit: viewModel.submit,
            onRescan: viewModel.scanCac,
          )
        else if (viewModel.canSubmitUnverified)
          RefusedSignOff(
            rejection: viewModel.lastScan!.rejection!,
            scanAttempts: viewModel.scanAttempts,
            scansBothSides: scansBothSides,
            isBusy: viewModel.isBusy,
            onScan: viewModel.scanCac,
            onSubmitUnverified: () => confirmUnverified(context),
            typedIdentityForm: TypedIdentityForm(viewModel: viewModel),
          )
        else
          SignOffPrompt(
            scansBothSides: scansBothSides,
            scannerAvailable: viewModel.cacScannerAvailable,
            isBusy: viewModel.isBusy,
            onScan: viewModel.scanCac,
          ),
      ],
    );
  }

  Future<void> confirmUnverified(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Submit unverified?',
      message: 'This PMCS will go out with no CAC behind it. The maintainer '
          'sees it flagged as unverified, and the reason is recorded.',
      confirmLabel: 'Submit Unverified',
      destructive: true,
    );
    if (confirmed) await viewModel.submitUnverified();
  }
}
