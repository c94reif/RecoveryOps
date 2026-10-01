# circle-x

## General Info:
Guided **PMCS** (Preventive Maintenance Checks and Services) for tactical vehicles on
Lattice Edge. Companion application for **Convoy Ops** / **Recovery Ops**.

The display name and source folder are `circle-x`. The host registration ID is
`circle_x`, matching the Dart package, just as Recovery Ops uses `recovery_ops`
for both. The Android helper package is `circle_x_android`.
The plugin logo is declared as `assets/logo.png` in the Flutter assets, using
the same registration pattern as Recovery Ops without an `iconAsset` override.
In a native host build the bundled logo is `packages/circle_x/assets/logo.png`.
Rebuild the host APK with this source to pick up the registration change; any
host registration or saved shortcut explicitly using `circle-x` must use
`circle_x`. Verify the logo in both the application grid and panel header.

Messages use `circle-x.report` and `circle-x.deletion`, with `circle-x` as the
Lattice integration name. Local storage uses `circle-x_db`; data from an earlier
installation remains in its previous database and is not automatically migrated.

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

## Build & deploy

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift codegen
flutter test
./scripts/deploy-extension.sh --register                   # push to a connected device
```

### Package source for upload

```bash
./scripts/package-zip.sh                       # creates ../circle-x-source.zip
./scripts/package-zip.sh /tmp/circle-x.zip      # optional output path
```

The script works from any working directory and includes the `circle-x/` source
folder while excluding build output, caches, local IDE settings, logs, and existing
ZIP files. It verifies the new archive before replacing an existing output ZIP.
Requires `zip` and `unzip`; a custom output directory must already exist.

## Features / Bugs:
> TODO's:
> - [/] Maintainer role: verify faults, adjust severity, record corrective action.
> - [/] Parts ordering off a fault (NSN suggestions are wired, the order flow is not).
> - [x] 5988-E export.
> - [ ] Photos on a fault — blocked on the same host `onPermissionRequest` gap as live
>       CAC preview; the still-capture path used for the CAC would work today.
> - [x] Live CAC preview once the host grants WebView camera permission — drops in behind
>       `CacScannerStrategy` with no change above it.
> - [ ] Need to fix the following god classess: 
>   - [ ] ReportsViewModel
>   - [ ] ReportsPageState
>   - [ ] SignOffCard
>   - [ ] CheckItemCard

## Maintainer reviews

Open **Profile → Enter maintainer mode** to check the remote store immediately
and search local and received PMCS by bumper number or UIC. Choose **Review
faults**, add a description for each fault, and swipe right for **Verified** or
left for **Not verified**. The matching buttons support keyboard and touch use.
Every fault needs a decision before **Submit review** offers **Scan CAC &
submit**. A failed or cancelled scan leaves the draft unsigned; there is no
typed or unsigned submission path for maintainer reviews. The scan records the
signer's identity, not a check of their maintainer qualifications.

Each batch is an immutable report snapshot with its own ID and a
`maintainerReview` linking it to the original PMCS. It preserves the operator's
faults, notes and signature, and is excluded from inspection history and vehicle
counts. Expand the original report in Reports or maintainer mode to see its
signed review batches. A decision does not change a fault's severity or clear a
vehicle deadline.

The batch and both transport queue entries commit in one database transaction.
Delivery then uses the existing mesh-store and peer-broadcast paths and retry
worker. Pending attempts survive restart and retry on reconnect. The local
database migrates to version 6 without changing existing report content.

Before deploying this feature, update the registered mesh-store schema using
[`schemas/report-v1.schema.json`](schemas/report-v1.schema.json), which adds the
optional `report.maintainerReview` field. Older registered schemas reject that
field, leaving store delivery queued. Update participating clients together;
older clients do not distinguish review snapshots from operator PMCS reports.


## Remote report storage

Mesh item store is the default remote storage strategy. The existing Lattice
entity implementation is retained and can be selected at build time. Local
Drift storage, the durable outbox, and peer-to-peer broadcasts remain enabled;
`REPORT_STORE` changes only the remote read/write backend. The existing `lattice`
queue transport value and `entityId` fields are retained for compatibility;
`entityId` is the stable application report ID, not a server-assigned item ID.

Before deploying the default, have a mesh-item-store administrator register
[`schemas/report-v1.schema.json`](schemas/report-v1.schema.json) at:

```text
sustainment/circle-x/pmcs-report/v1
```

The extension discovers this schema but cannot register it through the SDK.
Missing schemas or service failures fail publication and leave normal report
submissions available to the existing retry/outbox flow. There is no automatic
fallback to entities or dual writing.

Build with the default, or select the retained entity implementation:

```bash
flutter build web
flutter build web --dart-define=REPORT_STORE=entities
```

Override the four data-type path segments for a deployment (the registered schema
must still match this extension's report contract):

```bash
flutter build web \
  --dart-define=REPORT_STORE=meshItemStore \
  --dart-define=REPORT_STORE_NAMESPACE=sustainment \
  --dart-define=REPORT_STORE_DOMAIN=circle-x \
  --dart-define=REPORT_STORE_DATA_TYPE=pmcs-report \
  --dart-define=REPORT_STORE_VERSION=v1
```

When using a deployment script that builds by default, prebuild with these flags
and deploy with `--no-build` so the configured artifact is preserved.
Tests/embedders can also pass `reportStoreBackend` and `reportItemType` to
`configureDependencies`. One `ReportStoreStrategy` instance supplies both the
publisher and remote reader, including queue retries.

Items have no TTL. Writes resolve the stable report ID from the typed collection
before creating or updating a server-assigned item path, and verify persistence
with a read-back. Retries after a committed write with a lost response reuse the
existing item when visible. Same-device writes for an ID are serialized.
Concurrent disconnected writers can still create duplicates: the SDK exposes no
atomic upsert, conditional write, or uniqueness constraint. Reads collapse these
by report ID, latest `updatedAt`, then item ID. Clock skew and concurrent edits
remain backend limitations; this is not an exactly-once delivery guarantee.

Withdrawals are separate permanent items and dominate live duplicates, even if
a stale writer updates a live item afterward. Do not expire or manually remove
these withdrawal records while offline peers may still carry the old report.
The client lists only this configured data type and uses existing polling;
item streams are not needed for this refactor. Item records do not automatically
publish a Lattice COP entity; extension map markers continue using the map API.

Switching strategies does not migrate server records automatically. Locally
stored outgoing reports can republish through the existing reconciliation path;
remote-only historical entities require a separate migration if they must be
available in item-store mode. All participating extensions should use the same
backend and schema path for consistent remote reads and withdrawals.
