# Field Report — Sample Extension

Demonstrates a medium-complexity extension for filing field reports with location and voice input.

## SDK Features Used

- **Location** — `context.location.requestPick()` for map location selection, `context.location.placeMarker()` for placing markers
- **Input** — `context.input.requestSpeech()` for voice dictation
- **Storage** — `context.storage.get/set()` for persisting reports across sessions
- **Contacts** — `context.contacts.send()` and `context.contacts.onDataReceived()` for sending/receiving reports between devices

## Key Files

- `lib/field_report_plugin.dart` — Extension class and full UI implementation
- `lib/main.dart` — Standalone preview runner

## Running

```bash
flutter pub get
flutter run -d <device>     # standalone preview
flutter build web           # web build for host testing
```
