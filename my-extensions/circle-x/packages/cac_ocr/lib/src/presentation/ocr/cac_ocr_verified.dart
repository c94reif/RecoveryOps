import 'package:flutter/material.dart';
import 'package:cac_ocr/src/domain/cac_identity.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_button.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_link_button.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_note.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_panel.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_theme.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_text.dart';

class CacOcrVerified extends StatelessWidget {
  final CacIdentity identity;

  final bool fromPhoto;
  final bool isBusy;
  final VoidCallback onSubmit;
  final VoidCallback onRescan;
  final CacOcrText text;

  const CacOcrVerified({
    super.key,
    required this.identity,
    required this.fromPhoto,
    required this.isBusy,
    required this.onSubmit,
    required this.onRescan,
    this.text = const CacOcrText(),
  });

  @override
  Widget build(BuildContext context) {
    final theme = CacOcrTheme.of(context);
    final title = text.verifiedTitle(identity);
    final detail = text.verifiedDetail?.call(identity) ?? '';
    final dodId = text.dodIdLine?.call(identity);
    final expires = identity.cardExpiresOn == null
        ? null
        : text.expiresLine?.call(identity);
    final expired = identity.isCardExpired;
    final advisory = expired
        ? text.expiredAdvisory?.call(identity)
        : identity.isCardExpiringSoon
            ? text.expiringSoon?.call(identity)
            : null;
    final rescan = text.rescanButton;
    final gallery = text.galleryAdvisory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CacPanel(
          tone: CacTone.success,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined,
                      color: theme.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: theme.text,
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
                  style: TextStyle(color: theme.mutedText, fontSize: 12),
                ),
              ],
              if (dodId != null && dodId != title) ...[
                const SizedBox(height: 4),
                Text(
                  dodId,
                  style: TextStyle(
                    color: theme.mutedText,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
              if (expires != null) ...[
                const SizedBox(height: 2),
                Text(
                  expires,
                  style: TextStyle(
                    color: theme.mutedText,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
              if (advisory != null) ...[
                const SizedBox(height: 8),
                CacPanel.compact(
                  tone: expired ? CacTone.danger : CacTone.warning,
                  child: CacNote(
                    icon: Icons.event_busy_outlined,
                    text: advisory,
                    color: expired ? theme.danger : theme.warning,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        CacButton(
          text: text.submitButton,
          icon: Icons.send,
          onPressed: isBusy ? null : onSubmit,
        ),
        if (rescan != null) ...[
          const SizedBox(height: 4),
          CacLinkButton(text: rescan, onPressed: isBusy ? null : onRescan),
        ],
        const SizedBox(height: 4),
        if (fromPhoto && gallery != null)
          CacNote(
            icon: Icons.photo_camera_back_outlined,
            text: gallery,
            color: theme.warning,
          ),
      ],
    );
  }
}
