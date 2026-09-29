import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/cac_identity.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/usecases/identity/cac_retry_hint.dart';
import 'package:ivy_pulse/presentation/common/widgets/confirm_dialog.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/common/widgets/section_label.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/typed_identity_form.dart';
import 'package:ivy_pulse/presentation/inspection/viewfinder/cac_viewfinder.dart';

class SignOffCard extends StatelessWidget {
  final InspectionViewModel viewModel;

  const SignOffCard({super.key, required this.viewModel});

  static const int maxLeadingRetries = 3;

  static const double cardWidth = 88;

  static const double cardHeight = cardWidth / 1.587;

  bool get scansBothSides => scansBothCacSides(viewModel.cacScanner);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(text: 'SIGN OFF'),
        const SizedBox(height: 8),
        if (viewModel.isScanning)
          buildScanning()
        else if (viewModel.isSignedOff)
          buildVerified(viewModel.lastScan!.identity!)
        else if (viewModel.canSubmitUnverified)
          buildRefused(context)
        else
          buildPrompt(),
      ],
    );
  }

  Widget buildPrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          scansBothSides
              ? 'A PMCS is signed by the Soldier who walked it. Scan the front '
                  'of your CAC for your name, then flip it when asked to read '
                  'the DoD ID number on the back.'
              : 'A PMCS is signed by the Soldier who walked it. Show the camera '
                  'the back of your CAC — it reads your DoD ID number.',
          style:
              const TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
        ),
        if (viewModel.cacScannerAvailable) ...[
          const SizedBox(height: 10),
          buildAimGuide(),
        ] else ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: circleXAmber, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'No camera reachable on this device — you will be offered an '
                  'unverified submission instead.',
                  style: TextStyle(
                    color: circleXAmber,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        CustomButton(
          text: 'SCAN CAC',
          icon: Icons.badge_outlined,
          onPressed: viewModel.isBusy ? null : viewModel.scanCac,
        ),
      ],
    );
  }

  Widget buildScanning() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCacViewfinder(viewModel.cacScanner) ??
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border, width: 1),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Reading the card — fill the frame with the back, the '
                      'side with the wide barcode strip.',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            height: minTouchTarget,
            child: TextButton(
              onPressed: viewModel.isBusy ? null : viewModel.cancelScan,
              child: const Text('CANCEL SCAN'),
            ),
          ),
        ),
        const Text(
          'Camera frames are discarded after reading. Cancelling closes the '
          'camera and leaves the PMCS unsigned.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget buildVerified(CacIdentity identity) {
    final detail = [
      if (identity.branch.isNotEmpty) identity.branch,
      if (identity.category.isNotEmpty) identity.category,
    ].join(' · ');
    final expiresOn = identity.cardExpiresOn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: serviceableGlow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: serviceableGreen, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined,
                      color: serviceableGreen, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      identity.displayName,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'DoD ID ${identity.edipi}',
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              if (expiresOn != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Card expires ${formatCardDate(expiresOn)}',
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
              if (identity.isCardExpiringSoon) ...[
                const SizedBox(height: 8),
                buildExpiryAdvisory(identity),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        CustomButton(
          text: 'SUBMIT PMCS',
          icon: Icons.send,
          onPressed: viewModel.isBusy ? null : viewModel.submit,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: viewModel.isBusy ? null : viewModel.scanCac,
            child: const Text('NOT ME — RESCAN'),
          ),
        ),
        const SizedBox(height: 4),
        if (!scansBothSides) buildGalleryAdvisory(),
      ],
    );
  }

  Widget buildExpiryAdvisory(CacIdentity identity) {
    final days = identity.daysUntilCardExpiry;
    final line = days != null && days < 0
        ? 'This CAC has expired since it was scanned. Draw a current card '
            'before the next PMCS.'
        : 'This CAC expires ${identity.cardExpiryCountdown}. Book an ID card '
            'appointment before it stops signing.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: circleXGlow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: circleXAmber, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event_busy_outlined, color: circleXAmber, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              line,
              style: const TextStyle(
                color: circleXAmber,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRefused(BuildContext context) {
    final rejection = viewModel.lastScan!.rejection!;
    final retryLeads = rejection.isWorthRetrying &&
        viewModel.scanAttempts <= maxLeadingRetries;
    final hint = rejection.isWorthRetrying
        ? cacRetryHint(viewModel.scanAttempts, bothSides: scansBothSides)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: circleXGlow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: circleXAmber, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.gpp_maybe_outlined,
                  color: circleXAmber, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rejection.message,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  color: masterChiefGreen, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hint,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (retryLeads) ...[
          buildScanAgain(),
          const SizedBox(height: 4),
          buildUnverifiedLink(context),
        ] else ...[
          buildUnverified(context),
          const SizedBox(height: 4),
          buildScanAgainLink(),
        ],
        if (rejection.isWorthRetrying) ...[
          const SizedBox(height: 10),
          buildAimGuide(),
        ],
        const SizedBox(height: 14),
        TypedIdentityForm(viewModel: viewModel),
        const SizedBox(height: 6),
        const Text(
          'An unverified PMCS still reaches the maintainer, marked as signed '
          'by nobody this device could check.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, fontSize: 11, height: 1.4),
        ),
        if (!scansBothSides && rejection != CacRejection.noCamera) ...[
          const SizedBox(height: 8),
          buildGalleryAdvisory(),
        ],
      ],
    );
  }

  Widget buildScanAgain() => CustomButton(
        text: 'SCAN AGAIN',
        icon: Icons.badge_outlined,
        onPressed: viewModel.isBusy ? null : viewModel.scanCac,
      );

  Widget buildScanAgainLink() => Align(
        alignment: Alignment.center,
        child: SizedBox(
          height: minTouchTarget,
          child: TextButton(
            onPressed: viewModel.isBusy ? null : viewModel.scanCac,
            child: const Text('SCAN AGAIN'),
          ),
        ),
      );

  Widget buildUnverified(BuildContext context) => CustomButton(
        text: 'SUBMIT UNVERIFIED',
        icon: Icons.gpp_bad_outlined,
        color: redXRed,
        onPressed: viewModel.isBusy ? null : () => confirmUnverified(context),
      );

  Widget buildUnverifiedLink(BuildContext context) => Align(
        alignment: Alignment.center,
        child: SizedBox(
          height: minTouchTarget,
          child: TextButton(
            onPressed:
                viewModel.isBusy ? null : () => confirmUnverified(context),
            style: TextButton.styleFrom(foregroundColor: redXRed),
            child: const Text('SUBMIT UNVERIFIED'),
          ),
        ),
      );

  Widget buildGalleryAdvisory() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.photo_camera_back_outlined,
            color: circleXAmber, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Ivy Pulse dropped the photo, but the camera app may have kept its '
            'own copy in the gallery. Delete it there.',
            style: TextStyle(
              color: circleXAmber,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildAimGuide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCardSchematic(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AimGuideLine(scansBothSides
                  ? '1. Show the front — your name below the photo'
                  : 'Turn the card over — the side the gate scans'),
              const SizedBox(height: 5),
              AimGuideLine(scansBothSides
                  ? '2. Flip when asked — DoD ID above the wide strip'
                  : 'Fill the box; the DoD ID number sits above the wide strip'),
              const SizedBox(height: 5),
              const AimGuideLine('It reads by itself — no button to press'),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildCardSchematic() {
    final width = scansBothSides ? cardHeight : cardWidth;
    final height = scansBothSides ? cardWidth : cardHeight;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: surfaceLight,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: border, width: 1),
              ),
            ),
          ),
          buildPrintedRule(top: 0.10, width: 0.40),
          buildPrintedRule(top: 0.20, width: 0.30),
          Positioned(
            left: width * 0.08,
            top: height * (scansBothSides ? 0.65 : 0.32),
            width: width * 0.62,
            height: height * 0.09,
            child: Container(
              decoration: BoxDecoration(
                color: serviceableGreen,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: masterChiefGreen, width: 1.2),
              ),
            ),
          ),
          Positioned(
            left: width * 0.08,
            top: height * (scansBothSides ? 0.30 : 0.58),
            width: width * (scansBothSides ? 0.44 : 0.84),
            height: height * (scansBothSides ? 0.28 : 0.14),
            child: Container(
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          buildPrintedRule(top: 0.86, width: 0.84),
        ],
      ),
    );
  }

  Widget buildPrintedRule({required double top, required double width}) {
    return Positioned(
      left: (scansBothSides ? cardHeight : cardWidth) * 0.08,
      top: (scansBothSides ? cardWidth : cardHeight) * top,
      width: (scansBothSides ? cardHeight : cardWidth) * width,
      height: 2,
      child: Container(color: border),
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

class AimGuideLine extends StatelessWidget {
  final String text;

  const AimGuideLine(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '·  ',
          style: TextStyle(color: textSecondary, fontSize: 11, height: 1.3),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

String formatCardDate(DateTime date) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  final utc = date.toUtc();
  return '${utc.day.toString().padLeft(2, '0')} '
      '${months[utc.month - 1]} ${utc.year}';
}
