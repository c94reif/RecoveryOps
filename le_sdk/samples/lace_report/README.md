# LACE Report — Sample Extension

Demonstrates a logistics report extension tracking Liquids, Ammunition, Casualties, and Equipment status.

## SDK Features Used

- **Storage** — `context.storage.get/set()` for report persistence
- **Contacts** — `context.contacts.send()` and `context.contacts.onDataReceived()` for sending/receiving reports

## Key Files

- `lib/lace_report_plugin.dart` — Extension class with LACE status tracking (green/amber/red/black)
- `lib/main.dart` — Standalone preview runner

## Running

```bash
flutter pub get
flutter run -d <device>
flutter build web
```
