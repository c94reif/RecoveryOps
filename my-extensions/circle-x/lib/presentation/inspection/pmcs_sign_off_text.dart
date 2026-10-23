import 'package:cac_ocr/cac_ocr.dart';

/// The PMCS reading of the CAC sign-off: a walked PMCS goes to the maintainer,
/// and a card that cannot be read still leaves an unverified way to send it.
const pmcsSignOffText = CacOcrText(
  promptBothSides: 'A PMCS is signed by the Soldier who walked it. Scan the '
      'front of your CAC for your name, then flip it when asked to read the '
      'DoD ID number on the back.',
  promptBackOnly: 'A PMCS is signed by the Soldier who walked it. Show the '
      'camera the back of your CAC — it reads your DoD ID number.',
  noCamera: 'No camera reachable on this device — you will be offered an '
      'unverified submission instead.',
  scanningNotice: 'Camera frames are discarded after reading. Cancelling '
      'closes the camera and leaves the PMCS unsigned.',
  submitButton: 'SUBMIT PMCS',
  unverifiedNotice:
      'An unverified PMCS still reaches the maintainer, marked as '
      'signed by nobody this device could check.',
  galleryAdvisory: 'circle-x dropped the photo, but the camera app may have '
      'kept its own copy in the gallery. Delete it there.',
  typedNotice: 'Goes out marked as typed, not scanned. The maintainer still '
      'gets a name and a number to chase.',
  rejectionMessage: pmcsRejectionMessage,
);

String pmcsRejectionMessage(CacRejection rejection) => switch (rejection) {
      CacRejection.expired =>
        'That CAC expired. Draw a current card, or submit unverified.',
      CacRejection.cameraTimedOut =>
        'The camera did not come back. Try again, or submit unverified.',
      CacRejection.noCamera =>
        'No camera available on this device. Submit unverified, or sign '
            'this PMCS on a device that has one.',
      _ => rejection.message,
    };
