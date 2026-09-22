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

/// The last thing between a walked PMCS and the net: who is signing for it.
///
/// Four states, one at a time — nothing to scan yet, scanning, a Soldier read
/// off a CAC, or a refusal with a way past it. SUBMIT PMCS only exists in the
/// third; the fourth offers SUBMIT UNVERIFIED instead, which says on the face
/// of the report that nobody checked. Every state that can still be walked
/// away from carries a control that does it — a Soldier holding a finished
/// PMCS must never be looking at a panel with nothing on it to press.
class SignOffCard extends StatelessWidget {
  final InspectionViewModel viewModel;

  const SignOffCard({super.key, required this.viewModel});

  /// How many misses in a row SCAN AGAIN keeps the leading position for.
  ///
  /// Past this the aim is not the problem any more — the card, the light or
  /// the camera is — and a full-width primary button that returns the same
  /// refusal a fourth time is walking the operator round a loop. The override
  /// takes the front position instead, still behind its confirmation dialog.
  static const int maxLeadingRetries = 3;

  /// Width of the aim diagram, in logical pixels.
  ///
  /// Deliberately small. A larger version of this drawing pushed SCAN AGAIN
  /// and SUBMIT UNVERIFIED off a 314-pixel panel at the exact moment the
  /// Soldier needed them, which is a worse failure than a diagram nobody can
  /// read the fine detail of — the detail is in the three lines beside it.
  static const double cardWidth = 88;

  /// A CR80 card is 1.587:1, and the back — the side asked for — is printed
  /// landscape. Held to the real proportion so the drawing is recognisably
  /// the thing in the operator's hand rather than a generic rectangle.
  static const double cardHeight = cardWidth / 1.587;

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

  // ── nothing scanned yet ────────────────────────────────────────────────

  Widget buildPrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'A PMCS is signed by the Soldier who walked it. Show the camera '
          'the back of your CAC — it reads your DoD ID number.',
          style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
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

  // ── camera open / frame decoding ───────────────────────────────────────

  Widget buildScanning() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // On Android the scan is a live view: the camera is drawn right here
        // and reads the number the moment it is legible. Where the platform
        // has no live view — the web build photographs through the system
        // camera app — the operator is told what is happening instead.
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
        // This state used to render no controls at all, which made a camera
        // that never came back the end of the PMCS. It is also the state the
        // operator sits in for up to two minutes while the capture timeout
        // runs down.
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
          'Nothing is saved — the camera reads the number and the frames are '
          'gone. Cancelling closes the camera and leaves the PMCS unsigned.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  // ── a Soldier off the card ─────────────────────────────────────────────

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
              // The expiry is already parsed to refuse a dead card, and a
              // maintainer reading a signature block months later wants to see
              // what the app checked against.
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
        buildGalleryAdvisory(),
      ],
    );
  }

  /// Amber inside the green panel: the scan was good, the card is not going to
  /// be for much longer.
  ///
  /// Nested rather than shown instead of the verified banner, because the
  /// signature is valid today — this is a heads-up, not a refusal, and
  /// dressing it as one would teach operators to ignore the real refusals.
  Widget buildExpiryAdvisory(CacIdentity identity) {
    final days = identity.daysUntilCardExpiry;
    // `cardExpiryCountdown` answers 'expired' for a card already past its
    // date, which reads as "expires expired" in a sentence. That case only
    // reaches here through an identity restored from an older report, but it
    // reaches here.
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

  // ── the scan was refused ───────────────────────────────────────────────

  Widget buildRefused(BuildContext context) {
    final rejection = viewModel.lastScan!.rejection!;
    // Aiming, lighting and a fumbled camera are all fixed by another shot, so
    // SCAN AGAIN leads. An expired or pre-2012 card, or a device with no
    // camera, returns the identical answer however it is photographed — and so
    // does a card that has already beaten the operator [maxLeadingRetries]
    // times. In both of those the override leads instead.
    final retryLeads = rejection.isWorthRetrying &&
        viewModel.scanAttempts <= maxLeadingRetries;
    final hint =
        rejection.isWorthRetrying ? cacRetryHint(viewModel.scanAttempts) : null;

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
                  // The icon carries "this is advice, not a fault"; the text
                  // does not have to. masterChiefGreen on bgDark is 3.5:1,
                  // under AA for 11px, and this is the one genuinely
                  // non-obvious sentence on the card — unreadable outdoors is
                  // the same as absent.
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
        // Below the controls here, above the button in [buildPrompt]. The
        // guide is 95px on a panel with about 314 to spend, and sitting it
        // between the refusal message and SCAN AGAIN pushed those two far
        // enough apart that the operator scrolled down to the button and
        // re-shot the card without ever seeing the sentence saying what to
        // change — which is the only reason the message exists. In the prompt
        // nothing has failed yet and the operator is being aimed rather than
        // corrected, so there the diagram leads.
        //
        // Only where another photograph could change the answer: a diagram of
        // where the barcode lives is noise next to an expired card or a device
        // with no camera behind the WebView.
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
        // Nothing was photographed when there is no camera to photograph with,
        // and telling an operator to go and clear a gallery copy that cannot
        // exist is the kind of confidently wrong instruction this card exists
        // to avoid.
        if (rejection != CacRejection.noCamera) ...[
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

  /// The same label, the same handler and the same dialog as
  /// [buildUnverified] — demoted, never removed. An operator who knows they
  /// are never going to get this card read must still be able to send the
  /// PMCS, and hiding the way out behind a number of attempts would strand
  /// exactly the person who needs it.
  Widget buildUnverifiedLink(BuildContext context) => Align(
        alignment: Alignment.center,
        child: SizedBox(
          height: minTouchTarget,
          child: TextButton(
            onPressed:
                viewModel.isBusy ? null : () => confirmUnverified(context),
            // Demoted in position, never in severity. Left to the theme this
            // renders in the same green as SCAN AGAIN — the benign control it
            // trades places with — so a gloved operator glancing at the panel
            // sees the override styled exactly like the safe action.
            style: TextButton.styleFrom(foregroundColor: redXRed),
            child: const Text('SUBMIT UNVERIFIED'),
          ),
        ),
      );

  // ── shared advisories ──────────────────────────────────────────────────

  /// Said out loud because the app cannot do anything about it.
  ///
  /// Ivy Pulse decodes the frame in memory and drops it, but the capture runs
  /// through the platform camera app and that app keeps its own copy on its
  /// own terms — as, on the way past, does the host's WebView file chooser.
  /// Neither is reachable from inside an extension. Photographing a US
  /// Government ID is an offence under 18 U.S.C. § 701, so the operator is
  /// the only one who can finish the job.
  ///
  /// Shown after a refusal as well as after a read: the Soldier who missed
  /// three times has three probable copies sitting in DCIM and is the one
  /// least likely to be told otherwise.
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

  // ── where the barcode actually is ──────────────────────────────────────

  /// A schematic of the CAC front with the PDF417 lit up, and the three lines
  /// that stop an operator scanning the wrong face.
  ///
  /// The wrong face is the default mistake, and training is the reason: at an
  /// installation gate a Soldier is told to show the *back* so the sentry can
  /// read the wide Code 39 strip, and every driver's licence in their wallet
  /// carries its PDF417 on the back as well. So the copy never says "front" —
  /// it names what the operator can see in their own hand, and disclaims the
  /// strip they have been trained to present.
  ///
  /// Drawn from nested containers rather than an asset or a painter: it needs
  /// no new dependency, it scales with the theme tokens, and there is nothing
  /// here a CustomPainter would draw better at 60 pixels wide.
  Widget buildAimGuide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCardSchematic(),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AimGuideLine('Turn the card over — the side the gate scans'),
              SizedBox(height: 5),
              AimGuideLine('Fill the box; the DoD ID number sits above the '
                  'wide strip'),
              SizedBox(height: 5),
              AimGuideLine('It reads by itself — no button to press'),
            ],
          ),
        ),
      ],
    );
  }

  /// The back of the card, as the operator holds it: landscape, the wide
  /// Code 39 strip along the lower edge, and the DoD ID number printed
  /// above it. Only the number is lit — it is the thing the camera is
  /// reading — and the strip is drawn muted as the landmark it sits above.
  Widget buildCardSchematic() {
    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Stack(
        children: [
          // Positioned.fill, not a bare child: a Stack hands its unpositioned
          // children loose constraints, and a Container with nothing in it but
          // a decoration collapses to nothing under those.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: surfaceLight,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: border, width: 1),
              ),
            ),
          ),
          // The other printed numbers — benefits number, date of birth —
          // as muted rules, so the lit one reads as one of several.
          buildPrintedRule(top: 0.10, width: 0.40),
          buildPrintedRule(top: 0.20, width: 0.30),
          // The target: the DoD ID number. The only lit element, filled solid
          // rather than glowed so it still reads on a sunlit EUD.
          Positioned(
            left: cardWidth * 0.08,
            top: cardHeight * 0.32,
            width: cardWidth * 0.62,
            height: cardHeight * 0.09,
            child: Container(
              decoration: BoxDecoration(
                color: serviceableGreen,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: masterChiefGreen, width: 1.2),
              ),
            ),
          ),
          // The wide Code 39 strip along the long edge — the landmark, so
          // muted, not the thing being aimed at.
          Positioned(
            left: cardWidth * 0.08,
            top: cardHeight * 0.58,
            width: cardWidth * 0.84,
            height: cardHeight * 0.14,
            child: Container(
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          // The magnetic stripe, right at the bottom edge.
          buildPrintedRule(top: 0.86, width: 0.84),
        ],
      ),
    );
  }

  Widget buildPrintedRule({required double top, required double width}) {
    return Positioned(
      left: cardWidth * 0.08,
      top: cardHeight * top,
      width: cardWidth * width,
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

/// One line of the aim guide, bulleted so three short instructions do not read
/// as one wrapped paragraph at 11 point.
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

/// `30 JUN 2028` — the form the card itself prints, so an operator can hold
/// the panel and the card side by side without converting anything.
String formatCardDate(DateTime date) {
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  final utc = date.toUtc();
  return '${utc.day.toString().padLeft(2, '0')} '
      '${months[utc.month - 1]} ${utc.year}';
}
