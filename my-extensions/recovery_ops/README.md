How # Recovery Ops:
## General Info:
Companion application for **Convoy Ops**
> Developers: 
> - Christopher Reif
>   - Phone Number: (580)919-0457
>   - Email:
>     - Military: christopher.a.reif.mil@army.mil
>     - Personal: reifc@protonmail.com
 ---
## Features / Bugs:
>TODO's:
> - [x] Refactor reports_view_model.dart
> - [ ] Need to introduce Isolates. 
> - [ ] Need to refactor the profile page, profile view model, create database migration, and some other stuff to remove the callsign the profile page 
> - [ ] Need to go back and refactor the polling for either geometry and or the remote nav and the 


> Features:
> - [x] Filter the external reports based on distance

> Bugs:
> - [ ] Speech to Text isn't populating the input fields. 
> - [ ] 8 failing tests, but keeping them to remind me to go back and fix the profile View Model to get rid of the Call Sign field
> - [x] Remove the call sign from the profile page and use the one from LE.
> - [x] Need to pre-load external / your reports on load.
> - [x] Need to remove the bubbles being added to the map. 
> - [x] Need to re-evaluate how I'm placing the marekrs on the map.
> - [x] External EUD needs to stop showing that someone is navigating to them if they stop navigation

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
sustainment/recovery-ops/recovery-report/v1
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
  --dart-define=REPORT_STORE_DOMAIN=recovery-ops \
  --dart-define=REPORT_STORE_DATA_TYPE=recovery-report \
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
