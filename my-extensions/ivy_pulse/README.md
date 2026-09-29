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

## Build & deploy

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift codegen
flutter test
./scripts/deploy-extension.sh --register                   # push to a connected device
```

### Package source for upload

```bash
./scripts/package-zip.sh                       # creates ../ivyPulse-source.zip
./scripts/package-zip.sh /tmp/ivyPulse.zip      # optional output path
```

The script works from any working directory and includes the `ivy_pulse/` source
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


