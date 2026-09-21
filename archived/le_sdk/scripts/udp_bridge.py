#!/usr/bin/env python3
"""
UDP bridge for Android emulator multicast.

Bridges UDP multicast heartbeats between N emulators that can't
communicate directly due to isolated QEMU SLIRP networks.

How it works:
  1. iptables TEE inside each emulator duplicates outgoing multicast
     packets (239.2.3.100:41820) to the host gateway (10.0.2.2).
  2. The SLIRP NAT delivers these as unicast UDP to the host.
  3. This script captures them on the host and injects them into ALL
     emulators via emulator-console UDP redir ports.

Prerequisites (run before this script, or use --setup):
  - adb shell su 0 iptables -t mangle -A POSTROUTING \
        -d 239.2.3.100 -p udp --dport 41820 -j TEE --gateway 10.0.2.2
  - Emulator console: redir add udp:<redir_port>:41820

Usage:
  python udp_bridge.py
  python udp_bridge.py --setup
  python udp_bridge.py --emus emulator-5554 emulator-5556 emulator-5558
"""
import argparse
import json
import os
import socket
import sys
import time

# Force unbuffered output on Windows
sys.stdout.reconfigure(line_buffering=True)


def emulator_console_cmd(console_port: int, auth_token: str, command: str) -> str:
    """Send a command to the emulator console."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(5)
    sock.connect(("127.0.0.1", console_port))
    sock.recv(4096)  # banner
    sock.sendall(f"auth {auth_token}\n".encode())
    time.sleep(0.3)
    sock.recv(4096)
    sock.sendall(f"{command}\n".encode())
    time.sleep(0.3)
    resp = sock.recv(4096).decode(errors="replace")
    sock.sendall(b"quit\n")
    sock.close()
    return resp


def setup_emulator(adb: str, serial: str, console_port: int,
                   redir_port: int, auth_token: str, guest_port: int):
    """Configure iptables TEE and console redir on one emulator."""
    # iptables TEE (check first, add if missing)
    os.system(
        f'{adb} -s {serial} shell '
        f'"su 0 iptables -t mangle -C POSTROUTING '
        f'-d 239.2.3.100 -p udp --dport {guest_port} '
        f'-j TEE --gateway 10.0.2.2 2>/dev/null '
        f'|| su 0 iptables -t mangle -A POSTROUTING '
        f'-d 239.2.3.100 -p udp --dport {guest_port} '
        f'-j TEE --gateway 10.0.2.2"'
    )
    print(f"  {serial}: iptables TEE -> 10.0.2.2")

    # Console redir
    resp = emulator_console_cmd(console_port, auth_token,
                                 f"redir add udp:{redir_port}:{guest_port}")
    ok = "ok" in resp.lower() or resp.strip() == ""
    print(f"  {serial}: redir udp:{redir_port}->{guest_port} {'OK' if ok else resp.strip()}")


def run_bridge(capture_port: int, redir_ports: list):
    """
    Listen for TEE'd packets on capture_port and relay to all emulators.

    All emulators' TEE'd packets arrive at the host on the same dest port
    (41820). We send to all redir ports — the app ignores its own heartbeats
    by checking deviceId, so duplicates are harmless.
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("", capture_port))

    # Join multicast group on all interfaces
    mgroup = socket.inet_aton("239.2.3.100")
    mreq = mgroup + socket.inet_aton("0.0.0.0")
    try:
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)
    except OSError as e:
        print(f"  Warning: could not join multicast group: {e}")
        print(f"  Falling back to unicast capture on port {capture_port}")

    send_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    count = 0

    ports_str = ", ".join(f"localhost:{p}" for p in redir_ports)
    print(f"  Listening on port {capture_port} for TEE'd heartbeats...")
    print(f"  Relay: -> {ports_str}")
    print(f"  Press Ctrl+C to stop.\n")

    while True:
        try:
            data, (src_ip, src_port) = sock.recvfrom(4096)
            if not data:
                continue

            for port in redir_ports:
                send_sock.sendto(data, ("127.0.0.1", port))
            count += 1

            if count == 1 or count % 20 == 0:
                try:
                    msg = json.loads(data)
                    who = msg.get("callsign", "?")
                except Exception:
                    who = "?"
                print(f"  [{count}] Relayed heartbeat from {who} ({src_ip}:{src_port})", flush=True)

        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"  Error: {e}")

    print(f"\nBridge stopped. Relayed {count} packets total.")
    sock.close()
    send_sock.close()


def main():
    parser = argparse.ArgumentParser(description="UDP bridge for emulator multicast")
    parser.add_argument("--setup", action="store_true",
                        help="Configure iptables TEE and console redir before starting")
    parser.add_argument("--setup-only", action="store_true",
                        help="Configure iptables TEE and console redir, then exit (no bridging)")
    parser.add_argument("--guest-port", type=int, default=41820)
    parser.add_argument("--emus", nargs="+", default=["emulator-5554", "emulator-5556"],
                        help="Emulator serials (e.g. emulator-5554 emulator-5556)")
    parser.add_argument("--redir-ports", nargs="+", type=int, default=None,
                        help="Host UDP redir ports (default: console_port + 10000 per emu)")
    parser.add_argument("--adb", default="adb")
    args = parser.parse_args()

    # Derive redir ports from serial numbers if not specified
    console_ports = [int(s.split("-")[1]) for s in args.emus]
    if args.redir_ports is None:
        args.redir_ports = [cp + 10000 for cp in console_ports]

    if len(args.emus) != len(args.redir_ports):
        parser.error("--emus and --redir-ports must have the same number of entries")

    if args.setup or args.setup_only:
        token_path = os.path.join(os.path.expanduser("~"), ".emulator_console_auth_token")
        with open(token_path) as f:
            auth = f.read().strip()

        print("Configuring emulators...")
        for serial, cp, rp in zip(args.emus, console_ports, args.redir_ports):
            setup_emulator(args.adb, serial, cp, rp, auth, args.guest_port)
        print()

        if args.setup_only:
            return

    print("Starting UDP bridge...")
    run_bridge(args.guest_port, args.redir_ports)


if __name__ == "__main__":
    main()
