import 'package:flutter/material.dart';
import 'package:cac_ocr/src/domain/cac_identity.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_aim_guide.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_button.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_link_button.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_note.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_panel.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_theme.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_text.dart';

class CacOcrRefused extends StatelessWidget {
  final CacRejection rejection;

  final CacIdentity? expiredCard;
  final int scanAttempts;
  final bool scansBothSides;
  final bool fromPhoto;
  final bool isBusy;
  final VoidCallback onScan;
  final VoidCallback? onSubmitUnverified;
  final Widget? typedIdentityForm;
  final bool showAimGuide;
  final int maxLeadingRetries;
  final CacOcrText text;

  const CacOcrRefused({
    super.key,
    required this.rejection,
    this.expiredCard,
    required this.scanAttempts,
    required this.scansBothSides,
    required this.fromPhoto,
    required this.isBusy,
    required this.onScan,
    this.onSubmitUnverified,
    this.typedIdentityForm,
    this.showAimGuide = true,
    this.maxLeadingRetries = defaultMaxLeadingRetries,
    this.text = const CacOcrText(),
  });

  static const int defaultMaxLeadingRetries = 3;

  @override
  Widget build(BuildContext context) {
    final theme = CacOcrTheme.of(context);
    final allowsUnverified = onSubmitUnverified != null;
    final retryLeads = !allowsUnverified ||
        (rejection.isWorthRetrying && scanAttempts <= maxLeadingRetries);
    final hint = rejection.isWorthRetrying
        ? text.retryHint?.call(scanAttempts, scansBothSides)
        : null;
    final typedForm = typedIdentityForm;
    final unverifiedNotice = allowsUnverified ? text.unverifiedNotice : null;
    final gallery = fromPhoto && rejection != CacRejection.noCamera
        ? text.galleryAdvisory
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rejection == CacRejection.expired)
          buildExpiredBanner(theme)
        else
          buildBanner(theme),
        if (hint != null) ...[
          const SizedBox(height: 8),
          CacNote(
            icon: Icons.tips_and_updates_outlined,
            text: hint,
            color: theme.accent,
            textColor: theme.text,
          ),
        ],
        const SizedBox(height: 12),
        if (retryLeads) ...[
          CacButton(
            text: text.scanAgainButton,
            icon: Icons.badge_outlined,
            onPressed: isBusy ? null : onScan,
          ),
          if (allowsUnverified) ...[
            const SizedBox(height: 4),
            CacLinkButton(
              text: text.unverifiedButton,
              color: theme.danger,
              onPressed: isBusy ? null : onSubmitUnverified,
            ),
          ],
        ] else ...[
          CacButton(
            text: text.unverifiedButton,
            icon: Icons.gpp_bad_outlined,
            color: theme.danger,
            onPressed: isBusy ? null : onSubmitUnverified,
          ),
          const SizedBox(height: 4),
          CacLinkButton(
            text: text.scanAgainButton,
            onPressed: isBusy ? null : onScan,
          ),
        ],
        if (showAimGuide && rejection.isWorthRetrying) ...[
          const SizedBox(height: 10),
          CacAimGuide(scansBothSides: scansBothSides, text: text),
        ],
        if (typedForm != null) ...[
          const SizedBox(height: 14),
          typedForm,
        ],
        if (unverifiedNotice != null) ...[
          SizedBox(height: typedForm == null ? 14 : 6),
          Text(
            unverifiedNotice,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.mutedText, fontSize: 11, height: 1.4),
          ),
        ],
        if (gallery != null) ...[
          const SizedBox(height: 8),
          CacNote(
            icon: Icons.photo_camera_back_outlined,
            text: gallery,
            color: theme.warning,
          ),
        ],
      ],
    );
  }

  Widget buildBanner(CacOcrTheme theme) => CacPanel(
        tone: CacTone.warning,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.gpp_maybe_outlined, color: theme.warning, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text.rejectionMessage(rejection),
                style: TextStyle(
                  color: theme.text,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );

  /// Says plainly that the card ran out, whose it is and when, so it does not
  /// read like one more misread worth another try.
  Widget buildExpiredBanner(CacOcrTheme theme) {
    final card = expiredCard;
    final holder = card == null ? null : text.expiredHolder?.call(card);
    final expiredOn =
        card?.cardExpiresOn == null ? null : text.expiredOnLine?.call(card!);
    return CacPanel(
      tone: CacTone.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_busy_outlined, color: theme.danger, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text.expiredTitle,
                  style: TextStyle(
                    color: theme.danger,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          if (holder != null && holder.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              holder,
              style: TextStyle(
                color: theme.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (expiredOn != null) ...[
            const SizedBox(height: 2),
            Text(
              expiredOn,
              style: TextStyle(
                color: theme.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            text.rejectionMessage(rejection),
            style: TextStyle(color: theme.text, fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }
}
