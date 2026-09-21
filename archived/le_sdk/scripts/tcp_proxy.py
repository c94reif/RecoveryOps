#!/usr/bin/env python3
"""
TCP proxy for Android emulator message relay.

Listens on a local port (default 41821) and for each incoming connection,
determines which emulator sent it by reading the envelope's fromDeviceId,
then forwards to the OTHER emulator(s) via adb-forward ports.

Since all emulators see the peer at 10.0.2.2:41821, they all connect here.
We read the message, check who sent it, and forward to the others.

Usage:
  python tcp_proxy.py
  python tcp_proxy.py --emus emulator-5554 emulator-5556
  python tcp_proxy.py --emus emulator-5554 emulator-5556 --devices <id1> <id2>
"""
import argparse
import json
import socket
import struct
import sys
import time
import threading

sys.stdout.reconfigure(line_buffering=True)

# Built dynamically in main() from --emus args
# Maps emulator serial -> host adb-forward port (serial + 20000)
EMU_PORTS = {}

# Maps emulator serial -> deviceId (populated from --devices args)
DEVICE_MAP = {}

# Serialize forwarding to avoid overlapping adb forward connections
_forward_lock = threading.Lock()


def handle_connection(client_sock, client_addr, listen_port):
    """Handle one incoming TCP message and relay to other emulator(s)."""
    try:
        # Read length prefix (4 bytes, big-endian)
        length_bytes = b""
        while len(length_bytes) < 4:
            chunk = client_sock.recv(4 - len(length_bytes))
            if not chunk:
                client_sock.close()
                return
            length_bytes += chunk

        msg_len = struct.unpack(">I", length_bytes)[0]

        # Read the message body
        body = b""
        while len(body) < msg_len:
            chunk = client_sock.recv(min(4096, msg_len - len(body)))
            if not chunk:
                break
            body += chunk

        client_sock.close()

        # Parse to find sender
        try:
            envelope = json.loads(body)
            from_id = envelope.get("fromDeviceId", "")
            from_cs = envelope.get("fromCallsign", "?")
        except Exception:
            from_id = ""
            from_cs = "?"

        # Forward to ALL emulators except the sender
        forward_ports = []
        for emu_name, port in EMU_PORTS.items():
            emu_device_id = DEVICE_MAP.get(emu_name, "")
            if emu_device_id and emu_device_id == from_id:
                continue  # Don't send back to sender
            forward_ports.append((emu_name, port))

        # If we can't identify sender, send to all (app will ignore its own)
        if not forward_ports:
            forward_ports = [(name, port) for name, port in EMU_PORTS.items()]

        with _forward_lock:
            for emu_name, port in forward_ports:
                try:
                    fwd = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    fwd.settimeout(5)
                    fwd.connect(("127.0.0.1", port))
                    fwd.sendall(length_bytes + body)
                    # Allow adb forward tunnel to flush data before closing
                    time.sleep(0.5)
                    fwd.shutdown(socket.SHUT_WR)
                    fwd.close()
                    time.sleep(0.2)
                    print(f"  Relayed TCP from {from_cs} -> {emu_name} (port {port})", flush=True)
                except Exception as e:
                    print(f"  TCP relay to {emu_name}:{port} failed: {e}", flush=True)

    except Exception as e:
        print(f"  Connection error: {e}", flush=True)
        try:
            client_sock.close()
        except Exception:
            pass


def main():
    parser = argparse.ArgumentParser(description="TCP proxy for emulator messages")
    parser.add_argument("--port", type=int, default=41821, help="Listen port (default 41821)")
    parser.add_argument("--emus", nargs="+", default=["emulator-5554", "emulator-5556"],
                        help="Emulator serials (e.g. emulator-5554 emulator-5556)")
    parser.add_argument("--devices", nargs="+", default=None,
                        help="Device IDs corresponding to each emulator serial")
    args = parser.parse_args()

    # Build EMU_PORTS dynamically: serial -> console_port + 20000
    for serial in args.emus:
        console_port = int(serial.split("-")[1])
        EMU_PORTS[serial] = console_port + 20000

    # Build DEVICE_MAP from --devices args
    if args.devices:
        for serial, dev_id in zip(args.emus, args.devices):
            if dev_id:
                DEVICE_MAP[serial] = dev_id

    print(f"TCP proxy listening on 0.0.0.0:{args.port}", flush=True)
    print(f"  Forwarding to: {EMU_PORTS}", flush=True)
    if DEVICE_MAP:
        print(f"  Device map: {DEVICE_MAP}", flush=True)
    print(flush=True)

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", args.port))
    server.listen(5)

    try:
        while True:
            client_sock, client_addr = server.accept()
            t = threading.Thread(target=handle_connection,
                                 args=(client_sock, client_addr, args.port),
                                 daemon=True)
            t.start()
    except KeyboardInterrupt:
        print("\nTCP proxy stopped.", flush=True)
    finally:
        server.close()


if __name__ == "__main__":
    main()
