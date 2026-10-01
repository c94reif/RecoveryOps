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

## Adding vehicles, variants, and TMs

The **Vehicle & technical manual** picker is searchable by family, variant, and
TM number. Its entries come from
[`tool/tm_source/catalog-manifest.mjs`](tool/tm_source/catalog-manifest.mjs).
The current build includes the existing Stryker and JLTV checklists. Additional
manuals can be added when their checklist content is available.

1. Add a checklist source under `tool/tm_source/`, following
   [`pmcs-checks-jltv.mjs`](tool/tm_source/pmcs-checks-jltv.mjs). Export an object
   with `BEFORE`, `DURING`, and `AFTER` category arrays. Each category has a
   `category` name and `items`; each item has a stable `id`, `item` label, `check`
   instruction, and `faults` answer list. The first answer is serviceable;
   subsequent answers describe faults in increasing severity. The current
   [classifier](lib/domain/services/tm_fault_classifier.dart) uses `CRIT` in new
   critical-system IDs and answer order to assign severity, so check both
   against the source manual when transcribing.
2. Import that source in the manifest and add one entry per selectable variant:

   ```javascript
   {
     id: 'exampleCargo',              // Unique lower-camel-case Dart identifier
     wireName: 'EXAMPLE_CARGO',        // Stable ID in saved/shared reports
     displayName: 'Example cargo',     // Vehicle name shown on reports
     family: 'Example vehicle family',// Groups related variants in the picker
     variant: 'Cargo variant',        // Distinguishes models within that family
     technicalManual: 'Actual TM number and edition',
     source: EXAMPLE_CARGO_PMCS,
   }
   ```

   This is a registration example, not an included checklist. Variants share a
   `family` name but have distinct `id` and `wireName` values. Each `source`
   supplies that variant's applicable checks; reuse a source only when the TM
   covers the same checks for both variants.
3. From `my-extensions/circle-x`, run:

   ```bash
   ./tool/generate_catalog.sh
   node --test tool/tm_source/catalog-generator.test.mjs
   flutter analyze --no-pub
   flutter test --no-pub
   ```

The generator validates the manifest and checklists before writing files. It
creates the vehicle enum, checklist registration, and Dart catalog files.
Commit the source and generated files together, then rebuild the extension.
The picker and report serialization use the generated registry, so adding a
vehicle requires no UI or database-schema edits. Keep existing vehicle IDs and
check IDs stable to preserve saved inspections; keep registered entries for
vehicles with historical reports. Receiving clients need the same catalog
update to recognize a newly added vehicle ID. This is a build-time catalog;
the app does not import PDF manuals at runtime.

### TM source audit — 1 October 2026

Use the [TM download checklist](docs/TM_DOWNLOAD_CHECKLIST.md) to collect the
operator manuals, with checkboxes, variant coverage, official links, and the
files needed for import.

The existing checklist sources claim Stryker `TM 9-2355-311-10` and JLTV
`TM 9-2320-400-10`. Those exact numbers were not found in the current APD
Range 9 index. The registry refactor preserves the existing checklist data;
its source labels do **not** establish that the checklists match current TMs.
Compare the applicable PMCS work packages before replacing those labels or
enabling additional variants.

The following active operator-manual records were verified through APD. Dates
are APD publication dates; full manual content and any separately issued
changes have not been downloaded or incorporated into the application.

| Coverage | Official APD record | Publication date |
|---|---|---|
| JLTV M1278 / M1279 / M1280 / M1281 and their A1 variants | [TM 9-2320-452-10](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1028190) | 5 February 2024 |
| JLTV M1278A2 / M1279A2 / M1280A2 / M1281A2 | [TM 9-2320-264-10](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1033310) | 1 June 2026 |
| JLTV trailer M1289 | [TM 9-2330-345-10](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1024284) | 24 January 2022 |
| Stryker M1126, M1127, M1129A1, M1130, M1131A1, M1132, M1133, M1134 | [TM 9-2355-473-10](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1033411) | 20 July 2026 |
| Stryker DVH M1251–M1257 | [TM 9-2355-363-10](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1033523) | 21 July 2026 |
| Stryker DVH A1 M1251A1–M1257A1 | [TM 9-2355-450-10](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1032645) | 16 March 2026 |
| Stryker M1135 NBCRV | [TM 9-2355-326-10](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1032806) | 16 March 2026 |
| Stryker Dragoon, listed as XM 1296 | [TM 9-2355-459-10](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1027224) | 31 July 2023 |
| Stryker DVH A1 30 mm, listed as XM1304 | [TM 9-2355-480-10](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1030353) | 30 April 2025 |
| Stryker M1128 MGS, legacy | [TM 9-2355-321-10-1](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1022232), [-2](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1022233), [-3](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1022234), [-4](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1022235) | 15 June 2021; volume 3 record lists 15 May 2021 |
| SGT STOUT / M-SHORAD Increment 1 | [TM 9-1430-300-10](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1033555) | 24 August 2026 |

The second pass checked both the TM and electronic-media indexes, including
spaced model names and the [SGT STOUT naming change](https://www.army.mil/article-amp/277291/army_names_the_m_shorad_after_vietnam_war_medal_of_honor_recipient).
The acquisition inventory in
[`manual-inventory.json`](tool/tm_source/manual-inventory.json) lists every
covered model explicitly: 12 JLTV variants, one JLTV trailer, and 27 Stryker
configurations across 14 operator publications. It records publication dates,
source URLs, access attempts, and missing content. These are metadata matches;
none of the full manuals has been obtained or parsed and none of these new
entries has been enabled in the app. The inventory is separate from the
selectable checklist manifest.

DE M-SHORAD and later increments remain unresolved; SGT STOUT coverage must not
be assumed to include them. The MGS volume-date discrepancy also requires a
title-page check. APD publication status does not establish current fleet use.

APD directs these manual downloads to [AESIP](https://login.aesip.army.mil/portal/faces/home).
The Army's [IADS access instructions](https://iads.redstone.army.mil/gettingstarted.html)
also identify LDAC ETMs Online and its NIPR/account requirements. Use authorized
access to obtain the applicable manual and change record. This table is a source
lookup, not a claim of checklist coverage or an exhaustive list of every Stryker
configuration.

To continue the import, provide authorized full PDF sets or IETM packages/XML
with title pages, change records, and applicability/UOC definitions. PDF exports
from IADS should include all PMCS work packages and referenced figures. Each
imported check must retain its source work-package/item reference and model
applicability; a shared TM does not mean every check applies to every variant.

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

The schema now restricts fault severities and phases to their supported wire
values, requires a six-character uppercase alphanumeric UIC, and validates CAC
and typed identities. Verified signatures require a valid CAC identity;
unverified signatures cannot carry one. Install the updated schema at the same
configured path when deploying these validation fixes. Existing invalid records
are not migrated by changing this file: a valid local outgoing copy can repair
an unreadable live record, while permanent withdrawals remain authoritative.
Historical invalid UICs or identities require correction before republication.
Vehicle names remain extensible in the schema; each client only imports catalog
types it recognizes.

`flutter test` includes contract tests using the actual JSON Schema validator,
serializer output, and mesh create/update paths. Tests also cover invalid input,
repair of rejected records, and withdrawal protection. No live-store connection
is needed for these checks.

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
