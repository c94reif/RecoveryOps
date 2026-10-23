import 'package:flutter/material.dart';
import 'package:cac_ocr/cac_ocr.dart';
import 'package:circle_x/presentation/common/widgets/confirm_dialog.dart';
import 'package:circle_x/presentation/common/widgets/section_label.dart';
import 'package:circle_x/presentation/inspection/inspection_view_model.dart';
import 'package:circle_x/presentation/inspection/pmcs_sign_off_text.dart';

class SignOffCard extends StatelessWidget {
  final InspectionViewModel viewModel;

  const SignOffCard({super.key, required this.viewModel});

  static const int maxLeadingRetries = CacOcr.defaultMaxLeadingRetries;
  static const double cardWidth = CacAimGuide.cardWidth;
  static const double cardHeight = CacAimGuide.cardHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(text: 'SIGN OFF'),
        const SizedBox(height: 8),
        CacOcr(
          controller: viewModel.identityScan,
          scannerAvailable: viewModel.cacScannerAvailable,
          isBusy: viewModel.isBusy,
          text: pmcsSignOffText,
          onSubmit: viewModel.submit,
          onSubmitUnverified: () => confirmUnverified(context),
          onSubmitTyped: viewModel.submitAttested,
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
