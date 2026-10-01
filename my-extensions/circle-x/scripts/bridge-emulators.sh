#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# bridge-emulators.sh
#
# Launches 2+ Android emulators with a shared WiFi network for
# multi-device testing. Peer discovery uses UDP multicast
# (239.2.3.100:41820) which works natively over the emulator's
# WiFi bridge — no synthetic heartbeat injection needed.
#
# Strategy:
#   The first emulator boots with -wifi-server-port <port>, creating
#   a virtual WiFi access point. All other emulators boot with
#   -wifi-client-port <port>, joining the same L2 network. Multicast
#   packets cross between emulators natively.
#
# Prerequisites:
#   - Two or more DIFFERENT Android AVDs (Google APIs images)
#   - Android SDK with emulator + platform-tools on PATH
#   - adb on PATH
#
# Usage:
#   ./scripts/bridge-emulators.sh                          # boot + install
#   ./scripts/bridge-emulators.sh --build                  # build APK first
#   ./scripts/bridge-emulators.sh --apk path/to/app.apk   # use specific APK
#   ./scripts/bridge-emulators.sh --skip-boot              # emulators already running
#   ./scripts/bridge-emulators.sh --skip-install           # just boot, no install
#   ./scripts/bridge-emulators.sh --devices 3              # boot 3 emulators
#   AVD_1=Pixel_8 AVD_2=Pixel_9 ./scripts/bridge-emulators.sh
# ─────────────────────────────────────────────────────────────────────
set -eo pipefail

# ── Configuration ────────────────────────────────────────────────────
AVD_1="${AVD_1:-Samsung_Galaxy_S23}"
AVD_2="${AVD_2:-Samsung_Galaxy_S23_2}"
AVD_3="${AVD_3:-Samsung_Galaxy_S23_3}"

APP_PACKAGE="com.lattice.webview"
# Default to the bundled host APK shipped with the SDK. Resolved relative to
# this script (my-extensions/recovery_ops/scripts → le_sdk/host-apk).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK_PATH="${APK_PATH:-$SCRIPT_DIR/../../../le_sdk/host-apk/lattice-edge-debug.apk}"

WIFI_PORT=9999  # WiFi bridge port (server listens, clients connect)

DO_BUILD=false
SKIP_BOOT=false
SKIP_INSTALL=false
NUM_DEVICES=2

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --build)        DO_BUILD=true; shift ;;
    --skip-boot)    SKIP_BOOT=true; shift ;;
    --skip-install) SKIP_INSTALL=true; shift ;;
    --devices)
      if [ -n "${2:-}" ]; then
        NUM_DEVICES="$2"; shift 2
      else
        echo "Error: --devices requires a number" >&2; exit 1
      fi ;;
    --apk)
      if [ -n "${2:-}" ]; then
        APK_PATH="$2"; shift 2
      else
        echo "Error: --apk requires a path argument" >&2; exit 1
      fi ;;
    --help|-h)
      echo "Usage: $0 [--build] [--apk <path>] [--skip-boot] [--skip-install] [--devices N]"
      echo ""
      echo "Options:"
      echo "  --build          Build a debug APK before installing"
      echo "  --apk <path>     Path to APK to install (default: $APK_PATH)"
      echo "  --skip-boot      Assume emulators are already running"
      echo "  --skip-install   Skip APK install"
      echo "  --devices N      Number of emulators to boot (2 or 3, default: 2)"
      echo ""
      echo "Environment:"
      echo "  AVD_1=<name>     First AVD name  (default: $AVD_1)"
      echo "  AVD_2=<name>     Second AVD name (default: $AVD_2)"
      echo "  AVD_3=<name>     Third AVD name  (default: $AVD_3)"
      echo "  APK_PATH=<path>  Same as --apk"
      echo ""
      echo "Networking:"
      echo "  Emulators are connected via WiFi bridge (-wifi-server-port/-wifi-client-port)."
      echo "  Multicast peer discovery (239.2.3.100:41820) works natively — no injection needed."
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Collect AVD names based on device count
AVDS=("$AVD_1" "$AVD_2")
[ "$NUM_DEVICES" -ge 3 ] && AVDS+=("$AVD_3")

# ── Colors ───────────────────────────────────────────────────────────
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*"; }
ok()   { echo -e "  ${GREEN}OK${NC}  $*"; }
warn() { echo -e "  ${YELLOW}!!${NC}  $*"; }
die()  { echo -e "  ${RED}FAIL${NC}  $*"; exit 1; }

# ── Preflight checks ───────────────────────────────────────────────
if ! command -v adb &>/dev/null; then
  if [ -n "${ANDROID_HOME:-}" ] && [ -x "$ANDROID_HOME/platform-tools/adb" ]; then
    export PATH="$ANDROID_HOME/platform-tools:$PATH"
  elif [ -x "$HOME/Library/Android/sdk/platform-tools/adb" ]; then
    export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
  elif [ -n "${LOCALAPPDATA:-}" ] && [ -x "$LOCALAPPDATA/Android/Sdk/platform-tools/adb" ]; then
    export PATH="$LOCALAPPDATA/Android/Sdk/platform-tools:$PATH"
  else
    die "Cannot find 'adb'. Install Android SDK platform-tools and add to PATH."
  fi
fi
ok "Found adb: $(command -v adb)"

# ── Helpers ──────────────────────────────────────────────────────────
find_emulator_bin() {
  if command -v emulator &>/dev/null; then
    echo "emulator"
  elif [ -n "${ANDROID_HOME:-}" ] && [ -e "$ANDROID_HOME/emulator/emulator" ]; then
    echo "$ANDROID_HOME/emulator/emulator"
  elif [ -e "$HOME/Library/Android/sdk/emulator/emulator" ]; then
    echo "$HOME/Library/Android/sdk/emulator/emulator"
  elif [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -e "$ANDROID_SDK_ROOT/emulator/emulator" ]; then
    echo "$ANDROID_SDK_ROOT/emulator/emulator"
  elif [ -n "${LOCALAPPDATA:-}" ] && [ -e "$LOCALAPPDATA/Android/Sdk/emulator/emulator" ]; then
    echo "$LOCALAPPDATA/Android/Sdk/emulator/emulator"
  else
    die "Cannot find the Android emulator binary. Set ANDROID_HOME."
  fi
}

wait_for_boot() {
  local serial="$1" timeout=120 elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    local boot_status=""
    boot_status=$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n') || true
    [ "$boot_status" = "1" ] && return 0
    sleep 2
    elapsed=$((elapsed + 2))
  done
  die "$serial did not boot within ${timeout}s"
}

discover_emulators() {
  adb devices 2>/dev/null | grep "^emulator-" | grep "device$" | cut -f1 || true
}

# ── Step 1: Boot emulators with WiFi bridge ────────────────────────
if [ "$SKIP_BOOT" = false ]; then
  EMU_BIN=$(find_emulator_bin)

  # Validate AVDs exist
  AVAILABLE=$("$EMU_BIN" -list-avds 2>/dev/null) || AVAILABLE=""
  for avd in "${AVDS[@]}"; do
    if ! echo "$AVAILABLE" | grep -qx "$avd"; then
      echo ""
      echo "  AVD '$avd' not found."
      echo ""
      echo "  Available AVDs:"
      echo "$AVAILABLE" | sed 's/^/    /'
      echo ""
      exit 1
    fi
  done

  # Check for duplicate AVDs
  if [ "$AVD_1" = "$AVD_2" ] || { [ "$NUM_DEVICES" -ge 3 ] && { [ "$AVD_1" = "$AVD_3" ] || [ "$AVD_2" = "$AVD_3" ]; }; }; then
    die "All AVDs must be different (each needs a separate serial number)."
  fi

  log "Killing any running emulators..."
  discover_emulators | while read -r emu; do
    [ -n "$emu" ] && adb -s "$emu" emu kill 2>/dev/null || true
  done
  sleep 3

  # Boot first AVD as WiFi server
  log "Starting ${BOLD}${AVDS[0]}${NC} (WiFi server on port $WIFI_PORT)..."
  "$EMU_BIN" -avd "${AVDS[0]}" -no-snapshot -no-audio -no-boot-anim -wifi-server-port "$WIFI_PORT" &>/dev/null &
  sleep 3

  # Boot remaining AVDs as WiFi clients
  for i in $(seq 1 $((NUM_DEVICES - 1))); do
    log "Starting ${BOLD}${AVDS[$i]}${NC} (WiFi client → port $WIFI_PORT)..."
    "$EMU_BIN" -avd "${AVDS[$i]}" -no-snapshot -no-audio -no-boot-anim -wifi-client-port "$WIFI_PORT" &>/dev/null &
    sleep 2
  done

  log "Waiting for $NUM_DEVICES emulators to appear..."
  for _ in $(seq 1 60); do
    EMU_COUNT=$(discover_emulators | grep -c "emulator-" || true)
    [ "$EMU_COUNT" -ge "$NUM_DEVICES" ] && break
    sleep 2
  done
fi

# ── Discover emulator serials ───────────────────────────────────────
EMUS=($(discover_emulators))

if [ "${#EMUS[@]}" -lt "$NUM_DEVICES" ]; then
  die "Expected $NUM_DEVICES emulators but found ${#EMUS[@]}. Check emulator output for errors."
fi

for emu in "${EMUS[@]}"; do
  ok "$emu"
done

if [ "$SKIP_BOOT" = false ]; then
  log "Waiting for boot..."
  for emu in "${EMUS[@]}"; do
    adb -s "$emu" wait-for-device && wait_for_boot "$emu" && ok "$emu booted"
  done
fi

# ── Step 2: Build APK (only with --build) ───────────────────────────
if [ "$DO_BUILD" = true ]; then
  log "Building debug APK..."
  flutter build apk --debug 2>&1 | tail -5
  [ -f "$APK_PATH" ] || die "APK not found at $APK_PATH"
  ok "APK built"
fi

# ── Step 3: Install ─────────────────────────────────────────────────
if [ "$SKIP_INSTALL" = false ]; then
  [ -f "$APK_PATH" ] || die "APK not found at $APK_PATH — provide --apk <path> or --build"
  log "Installing $APK_PATH..."
  for emu in "${EMUS[@]}"; do
    INSTALL_OUT=$(adb -s "$emu" install -r "$APK_PATH" 2>&1) || {
      echo "$INSTALL_OUT"
      die "Failed to install on $emu"
    }
    echo "$INSTALL_OUT" | tail -1
  done
  ok "Installed on all ${#EMUS[@]} emulators"
else
  log "Skipping install (--skip-install)"
fi

# ── Step 4: Start apps ──────────────────────────────────────────────
# Verify app is installed
for emu in "${EMUS[@]}"; do
  if ! adb -s "$emu" shell pm list packages 2>/dev/null | grep -q "$APP_PACKAGE"; then
    die "App '$APP_PACKAGE' is not installed on $emu. Run without --skip-install."
  fi
done

# Sync emulator clocks to host time to prevent message ordering issues
log "Syncing emulator clocks..."
HOST_TIME=$(date +%m%d%H%M%Y.%S)
CLOCKS_OK=true
for emu in "${EMUS[@]}"; do
  adb -s "$emu" shell su 0 date "$HOST_TIME" >/dev/null 2>&1 || CLOCKS_OK=false
done
if [ "$CLOCKS_OK" = true ]; then
  ok "Clocks synced"
else
  warn "Clock sync failed (requires Google APIs image with root)"
fi

log "Starting apps..."
for emu in "${EMUS[@]}"; do
  adb -s "$emu" shell am force-stop "$APP_PACKAGE" 2>/dev/null || true
done
sleep 2
for emu in "${EMUS[@]}"; do
  adb -s "$emu" shell monkey -p "$APP_PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
done
ok "Apps started on all ${#EMUS[@]} emulators"

# ── Step 5: Verify multicast discovery ───────────────────────────────
log "Waiting 15s for peer discovery via multicast..."
sleep 15

log "Checking multicast traffic..."
ALL_OK=true
for emu in "${EMUS[@]}"; do
  HB=$(timeout 8 adb -s "$emu" shell "su 0 tcpdump -i wlan0 -c 2 'udp and port 41820' -nn 2>&1" 2>/dev/null | tr -d '\r') || HB=""
  if echo "$HB" | grep -q "UDP"; then
    ok "$emu: multicast traffic confirmed"
  else
    warn "$emu: no multicast traffic detected"
    ALL_OK=false
  fi
done

# ── Done ─────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════${NC}"
if [ "$ALL_OK" = true ]; then
  echo -e "${GREEN}${BOLD}  Multi-device network ready${NC}"
else
  echo -e "${YELLOW}${BOLD}  Multi-device network ready (with warnings)${NC}"
fi
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════${NC}"
echo ""
echo "  Emulators: ${#EMUS[@]}"
for emu in "${EMUS[@]}"; do
  IP=$(adb -s "$emu" shell ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | tr -d '\r') || IP="?"
  echo "    $emu  wlan0=$IP"
done
echo ""
echo "  Discovery: UDP multicast 239.2.3.100:41820 (native, no injection)"
echo "  WiFi bridge: server on port $WIFI_PORT"
echo ""
echo "  Press Ctrl+C to stop emulators and exit."
echo ""

# ── Keep alive ──────────────────────────────────────────────────────
cleanup() {
  echo ""
  log "Shutting down emulators..."
  for emu in "${EMUS[@]}"; do
    adb -s "$emu" emu kill 2>/dev/null || true
  done
  log "Done."
}
trap cleanup EXIT INT TERM

wait
