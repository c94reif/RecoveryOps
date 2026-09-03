# Lattice Edge Extension Developer Guide

## 1. Overview

Lattice Edge extensions are self-contained Flutter widgets that plug into the Lattice Edge command-and-control application. They appear as panels or overlays alongside the main map view and can access host capabilities such as map location picking, speech-to-text input, and persistent key-value storage. Extensions are **not** the same as ATAK/TAK plugins -- the TAK plugin system is a completely separate Android-native integration layer for interoperating with Android Team Awareness Kit. If you are building for TAK, this guide does not apply.

The standard development workflow uses a single Flutter/Dart codebase that serves two purposes. During development, you run `flutter build web` and load the output in the Lattice Edge host for rapid testing -- the SDK automatically bridges your Dart code to the host's JavaScript runtime. When you are ready to ship, you hand off the same Dart source as a package dependency, and Anduril compiles it natively into the host app with zero WebView overhead. You never write separate HTML or JavaScript.

The SDK package (`le_sdk`) exposes an `ExtensionContext` with domain-grouped accessors -- `context.map`, `context.speech`, and `context.storage` -- that provide a clean, autocomplete-friendly API surface. A static `ExtensionContext.connect()` factory detects the runtime environment automatically: it returns a real bridge context when running inside a WebView, and a stub context with fake data when running standalone for UI iteration.

## 2. Prerequisites

- **Flutter SDK** ^3.0.0 ([install guide](https://docs.flutter.dev/get-started/install))
- **Android device or emulator** for on-device testing
- **Lattice Edge host app** installed on the device (provides the extension runtime)
- Basic familiarity with Flutter widgets and Dart `async`/`await`

## 3. Create Your Extension

### Option A: Shell script (recommended)

From the SDK package root, run:

```bash
# macOS / Linux
./scripts/create-extension.sh my_report "My Report" "File quick field reports"
```

```powershell
# Windows (PowerShell)
.\scripts\create-extension.ps1 my_report "My Report" "File quick field reports"
```

Arguments:

| Position | Required | Description |
|----------|----------|-------------|
| 1 | Yes | Extension ID in `snake_case` (e.g. `my_report`) |
| 2 | No | Human-readable name (defaults to title-cased ID) |
| 3 | No | One-line description |

Expected output:

```
Creating extension: My Report (my_report)

Extension created at: ./my-extensions/my_report

Next steps:
  cd ./my-extensions/my_report
  flutter pub get
  flutter run -d <device>     # standalone preview
  flutter build web           # web build for testing
```

The generated directory structure:

```
my-extensions/my_report/
  pubspec.yaml                    # Package metadata + extension manifest
  lib/
    my_report_extension.dart      # LatticeEdgeExtension subclass
    main.dart                     # Entry point with ExtensionContext.connect()
  assets/
    logo.png                      # Placeholder icon
  fonts/
    Roboto-Regular.ttf            # Bundled font for offline web support
  .gitignore
```

### Option B: Claude skill

If you are using Claude Code, run the `/create-extension` skill. It asks for the extension name, ID, description, which API accessors you need, and the display mode, then generates a customized scaffold.

### Generated files walkthrough

**`pubspec.yaml`** declares the SDK dependency and the extension manifest:

```yaml
name: my_report
description: File quick field reports
version: 1.0.0
publish_to: 'none'

environment:
  sdk: ^3.0.0

dependencies:
  flutter:
    sdk: flutter
  le_sdk:
    path: ../../packages/le_sdk

flutter:
  assets:
    - assets/logo.png
  fonts:
    - family: Roboto
      fonts:
        - asset: fonts/Roboto-Regular.ttf

lattice_edge_extension:
  id: my_report
  name: My Report
  description: File quick field reports
  icon: extension
  display_mode: panel
```

**`lib/main.dart`** connects to the host and launches the UI:

```dart
import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';

import 'my_report_extension.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final context = await ExtensionContext.connect();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
    ),
    home: Scaffold(
      appBar: AppBar(
        title: const Text('My Report — Preview'),
        backgroundColor: const Color(0xFF0A0A0A),
      ),
      body: MyReportExtension().build(context),
    ),
  ));
}
```

`ExtensionContext.connect()` detects the runtime automatically. Inside the Lattice Edge WebView it wraps the injected JavaScript bridge; running standalone it returns a `StubExtensionContext` with fake location data, no-op speech, and in-memory storage.

## 4. Build Your Extension

This section walks through building a "Quick Report" extension that lets a field operator pick a map location, dictate a description, save drafts, and submit.

### Step 1: Define the extension class

```dart
import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';

class QuickReportExtension extends LatticeEdgeExtension {
  @override
  String get id => 'quick_report';

  @override
  String get name => 'Quick Report';

  @override
  String get description => 'File a field report with location and voice input';

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext context) => QuickReportForm(context: context);
}
```

### Step 2: Build the form widget

The complete widget below demonstrates all four SDK capabilities: location picking, speech input, storage, and close.

```dart
class QuickReportForm extends StatefulWidget {
  final ExtensionContext context;
  const QuickReportForm({super.key, required this.context});

  @override
  State<QuickReportForm> createState() => _QuickReportFormState();
}

class _QuickReportFormState extends State<QuickReportForm> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  LatLng? _location;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final title = await widget.context.storage.read('draft_title');
    final desc = await widget.context.storage.read('draft_desc');
    if (title != null) _titleCtrl.text = title;
    if (desc != null) _descCtrl.text = desc;
  }

  Future<void> _saveDraft() async {
    await widget.context.storage.write('draft_title', _titleCtrl.text);
    await widget.context.storage.write('draft_desc', _descCtrl.text);
  }

  Future<void> _pickLocation() async {
    final loc = await widget.context.map.pickLocation();
    if (loc != null) setState(() => _location = loc);
  }

  Future<void> _dictate() async {
    final text = await widget.context.speech.dictate();
    if (text != null) {
      _descCtrl.text = '${_descCtrl.text} $text'.trim();
      _saveDraft();
    }
  }

  Future<void> _submit() async {
    if (_location != null) {
      await widget.context.map.addMarker(
        _location!,
        label: _titleCtrl.text,
      );
    }
    await widget.context.storage.delete('draft_title');
    await widget.context.storage.delete('draft_desc');
    widget.context.close();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          controller: _titleCtrl,
          decoration: const InputDecoration(labelText: 'Title'),
          onChanged: (_) => _saveDraft(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descCtrl,
          decoration: const InputDecoration(labelText: 'Description'),
          maxLines: 4,
          onChanged: (_) => _saveDraft(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _dictate,
            icon: const Icon(Icons.mic),
            label: const Text('Dictate'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _pickLocation,
            icon: const Icon(Icons.location_on),
            label: Text(_location != null
                ? '${_location!.latitude.toStringAsFixed(4)}, ${_location!.longitude.toStringAsFixed(4)}'
                : 'Pick Location'),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
            ),
            child: const Text('Submit Report'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }
}
```

Key points in this code:

- **`context.map.pickLocation()`** opens the host's map picker. Returns `LatLng` or `null` if the user cancels.
- **`context.speech.dictate()`** starts native speech-to-text. Returns recognized text or `null`.
- **`context.storage.write()` / `context.storage.read()`** persist draft data across sessions.
- **`context.close()`** tells the host to dismiss this extension's panel or overlay tab.
- All buttons are 48px tall for glove-friendly touch targets.
- `ClampingScrollPhysics` prevents bouncy overscroll.

## 5. Test Your Extension

There are four ways to test, from fastest iteration to most realistic.

### Install the host APK

Before testing with the Lattice Edge host (Methods 2–4), install the APK:

```bash
adb install host-apk/lattice-edge.apk
```

### Method 1: Hot reload in Chrome (recommended for development)

```bash
cd my-extensions/my_report
flutter pub get
flutter run -d chrome
```

This runs `main.dart` directly in Chrome with full **hot reload** — edit code, press `r`, and see changes instantly. `ExtensionContext.connect()` returns a `StubExtensionContext` that provides:

- `map.pickLocation()` returns a randomized coordinate near (33.6938, -117.9166)
- `location.getCurrentLocation()` returns a fixed coordinate (33.6938, -117.9166)
- `speech.dictate()` returns `null`
- `storage` uses an in-memory map (not persisted)
- `entities` is seeded with 3 stub entities (friendly, hostile, neutral)
- `tasks` supports full in-memory CRUD
- `close()` is a no-op

This is the fastest way to iterate on layout and widget logic.

### Method 2: Deploy script — serve mode (recommended for device testing)

The deploy script builds, registers, and serves your extension to a connected Android device/emulator in one command:

```bash
# macOS / Linux / Git Bash
./scripts/deploy-extension.sh my-extensions/my_report
```

```powershell
# Windows (PowerShell)
.\scripts\deploy-extension.ps1 my-extensions\my_report
```

The script will:
- Build a release web bundle (with offline CanvasKit support)
- Auto-register the extension in the host app's SharedPreferences
- Serve the build via a local HTTP server
- Set up `adb reverse` for emulators (fast localhost access)
- Restart the host app so the extension appears in the grid

On subsequent runs, the script detects the extension is already registered and **skips the app restart** — only the server restarts.

**Wasm dev server mode** — for faster iteration on device, use the `--wasm` flag:

```bash
./scripts/deploy-extension.sh --wasm my-extensions/my_report
```

```powershell
.\scripts\deploy-extension.ps1 -Wasm my-extensions\my_report
```

This uses `flutter run -d web-server --wasm` which compiles to a single WebAssembly file instead of hundreds of JS modules, giving fast load times on the emulator. To pick up code changes: stop the script (Ctrl+C), re-run it (~1s recompile).

**Additional flags:**

| Flag | PowerShell | Description |
|------|-----------|-------------|
| `--no-build` | `-NoBuild` | Skip build, use existing output |
| `--wasm` | `-Wasm` | Wasm dev server (fast load, ~1s recompile) |
| `--port PORT` | `-Port PORT` | Custom port (default: 8080) |
| `--deploy-on-device` | `-DeployOnDevice` | Push files to device instead of serving |
| `--register` | `-Register` | Auto-register (with `--deploy-on-device`) |

### Method 3: Deploy script — push to device

For disconnected environments without a network connection between dev machine and device:

```bash
./scripts/deploy-extension.sh --deploy-on-device --register my-extensions/my_report
```

This builds the web bundle, pushes all files to `/sdcard/LatticeEdge/extensions/<id>/` on the device, and optionally auto-registers via `--register`. No running HTTP server is needed.

### Method 4: Manual web build + serve

If you prefer manual control:

```bash
cd my-extensions/my_report
flutter build web --no-web-resources-cdn
python3 -m http.server 8080 --directory build/web --bind 0.0.0.0
```

Then register the URL in the host app:

1. Open **Settings** (right panel)
2. Expand the **Plugins** section
3. Tap **Register Plugin** and enter a name and the URL: `http://<your-dev-machine-ip>:8080`
4. The extension appears in the plugin grid

> **Note:** Use `--no-web-resources-cdn` to bundle CanvasKit locally. Without it, the extension requires internet access to load.

In this mode, `ExtensionContext.connect()` detects the WebView environment and bridges to the host's injected `window.LatticeEdgeExtension` object. All capabilities (location, speech, storage) work against the real host.

### Recommended workflow

1. **Develop** with `flutter run -d chrome` — hot reload, instant feedback
2. **Test on device** with `deploy-extension.sh --wasm` — verify in the real host app
3. **Final test** with `deploy-extension.sh` (release build) — production-like performance

## 6. Ship to Anduril

When your extension is ready for production, there are two delivery options.

### Option A: Git repository (preferred)

Push your extension to a Git repository. Provide Anduril with:

- Repository URL
- Branch name or version tag
- Any required environment configuration

Anduril adds your extension as a dependency in the host app:

```yaml
# In the host app's pubspec.yaml
dependencies:
  my_report:
    git:
      url: https://github.com/your-org/my_report.git
      ref: v1.0.0
```

And registers it at startup:

```dart
extensionService.registerExtension(QuickReportExtension());
```

Your extension compiles natively into the host app -- no WebView overhead.

### Option B: Prebuilt package handoff

If you cannot share repository access, package the following into a zip archive:

- `lib/` -- all Dart source files
- `assets/` -- icon and other assets
- `pubspec.yaml` -- must include the `lattice_edge_extension:` manifest section
- `README.md` -- setup instructions and configuration notes

Submit the archive to Anduril via the agreed intake channel.

### Delivery Checklist

Before submitting your extension, verify:

- [ ] Extension runs in standalone preview without errors
- [ ] Extension runs in host app via web build registration
- [ ] `pubspec.yaml` has a valid `lattice_edge_extension:` manifest section
- [ ] All assets are included (icons, images)
- [ ] No hardcoded file paths or device-specific configuration
- [ ] README.md with setup instructions is included

### Extension manifest format

Your `pubspec.yaml` must include the `lattice_edge_extension:` section:

```yaml
lattice_edge_extension:
  id: my_report              # Unique identifier (snake_case)
  name: My Report            # Display name in the extension grid
  description: File quick field reports
  icon: extension            # Material icon name, or 'custom' for iconAsset
  display_mode: panel        # 'panel' or 'overlay'
```

### Repository structure requirements

```
my_report/
  pubspec.yaml              # With lattice_edge_extension: section
  lib/
    my_report_extension.dart
    main.dart
  assets/
    logo.png
  README.md
```

## 7. API Reference

For the complete API reference covering all accessors (location, input, storage, contacts), types, error handling, and storage behavior, see the **[API Reference](api-reference.md)**.

A quick summary of the accessor surface:

| Accessor | Key Methods |
|----------|-------------|
| `context.map` | `pickLocation()`, `addMarker()` |
| `context.speech` | `dictate()` |
| `context.storage` | `read()`, `write()`, `delete()` |
| `context.messaging` | `getPeers()`, `send()`, `broadcast()`, `onMessageReceived`, and more |
| `context.hostInfo` | Returns `HostInfo` with host name, version, and extension ID |
| `context.close()` | Dismisses this extension's panel or overlay tab |

## 8. Style Guide Essentials

Extensions must follow the Lattice Edge visual style to provide a consistent user experience. The complete guide is at `docs/style-guide.md`. Key rules:

**Touch targets:** All interactive elements (buttons, tiles, icons, tabs) must be at least **48x48 pixels**. Users operate with gloves in field conditions.

**Scroll physics:** Always use `ClampingScrollPhysics` on scrollable containers. No bouncy overscroll. Wrap scrollable containers in `ClipRect` to prevent content bleed during fast scrolls.

**Dark theme only:**

| Token | Hex | Usage |
|-------|-----|-------|
| Background | `#0A0A0A` | Panel/drawer background |
| Surface | `#111111` | Input fields, cards |
| Border Active | `#2A2A2A` | Input borders, button outlines |
| Text Primary | `#FFFFFF` | Headings, active labels |
| Text Secondary | `#888888` | Descriptions, subtitles |
| Accent | `#FF6B35` | Primary actions, active indicators |

**Animations:** 200-300ms maximum for functional transitions. No decorative animations.

**No hover-only interactions.** Everything must work with tap. Avoid swipe gestures as primary navigation.

**Input fields:** Use `#111111` fill, `#2A2A2A` border, 14px vertical padding. Never place inline suffix actions in text fields (URLs and long strings need full width).

## 9. Advanced: Raw HTML/JS Extensions

If you are porting an existing web application or prefer raw HTML/JS over Flutter, you can build extensions that communicate directly with the host's JavaScript bridge. This is not the standard path -- raw HTML/JS extensions always run inside a WebView and cannot be compiled natively into the host app.

### Direct bridge usage

The host injects `window.LatticeEdgeExtension` into every extension WebView. The object mirrors the Dart accessor structure:

```javascript
// Wait for the bridge to be injected
function onReady() {
  const ext = window.LatticeEdgeExtension;

  // Get host info
  const info = ext.hostInfo;
  console.log(info.extensionId);

  // Pick a location
  const loc = await ext.map.pickLocation();
  if (loc) {
    console.log(loc.latitude, loc.longitude);
  }

  // Speech to text
  const text = await ext.speech.dictate();

  // Storage
  await ext.storage.write('key', 'value');
  const val = await ext.storage.read('key');
  await ext.storage.delete('key');

  // Close
  ext.close();
}

// The bridge may not be available immediately -- use the ready callback
if (window.LatticeEdgeExtension) {
  onReady();
} else {
  window.__LatticeEdgeExtension_onBridgeReady = onReady;
}
```

### Using the TypeScript SDK

For typed access, install the optional TypeScript SDK:

```html
<script src="lattice-edge-extension-sdk.js"></script>
```

Or import it as an ES module:

```typescript
import { ready } from '@lattice-edge/extension-sdk';

const ctx = await ready(5000); // timeout in ms

const info = ctx.hostInfo;
const loc = await ctx.map.pickLocation();
const text = await ctx.speech.dictate();
await ctx.storage.write('draft', JSON.stringify({ title: 'test' }));
ctx.close();
```

The `ready()` function waits for the bridge to be injected (using the `__LatticeEdgeExtension_onBridgeReady` callback internally) and returns a typed `LatticeEdgeExtensionSDK` object with the same accessor grouping as the Dart SDK.

### TypeScript SDK types

```typescript
interface LatLng {
  latitude: number;
  longitude: number;
}

interface HostInfo {
  host: string;
  version: string;
  extensionId: string;
}

interface LatticeEdgeExtensionSDK {
  readonly hostInfo: HostInfo;
  map: {
    pickLocation(): Promise<LatLng | null>;
    addMarker(location: LatLng, options?: {
      label?: string;
      color?: string;
      icon?: string;
      disposition?: string;
    }): Promise<string>;
    removeMarker(id: string): Promise<void>;
    getMarkers(): Promise<MapMarker[]>;
    clearMarkers(): Promise<void>;
    addPolyline(id: string, points: LatLng[], color?: string): Promise<void>;
    removePolyline(id: string): Promise<void>;
    clearPolylines(): Promise<void>;
    flyTo(location: LatLng, zoom?: number): Promise<void>;
  };
  location: {
    getCurrentLocation(): Promise<LatLng | null>;
  };
  speech: {
    dictate(): Promise<string | null>;
  };
  storage: {
    read(key: string): Promise<string | null>;
    write(key: string, value: string): Promise<void>;
    delete(key: string): Promise<void>;
  };
  close(): void;
}
```

## 10. Troubleshooting / FAQ

### Bridge timeout: "LatticeEdgeExtension bridge not available"

**Cause:** `ExtensionContext.connect()` (or `ready()` in JS) timed out waiting for the host to inject the bridge.

**Fixes:**
- Verify you are loading the extension inside the Lattice Edge app, not a regular browser.
- Increase the timeout: `ExtensionContext.connect(timeout: const Duration(seconds: 10))`.
- Check that the extension URL is reachable from the device (`adb shell curl <url>`).

### Storage not persisting across restarts

**Cause:** You may be running in standalone preview mode, where `StubExtensionContext` uses in-memory storage.

**Fixes:**
- Storage only persists when running inside the Lattice Edge host (web build or native).
- To test persistence, use Method 2 or 3 from the testing section (web build loaded in the host).

### Web build CORS errors

**Cause:** The Flutter web build tries to load assets from a different origin than the host WebView expects.

**Fixes:**
- Serve the web build with a local HTTP server (`python3 -m http.server 8080`), not via `file://` URLs.
- If using Chrome for desktop testing: `flutter run -d chrome --web-browser-flag --disable-web-security`.
- When deploying to the device via `adb push`, use the local file path registration in Settings.

### Extension loads but text/fonts are missing

**Cause:** Flutter web fetches the Roboto font from `fonts.gstatic.com` at runtime. If the device has no internet access, text won't render.

**Fixes:**
- Extensions created with the `create-extension` script already bundle Roboto. Verify your `pubspec.yaml` has:
  ```yaml
  flutter:
    fonts:
      - family: Roboto
        fonts:
          - asset: fonts/Roboto-Regular.ttf
  ```
- Ensure `fonts/Roboto-Regular.ttf` exists in your extension directory.

### Extension takes a long time to load on emulator

**Cause:** Debug builds load hundreds of individual JS modules. The emulator's virtual network (`10.0.2.2`) is slow for large transfers.

**Fixes:**
- Use the deploy script which automatically sets up `adb reverse` for fast localhost access on emulators.
- Use `--wasm` mode which compiles to a single file instead of hundreds of modules.
- Use the default serve mode (release build) for fastest load times.

### Extension does not appear in the grid

**Cause:** The extension is not registered with the host, or the manifest is malformed.

**Fixes:**
- For web extensions: verify the URL is registered under Settings → Plugins and the server is running.
- For native extensions: verify `extensionService.registerExtension(MyExtension())` is called at startup.
- Check that `pubspec.yaml` has a valid `lattice_edge_extension:` section with `id`, `name`, and `display_mode`.

### Location picker returns null immediately

**Cause:** The host's map view may not be loaded or the device may not have location permissions.

**Fixes:**
- Ensure the Lattice Edge map is visible before calling `pickLocation()`.
- Check that location permissions are granted to the host app.
- In standalone mode, `pickLocation()` returns a randomized coordinate near (33.6938, -117.9166) -- if you are getting `null`, you may have a custom stub.

### Speech recognition returns null

**Cause:** The device does not have a speech recognizer, microphone permissions are denied, or the user cancelled.

**Fixes:**
- Check microphone permissions for the host app.
- Test on a real device -- emulators may not support speech recognition.
- In standalone mode, `dictate()` always returns `null`. Use web build mode for real testing.
