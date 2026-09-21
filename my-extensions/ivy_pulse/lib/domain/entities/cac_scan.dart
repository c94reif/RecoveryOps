import 'package:ivy_pulse/domain/entities/cac_identity.dart';

/// Why a CAC scan did not produce an identity.
///
/// Every one of these is shown to the operator verbatim, so each reads as an
/// instruction rather than a diagnosis — a Soldier standing at a vehicle needs
/// to know what to do next, not what the parser thought.
///
/// The copy never says just "the front" either. At an installation gate a
/// Soldier is trained to present the *back* so the sentry can read the wide
/// Code 39 strip, and every driver's licence in their wallet carries its
/// PDF417 on the back too — so "front" is the one word guaranteed to send them
/// the wrong way. Name landmarks instead: the photo, the gold chip, the tall
/// barcode beside it.
enum CacRejection {
  /// The camera came back but nothing in the frame was a PDF417.
  noCodeFound,

  /// The barcode was found and then would not resolve into codewords — glare
  /// across it, a crease, a thumb over one corner. Its own case rather than
  /// [noCodeFound] because the operator is already aimed at the right thing
  /// and only needs to change the light or steady their hands.
  codeUnreadable,

  /// Found, but rendered too few pixels per module to decode. Either the card
  /// was too far away, or it was held so the barcode's long axis ran up the
  /// frame instead of across it.
  cardTooSmall,

  /// A barcode was read, but it is not the one on the front of a CAC — a
  /// driver's licence, a shipping label, a QR code on a windscreen.
  notACac,

  /// A CAC's own Code 39 decoded, so the operator photographed the back. Kept
  /// apart from [notACac] because this one has a single specific fix, and it
  /// is the mistake most Soldiers make first: the back is the face they are
  /// trained to show at a gate. That strip carries no name and no rank, so it
  /// can never sign a 5988-E — its only use is this signal.
  wrongSideOfCard,

  /// Issued before 1 December 2012, when the second field on the card was
  /// literally the cardholder's SSN. Refused outright: this app will not hold
  /// an SSN even for the moment it takes to ignore it.
  legacySsnCard,

  /// The card is past its expiry date.
  expired,

  /// The operator backed out of the camera.
  cancelled,

  /// The camera opened and never came back. Distinct from [cancelled] because
  /// nobody chose it — on the operator's side the scan simply stopped, and
  /// without this they would be staring at a spinner deciding whether the app
  /// is broken.
  cameraTimedOut,

  /// No camera behind the host's WebView, or permission was refused.
  noCamera;

  String get message => switch (this) {
        CacRejection.noCodeFound =>
          'No barcode found. Fill the frame with the side that has your photo '
              'and the gold chip, and hold steady.',
        CacRejection.codeUnreadable =>
          'Found the barcode but could not read it. Wipe the card, tilt it '
              'away from the light, and hold steady.',
        CacRejection.cardTooSmall =>
          'The barcode is too small in the frame. Turn the card sideways so '
              'the barcode runs across the frame, and move closer.',
        // Says "tall", never "large": the strip on the back is more than twice
        // the area of the symbol this wants, so "the large block" names the
        // wrong one — and contradicts the diagram drawn right under it.
        CacRejection.notACac =>
          'That is not a CAC barcode. Scan the tall barcode on the side with '
              'your photo and the gold chip, bottom left beside the chip.',
        CacRejection.wrongSideOfCard =>
          'That is the strip the gate guard scans, on the back. Turn the card '
              'over — the tall barcode is bottom left, beside the gold chip.',
        CacRejection.legacySsnCard =>
          'That card predates 2012 and carries an SSN. It cannot be used — '
              'draw a current CAC.',
        CacRejection.expired =>
          'That CAC expired. Draw a current card, or submit unverified.',
        CacRejection.cancelled => 'Scan cancelled.',
        CacRejection.cameraTimedOut =>
          'The camera did not come back. Try again, or submit unverified.',
        CacRejection.noCamera =>
          'No camera available on this device. Submit unverified, or sign '
              'this PMCS on a device that has one.',
      };

  /// Whether photographing the card again could plausibly change the answer.
  ///
  /// Drives which control the refused state leads with. Aiming, lighting and
  /// a fumbled camera are all fixed by another shot, so SCAN AGAIN is the
  /// primary action. A card that is expired or pre-2012, or a device with no
  /// camera at all, returns the identical answer every time — leading with
  /// SCAN AGAIN there walks the operator round a loop that cannot end, so the
  /// unverified override takes the front position instead.
  bool get isWorthRetrying => switch (this) {
        CacRejection.noCodeFound ||
        CacRejection.codeUnreadable ||
        CacRejection.cardTooSmall ||
        CacRejection.notACac ||
        CacRejection.wrongSideOfCard ||
        CacRejection.cancelled ||
        CacRejection.cameraTimedOut =>
          true,
        CacRejection.legacySsnCard ||
        CacRejection.expired ||
        CacRejection.noCamera =>
          false,
      };
}

/// What the camera came back with: barcode text, or the reason there is none.
///
/// Stops short of an identity on purpose — the scanner's job ends at the
/// decoded string, and everything the DMDC spec says about that string is
/// [ParseCacBarcode]'s, where it can be tested without a camera.
class CacCapture {
  final String? barcode;
  final CacRejection? rejection;

  const CacCapture.read(String this.barcode) : rejection = null;

  const CacCapture.failed(CacRejection this.rejection) : barcode = null;
}

/// The outcome of one attempt to read a CAC — either an identity or the
/// reason there isn't one.
class CacScan {
  final CacIdentity? identity;
  final CacRejection? rejection;

  const CacScan.verified(CacIdentity this.identity) : rejection = null;

  const CacScan.rejected(CacRejection this.rejection) : identity = null;

  bool get isVerified => identity != null;
}
