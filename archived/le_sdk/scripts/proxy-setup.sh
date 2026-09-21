#!/usr/bin/env bash
# =============================================================================
# Proxy Setup — DEVELOPMENT TOOL ONLY
#
# Configures connected Android devices/emulators to route traffic through a
# local proxy. Use with an HTTPS interception proxy (e.g. mitmproxy) to
# bypass CORS restrictions during Lattice Edge extension development.
#
# WARNING: This routes ALL device traffic through the proxy. Only use for
# local development and testing. Never use in production environments.
#
# Usage:
#   bash le_sdk/scripts/proxy-setup.sh              # Configure devices
#   bash le_sdk/scripts/proxy-setup.sh --port 8888  # Custom port
#   bash le_sdk/scripts/proxy-setup.sh --clear       # Clear proxy from devices
#
# The script sets the proxy and waits. Press Ctrl+C to clear the proxy from
# all devices and exit. Start your proxy server separately (see docs).
#
# See: le_sdk/docs/proxy-setup.md
# =============================================================================

set -euo pipefail

PORT=9090
CLEAR_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --clear) CLEAR_ONLY=true; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# --- Find adb ----------------------------------------------------------------

ADB=$(command -v adb 2>/dev/null || echo "${ANDROID_HOME:-${LOCALAPPDATA:-$HOME}/Android/Sdk}/platform-tools/adb")
if ! command -v "$ADB" &>/dev/null && [[ ! -x "$ADB" ]]; then
  echo "ERROR: adb not found. Install Android SDK platform-tools or set ANDROID_HOME."
  exit 1
fi

# --- Find devices -------------------------------------------------------------

DEVICES=$("$ADB" devices -l 2>/dev/null | tr -d '\r' | grep -E "device\s+" | awk '{print $1}')
if [[ -z "$DEVICES" ]]; then
  echo "No connected devices/emulators found."
  exit 1
fi

# --- Host LAN IP (for physical devices) --------------------------------------

get_lan_ip() {
  if command -v ip &>/dev/null; then
    ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}'
  elif command -v ipconfig &>/dev/null; then
    ipconfig 2>/dev/null | grep -A5 "Wi-Fi\|Ethernet" | grep "IPv4" | head -1 | awk '{print $NF}'
  else
    hostname -I 2>/dev/null | awk '{print $1}'
  fi
}

LAN_IP=$(get_lan_ip)

# --- Clear proxy --------------------------------------------------------------

clear_proxy() {
  echo "Clearing proxy from devices..."
  for SERIAL in $DEVICES; do
    "$ADB" -s "$SERIAL" shell settings put global http_proxy :0 2>/dev/null || true
    "$ADB" -s "$SERIAL" reverse --remove tcp:"$PORT" 2>/dev/null || true
    echo "  $SERIAL — proxy cleared"
  done
  echo "Done."
}

if [[ "$CLEAR_ONLY" == true ]]; then
  clear_proxy
  exit 0
fi

# --- Cleanup on exit ---------------------------------------------------------

trap clear_proxy EXIT

# --- Configure devices --------------------------------------------------------

echo "========================================"
echo "  CORS Development Proxy"
echo "  FOR LOCAL DEVELOPMENT ONLY"
echo "========================================"
echo ""
echo "Configuring proxy (port $PORT) on connected devices..."
echo ""

for SERIAL in $DEVICES; do
  if [[ "$SERIAL" == emulator-* ]]; then
    "$ADB" -s "$SERIAL" reverse tcp:"$PORT" tcp:"$PORT" >/dev/null
    "$ADB" -s "$SERIAL" shell settings put global http_proxy 127.0.0.1:"$PORT"
    echo "  $SERIAL (emulator) — 127.0.0.1:$PORT via adb reverse"
  else
    if [[ -z "$LAN_IP" ]]; then
      echo "  $SERIAL (device) — WARNING: could not detect LAN IP, skipping"
      continue
    fi
    "$ADB" -s "$SERIAL" shell settings put global http_proxy "$LAN_IP":"$PORT"
    echo "  $SERIAL (device) — $LAN_IP:$PORT"
  fi
done

echo ""
echo "Devices configured. Start your proxy server on port $PORT."
echo "Press Ctrl+C to clear the proxy from all devices and exit."
echo ""

# Wait until Ctrl+C
while true; do sleep 60; done
