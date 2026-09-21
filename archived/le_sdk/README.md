****# Lattice Edge Extension SDK

Build extensions for the Lattice Edge command-and-control application. Extensions are self-contained Flutter widgets that appear as panels or overlays alongside the main map view and can access host capabilities: map location picking, speech-to-text input, persistent storage, and peer-to-peer messaging.

## Prerequisites

- **Flutter SDK** ^3.0.0 ([install guide](https://docs.flutter.dev/get-started/install))
- **Android device or emulator** for on-device testing
- **Lattice Edge host APK** — see `host-apk/README.md` for installation

## Quick Start

### 1. Create a new extension

```bash
# macOS / Linux
./scripts/create-extension.sh my_plugin "My Plugin" "A short description"
```

**Windows users** have two options:

```powershell
# Option A: PowerShell (recommended on Windows)
.\scripts\create-extension.ps1 my_plugin "My Plugin" "A short description"
```

```bash
# Option B: Git Bash (ships with Git for Windows)
# Open Git Bash (typically at C:\Program Files\Git\bin\bash.exe) and run:
./scripts/create-extension.sh my_plugin "My Plugin" "A short description"
```

> **Note:** If you use Option A (PowerShell), you may need to adjust your execution policy
> to allow running local scripts: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

Both scripts accept an optional output directory parameter (defaults to `my-extensions/`):

```bash
# Custom output directory (bash)
./scripts/create-extension.sh my_plugin "My Plugin" "A short description" /path/to/output

# Custom output directory (PowerShell)
.\scripts\create-extension.ps1 my_plugin "My Plugin" "A short description" -OutputDir C:\path\to\output
```

This generates a runnable extension at `my-extensions/my_plugin/` (or your chosen output directory).

### 2. Add platform support

The scaffold generates a pure Dart/Flutter project. Add the platforms you need:

```bash
cd my-extensions/my_plugin
flutter create --platforms web,android .
```

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Preview standalone

```bash
flutter run -d <device-or-emulator>
```

This runs your extension in isolation with a stub context (fake location data, in-memory storage). Use this for rapid UI iteration.

### 5. Test in the Lattice Edge host

```bash
# Install the host APK (one time)
adb install ../host-apk/lattice-edge.apk

# Build your extension as a web app
flutter build web

# Serve it locally
cd build/web
python3 -m http.server 8080
```

On the device running Lattice Edge:
1. Open **Settings** (gear icon)
2. Tap **Register Web Extension**
3. Enter: `http://<your-dev-machine-ip>:8080`
4. Your extension appears in the extension grid

### 5b. Deploy to device (one command)

Build and push your extension directly to a connected Android device or emulator:

```bash
# macOS / Linux — from your extension directory
../../scripts/deploy-extension.sh .

# Or specify the path from the SDK root
./scripts/deploy-extension.sh my-extensions/my_plugin
```

```powershell
# Windows (PowerShell)
..\..\scripts\deploy-extension.ps1

# Or specify the path
.\scripts\deploy-extension.ps1 -ExtensionDir my-extensions\my_plugin
```

The script builds the web output, pushes `pubspec.yaml` and `build/web/` to the device, and prints first-time registration instructions. Subsequent deploys update in-place — no re-registration needed.

### 6. Build and ship

See [Shipping Your Plugin](docs/developer-guide.md#6-ship-to-anduril) in the developer guide.

## Package Contents

| Directory | Description |
|-----------|-------------|
| `docs/` | Developer guide, API reference, style guide |
| `packages/` | The `le_sdk` Dart package (your main dependency) |
| `templates/` | Scaffold templates used by `create-extension` scripts |
| `samples/` | 10 sample extensions — from simple reports to entity/task management |
| `scripts/` | Extension scaffolding and deploy scripts (bash + PowerShell) |
| `my-extensions/` | Your extensions go here (created by scaffold scripts) |
| `host-apk/` | Place the Lattice Edge APK here for on-device testing |

## Samples

| Sample | Complexity | What it demonstrates |
|--------|-----------|----------------------|
| `field_report` | Medium | Forms, location picker, speech dictation, send/receive via contacts |
| `chat` | High | Real-time peer-to-peer messaging, conversation list, voice notes |
| `evac_request` | Medium | MEDEVAC request with priority classification and location |
| `casevac_report` | Very High | Full 9-line CASEVAC report, MGRS coordinate conversion |
| `lace_report` | Medium | Logistics status tracking (Liquids, Ammo, Casualties, Equipment) |
| `entity_task_manager` | High | EntityService and TaskService APIs — create, browse, manage entities and tasks |
| `equipment_readiness` | High | Logistics reporting with unit/site selection, equipment catalog, peer messaging |
| `route_planner` | Medium | Map APIs: pickLocation, addMarker, addPolyline, flyTo, getMarkers |
| `icon_markers_demo` | Low | All 18 icon marker types with 4 disposition colors |
| `cors_test` | Low | CORS proxy verification — fetches external URL to test proxy setup |

## Documentation

- **[Extension Developer Guide](docs/developer-guide.md)** — Full walkthrough: create, build, test, ship
- **[API Reference](docs/api-reference.md)** — Complete SDK API: all accessors, methods, types, and error handling
- **[Style Guide](docs/style-guide.md)** — Required UI conventions (dark theme, 48px touch targets, etc.)
