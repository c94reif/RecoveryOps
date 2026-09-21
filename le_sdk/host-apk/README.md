# Host APK

Place the Lattice Edge host APK in this directory before sharing the SDK package.

## Installation

```bash
adb install lattice-edge.apk
```

If updating an existing installation:

```bash
adb install -r lattice-edge.apk
```

## What This Provides

The Lattice Edge host APK is the runtime environment for your extensions. It provides:

- **Map view** with location picking (`context.location.requestPick()`)
- **Speech-to-text** engine (`context.input.requestSpeech()`)
- **Persistent storage** backed by SharedPreferences (`context.storage`)
- **Peer-to-peer contacts** and messaging over LAN (`context.contacts`)
- **Extension grid** where your extension appears after registration

Without the host APK, you can only test in standalone preview mode (stub context with fake data).

## Registering Your Extension

After installing the APK and building your extension as a web app:

1. Open Lattice Edge on the device
2. Tap the **Settings** gear icon
3. Tap **Register Web Extension**
4. Enter: `http://<your-dev-machine-ip>:8080` (or wherever you're serving the web build)
5. Your extension appears in the extension grid
