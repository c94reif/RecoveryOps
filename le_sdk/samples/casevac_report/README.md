# CASEVAC Report — Sample Extension

Demonstrates a very high-complexity extension implementing the full 9-Line CASEVAC/MEDEVAC report format (US military standard).

## SDK Features Used

- **Location** — `context.location.requestPick()` for pickup and marking zones
- **Input** — `context.input.requestSpeech()` for voice dictation of report lines
- **Storage** — `context.storage.get/set()` for report persistence
- **Contacts** — `context.contacts.send()` and `context.contacts.onDataReceived()` for transmitting reports

## Key Files

- `lib/casevac_report_plugin.dart` — Extension class with all 9 CASEVAC lines and LatLng-to-MGRS conversion
- `lib/main.dart` — Standalone preview runner

## Running

```bash
flutter pub get
flutter run -d <device>
flutter build web
```
