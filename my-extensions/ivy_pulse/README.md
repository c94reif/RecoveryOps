# Ivy Pulse

## General Info:
Guided **PMCS** (Preventive Maintenance Checks and Services) for tactical vehicles on
Lattice Edge. Companion application for **Convoy Ops** / **Recovery Ops**.

> Developers:
> - Christopher Reif
>   - Phone Number: (580)919-0457
>   - Email:
>     - Military: christopher.a.reif.mil@army.mil
>     - Personal: reifc@protonmail.com
> - Jesus Ambroio
>   - Phone Number: (224)253-2169
>   - Email:
>     - Military: jesus.ambroio.mil@army.mil
>     - Personal: jesus.ambrocio@outlook.com
---

## What it does

A Soldier picks a platform and bumper number, walks the **BEFORE / DURING / AFTER**
phases, and taps a condition for each TM check. Faults are graded automatically, the
Soldier signs the finished PMCS by scanning their CAC, and it goes out to maintainers on
two independent transports.

- **Two platforms, from the TM.** Stryker (78 checks, TM 9-2355-311-10) and
  JLTV (94 checks, TM 9-2320-400-10).
- **One tap per check.** Serviceable is always the first, full-width, largest button —
  the common case is the fastest. Answering collapses the check and scrolls to the next.
- **Graded the way the TM grades.** RED X (Not Mission Capable), CIRCLE X
  (mission-essential only), DASH (deferrable). Items the TM flags
  "Not Mission Capable If" are treated as critical systems.
- **Nothing is lost.** Every answer is written to SQLite on tap. Kill the app, hand the
  EUD off, lose power — the walk-around resumes exactly where it stopped.
- **Nothing blocks on the net.** Submission is stored locally first, then pushed on
  Lattice and the mesh in parallel. Either leg failing parks its own copy on a queue that
  drains when that transport comes back, asking before it sends.
- **Voice notes.** A faulted check can take a dictated note — no typing in gloves.
- **Signed by the Soldier who walked it.** Submitting is gated behind a CAC scan. The
  PDF417 on the front of the card decodes to a name, rank, service and DoD ID, and those
  ride the report to the maintainer. A scan that cannot happen can be overridden, but the
  report then goes out stamped `UNVERIFIED` with the reason attached — never silently
  unattributed.
- **The scan tells you what went wrong and what to do about it.** A schematic of the card
  shows where the barcode actually is; a barcode found but unreadable is a different
  message from no barcode at all; photographing the *back* of the card is detected by name
  and says so. Advice escalates only after a miss, and the camera can always be cancelled.
- **A card about to expire warns before it strands anyone.** The signature block shows the
  card's expiry, and inside thirty days it says so — a card that dies mid-rotation strands
  whoever has been signing the 5988-Es.

## Architecture

Clean architecture, mirroring `recovery_ops`.

```
lib/
  core/          theme, DI container, constants
  domain/        entities, repository interfaces, ports, use cases  (no Flutter, no SDK impl)
  data/          drift database + DAOs, repository impls, SDK adapters, queue worker
  presentation/  ChangeNotifier view models + pages
```

Dependencies point inward only. Every boundary is an interface in `domain/services`
(`PmcsCatalogSource`, `FaultClassifierStrategy`, `PmcsEntityPort`, `MeshBroadcasterPort`,
`RemoteReportSource`, `QueueWorkerStrategy`, `QueuePromptStrategy`, `ReportCodec`,
`CacScannerStrategy`, `Clock`, `IdGenerator`), so the whole domain is testable with plain
fakes and no mocking framework.

Adding a vehicle platform is a `VehicleType` value plus a catalog registration — no change
to the inspection flow, the classifier, or the UI.

### Multi-threading

The offline queue runs off the UI thread. `IsolateQueueWorker` spawns a real isolate that
owns the per-transport state machine (what is parked, which legs are down, what is
in flight). `MainThreadQueueWorker` implements the same contract with a timer for the web
build — `Isolate.spawn` is unavailable in the host's WebView. `createQueueWorker` picks
one at wire-up; nothing else in the app knows which is running.

### The CAC sign-off

Submitting is a two-step gate on the summary screen: read a CAC, then send.

The Profile tab holds **only the UIC** now. A name and rank typed once and forgotten
could disagree with the card the Soldier actually signs with, so who walked the vehicle
is read off the CAC at the moment the PMCS closes out — never stored as a setting.

#### Which barcode, and why the copy never says "front"

A CAC carries two barcodes, on opposite faces, and only one of them can sign anything.

| | Front | Back |
|---|---|---|
| Printed | **portrait** (CR80, 1:1.587) | **landscape** — 90° from the front |
| Symbology | **PDF417**, ~12.5 x 24.7 mm | **Code 39**, ~70 x 9.3 mm, horizontal |
| Where | lower-left corner, immediately left of the gold ICC chip | along the long edge |
| Carries | 89 chars: name, rank, branch, category, DoD ID, expiry | 18 chars: DoD ID and card codes — **no name, no rank, no dates** |
| Ivy Pulse | reads it | detects it, to say "turn the card over" |

Ivy Pulse reads the **front**. But the word "front" is the one thing the UI never says to
an operator, and that is deliberate: at an installation gate a Soldier is trained to
present the **back** so AIE/DBIDS can read the Code 39 strip ("show the back of your CAC
to the sentry, keeping the horizontal bar code uncovered"), and every state driving licence
in their wallet carries its PDF417 on the back too. So every operator-facing string names
landmarks instead — *the side with your photo and the gold chip*, *the tall barcode bottom
left, beside the chip*, *not the wide strip the gate guard scans* — and the sign-off card
draws a small schematic of the front with the target lit up.

The back's Code 39 is recognised and then **refused**, never used. It has no name and no
rank in it, so letting it through would put a bare `DoD ID 1087987498` in a 5988-E
signature block with no way for a maintainer to tell it from a real read.

#### The format

The DMDC *DoD ID Bar Code Formats* SDK v7.5.0 — §2.2 for the front's 89-character PDF417
(88 on a legacy version-`1` card) and Table 2 for the back's 18-character Code 39. Both
are fixed-width ASCII with numeric fields packed base-32 over `0-9A-V` and dates as a day
count from 1 January 1000. `ParseCacBarcode` implements exactly that and nothing else, so
every rule is testable without a camera.

Three things it deliberately will not do:

- **A card issued before 1 December 2012** is rejected outright. On those the Person
  Designator Identifier field *is* the cardholder's SSN, and the app will not hold one
  even for the moment it takes to ignore it.
- **The date of birth and the card security identifier are decoded and dropped.** DoD
  guidance treats a DoD ID number paired with a date of birth as a reportable
  combination, and neither field says anything about who signed for a vehicle. What is
  kept is what goes in a 5988-E signature block: name, rank, service, category, DoD ID,
  card expiry.
- **Ivy Pulse does not keep the photograph.** The frame is decoded to pixels in memory and
  dropped: it is never written to disk by this app and never attached to a report.
  Photographing a US Government ID card is an offence under 18 U.S.C. § 701, so it is
  worth being exact about what is *not* covered — capture runs through the OEM camera app,
  which saves its own copy to DCIM on its own terms, and the host's WebView plugin writes
  its own temporary file passing the chooser's result across. Neither is reachable from
  inside an extension, so the sign-off card tells the operator to clear the gallery rather
  than reassuring them there is nothing to clear.

And two things it must keep on doing, each of which locked a real Soldier out of signing
until it did. Both failures were unrecoverable in the same way — the message sends the
operator to re-aim at a card they are already holding correctly — so both are pinned by
tests:

- **A blank last field is a real card, not a bad scan.** The middle initial is the final
  character of a version-`N` record and is a space for a Soldier with no middle name, as is
  the card instance on a version-`1`. Trimming the record ate it, turning an 89 into an 88
  that matched neither layout and refusing every such Soldier as `notACac`. Leading
  whitespace is still stripped unconditionally — field 0 is the version character and can
  never be a space — but the right edge is only trimmed when what arrived is not already a
  whole record.
- **A CAC is good *through* the date printed on it.** The expiry field decodes to midnight
  at the *start* of that day, so comparing against it directly deadlined the card from one
  second past midnight on its last valid day — and because `expired` is not worth retrying,
  that led the Soldier straight to an unverified submission with a good card in their hand.

A scan proves the Soldier is holding the card. It is **not** authentication: the barcode
is unsigned cleartext anyone can reprint. Binding a PMCS to an identity cryptographically
needs the CAC's PKI certificates, which the host does not expose.

#### How the camera is reached

`getUserMedia` does not work in the host today. Lattice Edge builds its extension
WebViews with `flutter_inappwebview` and passes no `onPermissionRequest`, so the plugin's
default `PermissionRequest.deny()` runs and the promise rejects with `NotAllowedError` —
a host-side gap, not something an extension can work around. (Anduril is adding it.)

So capture goes through `<input type="file" accept="image/*" capture="environment">`,
which the WebView's file chooser handles natively and hands to the Android camera app.
That path needs no host change, and it is the better UX anyway: full screen with
autofocus beats a viewfinder squeezed into the ~370px panel this extension gets.

Decoding is `zxing_lib` — pure Dart, so the one decoder serves the web build now and the
native compile later. `createCacScanner()` picks the implementation the platform can run,
the same way `createQueueWorker` does; off the web the scanner refuses honestly and the
operator gets the unverified path rather than a scanner that silently never reads.

#### What the operator sees

The camera is a separate full-screen Android activity. The extension does not own it,
cannot close it, and cannot tell the difference between a Soldier who backed out and one
who is still lining the card up — so the scan state is built around that rather than
around a happy path:

- **The camera app covers the screen**, so there is nothing useful to say while it is
  open. There is no progress plumbing and no "pass 2 of 3": it would render to a screen
  nobody is looking at and would change no decision.
- **CANCEL SCAN** gives up on this side, and says so in those words — it drops any photo
  that arrives late, and it cannot close the camera app. Without it, a camera that never
  came back was the end of the PMCS: `isScanning` latched, the retry was swallowed by its
  own double-tap guard, and the state rendered no controls at all.
- **A hard timeout** (`AppConstants.cacCaptureTimeout`, 120 s) resolves a stuck capture as
  `cameraTimedOut` rather than leaving a spinner up forever.
- **A late photo cannot re-latch an abandoned scan.** Every path that walks away bumps a
  generation counter, and a capture that resolves against a stale one is dropped — without
  it, a photo the operator gave up on signs the 5988-E.

#### What a refusal tells them

`CacRejection` values are the message, verbatim, and each one is an instruction rather
than a diagnosis. The decoder distinguishes them for free, off the exception ZXing already
throws plus one detector sweep on the miss path:

| Outcome | What it means | What it says |
|---|---|---|
| `noCodeFound` | nothing in the frame | fill the frame with the photo-and-chip side |
| `codeUnreadable` | symbol **located**, codewords would not resolve | wipe it, tilt it out of the light, hold steady |
| `cardTooSmall` | located, but under `minDecodableModulePx` (1.5 px/module) | turn it sideways and move closer |
| `wrongSideOfCard` | a CAC **Code 39** decoded | turn the card over — the tall barcode is bottom left |
| `cameraTimedOut` / `cancelled` | the capture never landed | try again, or submit unverified |

A miss also crops to the located symbol and decodes again before reporting anything, which
re-derives the binariser's black point from the barcode instead of from a frame that is
mostly card stock and sky. It costs nothing on a hit — the happy path returns before the
detector is ever reached.

`SCAN AGAIN` leads while another photograph could plausibly change the answer
(`CacRejection.isWorthRetrying`); for an expired card, a pre-2012 card, or a device with no
camera it swaps with `SUBMIT UNVERIFIED`, because a second photograph returns the same
answer. Neither control is ever removed, only demoted. Aiming advice escalates with the
miss count and says nothing on the first one.

A card that *reads* but is close to running out is not refused — the signature is good
today. The verified banner carries the expiry date and, inside
`CacIdentity.expiryWarningDays` (30), an amber note nested in the green panel. Thirty days
is the window a Soldier can act inside; a card that dies mid-rotation strands whoever has
been signing the 5988-Es.

> The `minDecodableModulePx` floor is the one number here that wants a real EUD photo to
> calibrate. Every miss logs `[IvyPulse] PDF417 miss: located=… modulePx=… frame=WxH`;
> read that before moving the constant.

### PMCS catalogs are generated

`lib/data/catalog/*.g.dart` is generated from the TM transcriptions in `tool/tm_source/`.
Never hand-edit it:

```bash
./tool/generate_catalog.sh
```

## Build & deploy

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift codegen
flutter test
./scripts/deploy-extension.sh --register                   # push to a connected device
```

## Features / Bugs:
> TODO's:
> - [ ] Maintainer role: verify faults, adjust severity, record corrective action.
> - [ ] Parts ordering off a fault (NSN suggestions are wired, the order flow is not).
> - [ ] 5988-E export.
> - [ ] Photos on a fault — blocked on the same host `onPermissionRequest` gap as live
>       CAC preview; the still-capture path used for the CAC would work today.
> - [ ] Live CAC preview once the host grants WebView camera permission — drops in behind
>       `CacScannerStrategy` with no change above it.
