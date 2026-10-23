# CAC OCR 


**Does not PROVE CAC authenticity: Only the cards-chip when read from a cac reader can 100% prove that the cac card is 
100% authentic.** 


Reads a DoD Common Access Card and turns it into a signature or pulls the information off the cac card.
Live two-sided OCR on Android, barcode decoding from a photo on the web, and the scan UI
around both: prompt, viewfinder, verified identity, refusal with retry
coaching, and a typed fallback.

Extracted from circle-x, which is its first consumer.

## What it reads

| Platform | Capture | Identity |
|---|---|---|
| Android | Live camera preview, read by ML Kit OCR and barcode scanning together. If the front's PDF417 decodes, that record is the whole read and no flip is needed. Otherwise the front gives the printed name, rank and expiry date, then the back gives the 10-digit DoD ID, cross-checked against the back's Code 39. `CacSides.backOnly` reads the back alone. See [Accuracy](#accuracy). | Name, rank, card expiry and DoD ID, or the DoD ID alone |
| Web | One photo through the browser's file input; the native `BarcodeDetector` when present, otherwise a pure-Dart zxing decoder. | The full front PDF417 record (name, rank, branch, category, expiry), or the DoD ID alone from the back's Code 39 |
| Anything else | None | `isAvailable()` is false and `capture()` refuses with `noCamera` |

Refused outright: cards from before 2012 (their security field is an SSN),
numbers outside the range DEERS issues, and, unless the app allows them,
expired cards (see [Expired cards](#expired-cards)). Camera frames are
discarded once read and nothing is saved. The web photo is dropped after
decoding, but the phone's camera app may keep its own copy, and the UI tells
the user so. The card's date of birth and security identifier never reach a
`CacIdentity`.

## Install

From inside this repository, by path:

```yaml
dependencies:
  cac_ocr:
    path: packages/cac_ocr                 # from circle-x
    # path: ../circle-x/packages/cac_ocr   # from a sibling extension
```

From another repository, by git:

```yaml
dependencies:
  cac_ocr:
    git:
      url: git@github.com:c94reif/RecoveryOps.git
      path: my-extensions/circle-x/packages/cac_ocr
      ref: main  # pin a tag or commit for repeatable builds
```

### Android

- `minSdk` **23** or later, which `camera_android_camerax` requires.
- ML Kit's barcode model ships inside the app, which adds a few MB.
- The camera plugin declares the `CAMERA` permission and asks for it when the
  camera first opens. Nothing to add to the app manifest.

## Use it

### The drop-in widget

`CacOcr` switches between prompt, live scan, verified identity and refusal
as its controller changes.

```dart
import 'package:cac_ocr/cac_ocr.dart';

final scanner = createCacScanner();
final scan = CacScanController(
  cacScanner: scanner,
  verifyOperatorIdentity: VerifyOperatorIdentity(
    scanner: scanner,
    parseBarcode: const ParseCacBarcode(),
  ),
);
final cameraReachable = await scanner.isAvailable();

CacOcr(
  controller: scan,
  scannerAvailable: cameraReachable,
  isBusy: saving,
  onSubmit: () => sign(scan.lastScan!.identity!),
  // Both optional. Leave them out where only a scanned card may sign.
  onSubmitUnverified: () => signUnverified(scan.lastScan!.rejection!),
  onSubmitTyped: ({required lastName, required firstName, required dodId}) async {
    final typed = AttestedIdentity.parse(
        lastName: lastName, firstName: firstName, dodId: dodId);
    if (typed.identity case final identity?) {
      signTyped(identity);
    } else {
      showError(typed.error!.message);
    }
  },
);
```

Dispose the controller with whatever owns it. Disposing mid-scan closes the
camera, and a result that arrives afterwards is dropped.

### Just the identity

```dart
final result = await VerifyOperatorIdentity(
  scanner: createCacScanner(),
  parseBarcode: const ParseCacBarcode(),
)();
if (result.identity case final identity?) {
  print('${identity.displayName}, DoD ID ${identity.dodId}');
} else {
  print(result.rejection!.message);
}
```

### Your own UI

| API | For |
|---|---|
| `buildCacViewfinder(scanner)` | The live viewfinder with card guide and tap-to-focus; `null` for scanners without a preview |
| `scansBothCacSides(scanner)` | Whether the scanner reads the front and then the back |
| `hasCacLivePreview(scanner)` | Whether it streams a preview, as opposed to taking a photo through the camera app |
| `CacOcrPrompt`, `CacOcrScanning`, `CacOcrVerified`, `CacOcrRefused`, `CacTypedIdentityForm` | The states `CacOcr` switches between |
| `CacButton`, `CacLinkButton`, `CacPanel`, `CacNote`, `CacAimGuide` | The building blocks those states share, in the package's style |
| `CacOcrSession`, `findCacName`, `inspectDodId` | The OCR rules on their own, to drive from another OCR engine |
| `ParseCacBarcode` | Decodes the PDF417 or Code 39 text from any barcode reader |
| `DodId`, `CacCardDates` | The rules a DoD ID and a card's dates follow |

### Your own scanner

Implement `CacScannerStrategy` and return what one attempt gave: the raw
contents of a barcode, the fields the scanner read itself, or why it got
neither. `VerifyOperatorIdentity` holds every capture to the same rules.

```dart
CacCapture.barcode(raw)                       // front PDF417 or back Code 39
CacCapture.fields('1087987498', name: name, rank: 'SGT', expiresOn: date)
CacCapture.failed(CacRejection.noCodeFound)
```

A live scanner built on another OCR engine can feed each frame's lines and
barcodes to a `CacOcrSession`, which says what to coach next
(`session.guidance`) and returns the capture once the card is read.

`package:cac_ocr/cac_core.dart` exports the model, parsers, OCR session and
scanner port with no Flutter import, so a domain layer can depend on it.
circle-x's architecture test allows its domain exactly that library.

## Make it yours

**Which sides to read.** The scanner decides, and the prompt, card diagram,
viewfinder and result all follow it:

```dart
final scanner = createCacScanner(sides: CacSides.backOnly); // DoD ID, no name
```

A back-only read has no name, so the verified card shows the DoD ID as its
title. The web scanner ignores `sides`: it takes one photo and decodes
whichever barcode it finds.

**Wording.** Every word `CacOcr` draws comes from `CacOcrText`: button
labels, prompts, notices, the viewfinder's step labels and torch switch, the
card-diagram lines,
the verified card's lines, the refusal message and retry tip for each
`CacRejection`, and the typed form's labels. Each field defaults to the
package's own wording, so set only what you want to change:

```dart
const text = CacOcrText(
  scanButton: 'SIGN IN WITH CAC',
  submitButton: 'CONTINUE',
  promptBackOnly: 'Hold the back of your CAC up to the camera.',
  aimGuideBackOnly: ['The side with the long barcode', 'Hold it still'],
  rescanButton: null,      // null leaves an optional line out
  scanningNotice: null,
);

CacOcr(controller: scan, onSubmit: signIn, text: text);
```

Lines that can be left out are nullable; the card diagram's lines are a list,
and an empty list leaves the diagram on its own. Lines that depend on the card,
such as `verifiedTitle`, `expiredHolder` or `rejectionMessage`, are functions.

The live coaching under the camera ("Reading your name — hold still · 2 of 3")
is a `CacGuidance` the scanner chooses and `CacOcrText.guidance` words. Each
kind carries the package's English as `message`, so a translation can switch
on the kinds it rewords and fall back to that:

```dart
CacOcrText(
  guidance: (guidance) => switch (guidance) {
    CacReadingProgress(agreeing: final agreeing?, :final needed) =>
        'Leyendo… $agreeing de $needed',
    CacInstruction.tiltFromGlare => 'Incline la tarjeta para quitar el brillo',
    _ => guidance.message,
  },
);
```

`CacRejection` and `AttestedIdentityError` carry their English the same way,
in `message`. Only the scan log's developer wording is fixed (see
[Tuning on a phone](#tuning-on-a-phone)). circle-x's PMCS wording is in
`lib/presentation/inspection/pmcs_sign_off_text.dart`.

**What is offered.** Leave out `onSubmitUnverified` or `onSubmitTyped` where
only a scanned card may sign. `showAimGuide: false` drops the card diagram, and
`maxLeadingRetries` (default 3) sets how many misses SCAN AGAIN stays the main
button before the unverified submission takes over.

**Colours.** Add a `CacOcrTheme` to `ThemeData.extensions`. Without one,
colours come from the app's `ColorScheme`.

### Expired cards

By default a card past its printed expiry date is refused. The refusal is a
red **CAC EXPIRED** card with whose card it is and when it ran out, and the
result is `CacScan.expired`: `rejection` is `CacRejection.expired` and
`expiredCard` holds what was read. A card is good through its printed date and
expires the day after.

To accept expired cards instead, set it on the verifier:

```dart
VerifyOperatorIdentity(
  scanner: scanner,
  parseBarcode: const ParseCacBarcode(),
  allowExpired: true,
);
```

The scan then verifies, and the verified card carries a red "This CAC expired
…" line (`expiredAdvisory`; set it to null to leave it out). Check
`identity.isCardExpired` wherever the app needs to know.

The date only exists where it was read. On Android it is OCR of the "Expires"
field on the front: if that field does not read cleanly, the date is left
empty rather than guessed, and nothing is checked. A back-only scan never sees
the front, so it cannot tell an expired card at all. The web's front barcode
always carries the date; the back's Code 39 never does.

**Timing.** `createCacScanner(captureTimeout: …)` sets how long one side, or
one photo, may take. Default 2 minutes. On Android the limit waits while the
app is out of sight and starts over when it returns.

## Accuracy

The live scanner trusts a barcode over printed text, and printed text only
when it reads the same several times:

- **Front PDF417.** Error-corrected, so a decoded record is exact. It ends the
  scan at once, with the name, rank, branch and expiry from the record.
- **Back Code 39.** It encodes the DoD ID. If it agrees with the printed
  number in the same frame, the number is accepted then; if they disagree,
  the frame is thrown away. Either one alone is voted on like printed text.
- **Votes.** Printed text is accepted once it reads the same on three of the
  last five frames (`CacOcrSession.framesToAgree`, `voteWindow`) with nothing
  else read among them. A frame that reads nothing neither counts nor
  restarts the count; a different reading holds the count back until it
  leaves the window. The coaching shows the count, and the viewfinder
  outlines the line or barcode being read.
- **ML Kit's own doubt.** Lines it scores under `minLineConfidence` (0.5) are
  dropped before any field is read. On the back, so is any line with a digit
  it scores under `minDigitConfidence` (0.5): one shaky digit of the DoD ID
  must not ride on a confident line.
- **Blur and glare.** A frame under 60% of the recent sharpest one is skipped.
  A frame more than 35% washed out is skipped, and above 15% the operator is
  told to tilt the card and the exposure dims by up to one stop. A torch
  switch sits over the preview where the camera has one.
- **Focus.** Focus and exposure hold once the card is found, so the camera
  stops hunting between frames, and let go after three blurred frames in a
  row or when the card is flipped.
- **Dates.** An expiry before the printed issue date, more than three years
  after it, or more than three years from today is a misread and is dropped.
- **Resolution.** Scanning starts at 1080p, for the PDF417's small modules,
  and moves to 4K after 12 frames without a reading.

Leaving the app mid-scan closes the camera, and returning reopens it with the
name already read kept. A camera that will not come back ends the scan with
`CacRejection.cameraTimedOut`, which is worth a retry.

The confidence, blur and glare thresholds are starting points chosen without
a real card in front of the camera. They are all in `CacScanTuning`, so they
can be tuned once scans on a phone show where they sit:

```dart
createCacScanner(tuning: const CacScanTuning(blurRatio: 0.5, glareToSkip: 0.4));
```

### Tuning on a phone

Give the scanner a log and `CacOcr` shows it under every state, with a button
that copies it:

```dart
final scanner = createCacScanner(diagnostics: CacScanDiagnostics());
```

Each line is one frame: its sharpness against the recent sharpest, its glare,
whether it was skipped for blur or glare, the lines kept and dropped, the
lowest line confidence, doubtful digits, barcodes found, what was read and how
many recent frames back it, and how long OCR took. Names are masked to their
initials and DoD IDs to their last four digits, so a log can be shared. The
log holds the latest scan, and `CacDiagnosticsView` can show it anywhere
else. Its wording is fixed: it is a developer's tool.

circle-x turns it on with `--dart-define=CAC_DIAGNOSTICS=true`.



