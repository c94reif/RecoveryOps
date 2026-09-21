# Evacuation Request — Sample Extension

Demonstrates a MEDEVAC request form with priority classification and location picking.

## SDK Features Used

- **Location** — `context.location.requestPick()` for pickup location, `context.location.placeMarker()` with medical marker
- **Input** — `context.input.requestSpeech()` for voice dictation
- **Storage** — `context.storage.get/set()` for report persistence
- **Contacts** — `context.contacts.send()` and `context.contacts.onDataReceived()` for sending/receiving requests

## Key Files

- `lib/evac_request_plugin.dart` — Extension class and full UI
- `lib/main.dart` — Standalone preview runner

## Running

```bash
flutter pub get
flutter run -d <device>
flutter build web
```
