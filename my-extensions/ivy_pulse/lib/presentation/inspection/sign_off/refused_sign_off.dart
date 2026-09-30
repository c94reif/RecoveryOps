import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/usecases/identity/cac_retry_hint.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/inspection/sign_off/scan_guidance.dart';

class RefusedSignOff extends StatelessWidget {
  final CacRejection rejection;
  final int scanAttempts;
  final bool scansBothSides;
  final bool isBusy;
  final VoidCallback onScan;
  final VoidCallback onSubmitUnverified;
  final Widget typedIdentityForm;

  const RefusedSignOff({
    super.key,
    required this.rejection,
    required this.scanAttempts,
    required this.scansBothSides,
    required this.isBusy,
    required this.onScan,
    required this.onSubmitUnverified,
    required this.typedIdentityForm,
  });

  static const int maxLeadingRetries = 3;

  @override
  Widget build(BuildContext context) {
    final retryLeads =
        rejection.isWorthRetrying && scanAttempts <= maxLeadingRetries;
    final hint = rejection.isWorthRetrying
        ? cacRetryHint(scanAttempts, bothSides: scansBothSides)
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
          buildUnverifiedLink(),
        ] else ...[
          buildUnverified(),
          const SizedBox(height: 4),
          buildScanAgainLink(),
        ],
        if (rejection.isWorthRetrying) ...[
          const SizedBox(height: 10),
          CacAimGuide(scansBothSides: scansBothSides),
        ],
        const SizedBox(height: 14),
        typedIdentityForm,
        const SizedBox(height: 6),
        const Text(
          'An unverified PMCS still reaches the maintainer, marked as signed '
          'by nobody this device could check.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, fontSize: 11, height: 1.4),
        ),
        if (!scansBothSides && rejection != CacRejection.noCamera) ...[
          const SizedBox(height: 8),
          const CacGalleryAdvisory(),
        ],
      ],
    );
  }

  Widget buildScanAgain() => CustomButton(
        text: 'SCAN AGAIN',
        icon: Icons.badge_outlined,
        onPressed: isBusy ? null : onScan,
      );

  Widget buildScanAgainLink() => Align(
        alignment: Alignment.center,
        child: SizedBox(
          height: minTouchTarget,
          child: TextButton(
            onPressed: isBusy ? null : onScan,
            child: const Text('SCAN AGAIN'),
          ),
        ),
      );

  Widget buildUnverified() => CustomButton(
        text: 'SUBMIT UNVERIFIED',
        icon: Icons.gpp_bad_outlined,
        color: redXRed,
        onPressed: isBusy ? null : onSubmitUnverified,
      );

  Widget buildUnverifiedLink() => Align(
        alignment: Alignment.center,
        child: SizedBox(
          height: minTouchTarget,
          child: TextButton(
            onPressed: isBusy ? null : onSubmitUnverified,
            style: TextButton.styleFrom(foregroundColor: redXRed),
            child: const Text('SUBMIT UNVERIFIED'),
          ),
        ),
      );
}
