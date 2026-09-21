#!/usr/bin/env python3
"""Tiny multicast UDP sender for testing the UDP Monitor extension.

Sends a datagram to a multicast group/port at a fixed interval. Run this on
the same LAN as the device (or on the dev machine + `adb` on an emulator) and
the UDP Monitor extension will show the datagrams arriving.

Usage:
    python3 udp_sender.py                          # 239.1.2.3:5005, "PING #n" every 1s
    python3 udp_sender.py --group 239.1.2.3 --port 5005 --interval 0.5
    python3 udp_sender.py --message "WARP|HR=72|SPO2=98"   # custom payload
    python3 udp_sender.py --once                   # send a single datagram and exit

Defaults match the UDP Monitor extension's prefilled group/port (239.1.2.3:5005).
"""
import argparse
import socket
import struct
import time


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--group", default="239.1.2.3", help="multicast group")
    ap.add_argument("--port", type=int, default=5005, help="UDP port")
    ap.add_argument("--interval", type=float, default=1.0,
                    help="seconds between datagrams")
    ap.add_argument("--message", default=None,
                    help="payload to send (default: 'PING #<n>')")
    ap.add_argument("--ttl", type=int, default=1,
                    help="multicast TTL (1 = local subnet)")
    ap.add_argument("--once", action="store_true",
                    help="send a single datagram and exit")
    args = ap.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL,
                    struct.pack("b", args.ttl))

    n = 0
    print(f"Sending to {args.group}:{args.port} "
          f"(ttl={args.ttl}, interval={args.interval}s). Ctrl+C to stop.")
    try:
        while True:
            n += 1
            payload = (args.message if args.message is not None
                       else f"PING #{n}").encode("utf-8")
            sock.sendto(payload, (args.group, args.port))
            print(f"  sent {len(payload)}B: {payload!r}")
            if args.once:
                break
            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        sock.close()


if __name__ == "__main__":
    main()
