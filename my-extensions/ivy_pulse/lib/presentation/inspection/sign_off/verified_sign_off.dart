import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/cac_identity.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/inspection/sign_off/scan_guidance.dart';

class VerifiedSignOff extends StatelessWidget {
  final CacIdentity identity;
  final bool scansBothSides;
  final bool isBusy;
  final VoidCallback onSubmit;
  final VoidCallback onRescan;

  const VerifiedSignOff({
    super.key,
    required this.identity,
    required this.scansBothSides,
    required this.isBusy,
    required this.onSubmit,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
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
          onPressed: isBusy ? null : onSubmit,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: isBusy ? null : onRescan,
            child: const Text('NOT ME — RESCAN'),
          ),
        ),
        const SizedBox(height: 4),
        if (!scansBothSides) const CacGalleryAdvisory(),
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
