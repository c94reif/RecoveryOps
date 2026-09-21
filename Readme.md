# Lattice Edge SDK Release - main
Build: 260911-150429

This release package contains the Lattice Edge Extension SDK.

## Projects

| Directory | Description |
|-----------|-------------|
| [`le_sdk/`](../../../../../../../run/media/creif/Noble_6/260911-150429/le_sdk/README.md) | Lattice Edge Extension SDK -- tools, packages, samples, and docs for building extensions |

## le_sdk

The SDK provides everything needed to build extensions for the Lattice Edge command-and-control application. Extensions are Flutter widgets that run alongside the main map view and can access host capabilities like location picking, speech-to-text, persistent storage, and peer-to-peer messaging.

Key contents:
- **`packages/`** -- `le_sdk` and `lattice_common` Dart packages
- **`samples/`** -- sample extensions (ie: field_report, chat, casevac_report, evac_request, lace_report, and more)
- **`scripts/`** -- Extension scaffolding and deploy scripts (bash + PowerShell)
- **`docs/`** -- Developer guide, API reference, and style guide
- **`host-apk/`** -- Lattice Edge APK for on-device testing

See the full [SDK README](../../../../../../../run/media/creif/Noble_6/260911-150429/le_sdk/README.md) for quick start instructions and details.

## Getting Started

1. Read the [SDK README](../../../../../../../run/media/creif/Noble_6/260911-150429/le_sdk/README.md) for prerequisites and quick start
2. Explore the [samples](le_sdk/samples/) to see what's possible
3. Create a new extension with `le_sdk/scripts/create-extension.ps1` (or `.sh`)
4. Review the [Developer Guide](../../../../../../../run/media/creif/Noble_6/260911-150429/le_sdk/docs/developer-guide.md) for the full walkthrough
