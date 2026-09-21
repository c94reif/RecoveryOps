# UDP Monitor — sample extension

Demonstrates the host-brokered UDP `NetworkService` (`context.network`), which
lets a WebExtension receive and send UDP datagrams even though the WebView
sandbox cannot open raw sockets itself. The native host does the socket work
and bridges datagrams across.

## What it shows

A **Multicast / Unicast** toggle at the top switches which APIs the panel drives.
In unicast mode the address field becomes the send **Destination IP** (receive
binds `0.0.0.0:<port>`, so it stays editable while listening).

| SDK call | Where |
|---|---|
| `context.network.subscribeMulticast(group, port)` | "Listen" in **Multicast** mode — `await` resolves once the socket is bound + joined; a failed bind throws and shows as a status error |
| `context.network.subscribeUnicast(port)` | "Listen" in **Unicast** mode |
| `UdpSubscription.datagrams.listen(...)` | live datagram log (hex + ASCII), newest first |
| `UdpSubscription.send(bytes)` | "Send" while connected (multicast) — transmits from the bound socket to the joined group |
| `UdpSubscription.send(bytes, destinationIp:, port:)` | "Send" while connected (unicast) — bound socket to the entered destination |
| `context.network.sendMulticast(group, port, bytes)` | "Send" while idle (multicast) — fire-and-forget, ephemeral socket |
| `context.network.sendUnicast(ip, port, bytes)` | "Send" while idle (unicast) — fire-and-forget, ephemeral socket |
| `UdpSubscription.close()` | "Stop" button / `dispose()` |

All four `NetworkService` methods are exercised from the UI.

## Try it locally

1. **Deploy** to a connected device/emulator (from `le_sdk/`):
   ```bash
   ./scripts/deploy-extension.sh --wasm samples/udp_monitor
   ```
   (First run will `flutter create --platforms web` if `web/` is missing.)

2. **Send test traffic** from the dev machine:
   ```bash
   python3 samples/udp_monitor/tools/udp_sender.py
   ```
   This blasts `PING #n` to `239.1.2.3:5005` every second — the extension's
   prefilled defaults.

   > On an **emulator**, multicast from the host machine may not reach the
   > guest over the virtual NIC. For an end-to-end loop without a real LAN, run
   > the sender on a device on the same physical network, or use the relay
   > approach from the design spec.

3. In the app, open **UDP Monitor**, confirm the group/port, tap **Listen**.
   Datagrams appear in the log. Type a payload and tap **Send** to transmit.

## Standalone preview

```bash
cd samples/udp_monitor && flutter run -d chrome
```

`ExtensionContext.connect()` returns a `StubExtensionContext` whose network
service is a no-op (subscribe → empty stream, send → `error: 'stub'`). Useful
for iterating on the UI, not for real traffic.

## Notes

- Payloads are capped at 1400 bytes by the host (matches the mesh-transport cap).
- The host denies binding to privileged ports (< 1024) and the Lattice mesh
  port (51820); subscribing to those surfaces as a status error.
