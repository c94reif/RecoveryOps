## 0.6.0

Cleaned up for release. Breaking:

- `CacCapture` is sealed and says what a scanner read:
  `CacCapture.barcode(raw)`, `CacCapture.fields(dodId, name:, rank:,
  expiresOn:)` or `CacCapture.failed(rejection)`, in place of
  `CacCapture.read`. `VerifyOperatorIdentity` no longer guesses from the
  text's shape.
- One name for the DoD ID: `edipi` is `dodId` on `CacIdentity`,
  `AttestedIdentity` and `CacTypedIdentitySubmit`. Stored maps keep the
  `'edipi'` key, so saved identities still load.
- `DodId` holds the DoD ID rules. `DodId.isValid` replaces
  `CacIdentity.isValidEdipi`, and `DodId.lowest` and `highest` replace
  `ParseCacBarcode.lowestEdipi` and `highestEdipi`.
- `CacCardDates` holds the card-date rules: `longestValidity`, `plausible`
  (was `CacIdentity.cardDatesPlausible`), `expiredAt` (was
  `CacIdentity.cardExpiredAt`) and `daysBetween`.
- Live coaching is typed. `CacOcrSession.guidance` and
  `CacCameraPreview.guidance` are a `CacGuidance` (`CacInstruction`,
  `CacReadingProgress`, `CacFlipCard` or `CacDigitCount`), each with the
  English as `message`, and `CacOcrText.guidance` words it. The viewfinder
  no longer compares strings to tell a finished read.
- `AttestedIdentity.parse` reports an `AttestedIdentityError`, with its English
  as `message`, instead of a string.
- Every threshold is in `CacScanTuning`, passed as `createCacScanner(tuning:)`.
  The constants on `AndroidCacScanner`, and its `minLineConfidence` and
  `minDigitConfidence` arguments, are gone.
- `CacFrameReport.skipped` is a `CacFrameSkip`.
- UI wording left the domain: `cacRetryHint` and
  `CacIdentity.cardExpiryCountdown` are now `CacOcrText` defaults. The default
  expiry warning for a card already past its date says it expired.
- `CacScanController` state is read-only (`lastScan`, `isScanning`,
  `scanAttempts`), and `scanGeneration` is gone.
- `CacScannerStrategy` is an interface.
- `CacGalleryAdvisory`, `AimGuideLine` and `CacTypedIdentityFormState` are no
  longer public.
- `FakeCacScanner.willRead` is `willReadBarcode` or `willReadFields`.

Added:

- Shared widgets: `CacPanel` with `CacTone`, `CacNote` and `CacLinkButton`.
- `CacVoteWindow`, the frame agreement on its own.
- `asFields` and `asBarcode` in `testing.dart`.
- Rank and date labels followed by an en dash now read, as names already did.

Internals:

- `lib/src` is in `domain`, `application`, `infrastructure` and `presentation`
  layers, which `test/architecture/layers_test.dart` holds to their direction.
- The Android scanner's frame handling is split into `CacFrameGate`,
  `CacFrameText`, `CacMetering` and `cacReadHighlights`. The web scanner's
  photo picker is `WebPhotoPicker`.

## 0.5.0

- Printed text is accepted once it reads the same on 3 of the last 5 frames
  with nothing else read among them (`CacOcrSession.voteWindow`). A frame that
  reads nothing no longer restarts the count, and a different reading holds
  it back until it leaves the window.
- Coaching while reading carries the count, e.g. "Reading your name — hold
  still · 2 of 3", and the viewfinder outlines the line or barcode being read.
- On the back, a line with a digit ML Kit scores under `minDigitConfidence`
  (default 0.5) is dropped.
- Focus and exposure lock once the card is found. They let go after 3 blurred
  frames in a row, and on the flip.
- Glare dims the exposure by up to one stop, once per camera.
- A torch switch over the preview, hidden where the camera has none, labelled
  by `CacOcrText.torchOn` and `torchOff`.
- Leaving the app mid-scan closes the camera, and returning reopens it with
  the name already read kept. The side's time limit waits while away and
  starts over on return. A camera that will not come back ends the scan with
  `CacRejection.cameraTimedOut`.
- Scan diagnostics: `createCacScanner(diagnostics: CacScanDiagnostics())`
  logs every frame, with what was read masked, and `CacOcr` shows the log
  under every state with a copy button.
- New: `CacLiveFeedback`, `CacScanDiagnostics`, `CacFrameReport`,
  `CacDiagnosticsView`, and on `CacOcrSession` `voteWindow`, `backing`,
  `contested`, `sawCard`, `lastNameRead` and `lastDodIdRead`.
- `CacOcrSession.resetFrameAgreement()` also puts back the side's opening
  prompt.

## 0.4.0

- The Android scanner decodes barcodes alongside OCR. The front's PDF417
  ends the scan with its exact record and no flip. The back's Code 39
  confirms the printed DoD ID at once when they agree, and a disagreement
  throws the frame away.
- Printed text must read the same on 3 frames in a row instead of 2.
- OCR lines ML Kit scores under `minLineConfidence` (default 0.5) are dropped.
- Blurred frames are skipped, measured against the recent sharpest frame.
  Glare above 15% shows a tilt tip, and above 35% the frame is skipped.
- An expiry that no card could carry (before its issue date, or more than
  three years out) is treated as unread.
- Scanning starts at 1080p and steps up to 4K after repeated misses.
- New: `ParseCacBarcode.isFrontRecord`, `ParseCacBarcode.dodIdFromCode39`,
  `findCacIssueDate`, `CacIdentity.cardDatesPlausible`, and
  `CacOcrSession.process(lines, barcodes: …)`.
- Adds `google_mlkit_barcode_scanning` 0.14.2, which matches the ML Kit
  version text recognition already uses.

## 0.3.0

- Renamed from `cac_scanner` to `cac_ocr`: import
  `package:cac_ocr/cac_ocr.dart`. `cac_core.dart` and `testing.dart` keep
  their names.
- Renamed the widgets: `CacSignOff` is `CacOcr`, `CacSignOffText` is
  `CacOcrText`, `CacSignOffPrompt` and `CacSignOffScanning` are `CacOcrPrompt`
  and `CacOcrScanning`, `CacVerifiedSignOff` and `CacRefusedSignOff` are
  `CacOcrVerified` and `CacOcrRefused`, and `CacScannerTheme` is `CacOcrTheme`.
  Logs are tagged `[CacOcr]`.
- The Android scanner reads the rank and expiry date off the front with the
  name. Both are labelled fields read only when unambiguous, and must agree
  across frames with the name.
- An expired card is refused with a red CAC EXPIRED card showing whose card
  it is and when it ran out. `CacScan.expired` carries the card as
  `expiredCard`.
- `VerifyOperatorIdentity(allowExpired: true)` accepts expired cards; the
  verified card then marks them expired. `CacIdentity.isCardExpired` reports
  it.
- Breaking:
  - `CacOcrTheme` takes a `dangerContainer` colour.
  - `CacOcrText.expiredSinceScan` is now `expiredAdvisory`, a function of the
    identity.

## 0.2.0

- `createCacScanner(sides: CacSides.backOnly)` reads the back of the card
  alone, for the DoD ID with no name. The prompt, card diagram, viewfinder and
  result follow the scanner's choice.
- Every word the sign-off draws is now in `CacSignOffText`, including the
  viewfinder labels, card-diagram lines, verified-card lines, retry tips and
  typed-form labels. Optional lines are nullable and left out when null.
- `CacSignOff` takes `showAimGuide` and `maxLeadingRetries`.
- Breaking:
  - `CacCameraPreview` has a `sides` getter.
  - `CacVerifiedSignOff` takes `fromPhoto` instead of `scansBothSides`, and
    `CacRefusedSignOff` takes `fromPhoto` as well. The gallery advice now
    follows photo capture rather than two-sided reading.
  - The constant `CacSignOff.maxLeadingRetries` is now
    `defaultMaxLeadingRetries`.
  - `formatCardDate` moved into `cac_sign_off_text.dart`; still exported.

## 0.1.0

- First release, extracted from circle-x: CAC identity model and parsing,
  Android live OCR and web barcode scanners, and the sign-off UI.
- Flow-specific wording moved into `CacSignOffText` and colours into
  `CacScannerTheme`, so an app other than circle-x can use the UI as is.
- `ParseCacBarcode` and `ParseDodId` take a `DateTime Function()` instead of
  circle-x's `Clock`; the capture timeout is a scanner parameter.
- The unverified and typed fallbacks are optional.
