# Chat — Sample Extension

Demonstrates a high-complexity extension for real-time peer-to-peer LAN chat with voice notes.

## SDK Features Used

- **Contacts** — Full contacts API: `getPeers()`, `onPeersChanged`, `pickRecipients()`, `send()`, `onDataReceived()`, `markAsRead()`, `markAllAsRead()`
- **Input** — `context.input.requestSpeech()` for voice-to-text
- **Storage** — `context.storage.get/set()` for chat persistence

## Key Files

- `lib/chat_plugin.dart` — Extension class and full chat UI
- `lib/main.dart` — Standalone preview runner

## Running

```bash
flutter pub get
flutter run -d <device>
flutter build web
```
