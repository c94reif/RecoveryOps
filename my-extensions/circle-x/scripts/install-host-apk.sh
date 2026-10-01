#!/usr/bin/env bash
set -euo pipefail

################################################################################
# Install Lattice Edge Host APK
#
# Default: installs the debug host APK on all connected devices.
#
# Usage: install-host-apk.sh [options]
#   --release:          install the release APK instead of debug
#   --apk PATH:         install a specific APK file (overrides --release/debug)
#   --uninstall-first:  uninstall any existing host app before installing
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CHECK="✓"
CROSS="✗"
ARROW="→"
BULLET="•"

print_success() { echo -e "${GREEN}${CHECK}${NC} $1"; }
print_error()   { echo -e "${RED}${CROSS}${NC} $1"; }
print_info()    { echo -e "${BLUE}${ARROW}${NC} $1"; }
print_warning() { echo -e "${YELLOW}${BULLET}${NC} $1"; }

print_header() {
  echo ""
  echo "=================================================="
  echo "  $1"
  echo "=================================================="
  echo ""
}

################################################################################
# Parse arguments
################################################################################

VARIANT="debug"
APK_OVERRIDE=""
UNINSTALL_FIRST=false

while [ $# -gt 0 ]; do
  case "$1" in
    --release) VARIANT="release"; shift ;;
    --debug) VARIANT="debug"; shift ;;
    --apk)
      if [ $# -lt 2 ]; then
        print_error "--apk requires a path"
        exit 1
      fi
      APK_OVERRIDE="$2"; shift 2 ;;
    --uninstall-first) UNINSTALL_FIRST=true; shift ;;
    -h|--help)
      sed -n '4,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) print_error "Unknown argument: $1"; exit 1 ;;
  esac
done

################################################################################
# Resolve APK path
################################################################################

print_header "Install Lattice Edge Host APK"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# scripts/ -> recovery_ops/ -> my-extensions/ -> wss-extensions/
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HOST_APK_DIR="$REPO_ROOT/le_sdk/host-apk"

if [ -n "$APK_OVERRIDE" ]; then
  APK_PATH="$APK_OVERRIDE"
else
  APK_PATH="$HOST_APK_DIR/lattice-edge-${VARIANT}.apk"
fi

if [ ! -f "$APK_PATH" ]; then
  print_error "APK not found: $APK_PATH"
  exit 1
fi

APK_SIZE_MB=$(( $(stat -c %s "$APK_PATH" 2>/dev/null || stat -f %z "$APK_PATH") / 1024 / 1024 ))
print_info "APK: $APK_PATH (${APK_SIZE_MB} MB, $VARIANT)"

################################################################################
# Locate adb
################################################################################

ADB=$(command -v adb 2>/dev/null || echo "${ANDROID_HOME:-${HOME}/Library/Android/sdk}/platform-tools/adb")

if ! "$ADB" version > /dev/null 2>&1; then
  print_error "adb not found. Install Android SDK platform-tools or set ANDROID_HOME."
  exit 1
fi

print_success "Found adb: $ADB"

################################################################################
# Verify devices connected
################################################################################

DEVICES=()
while IFS= read -r line; do
    DEVICES+=("$line")
done < <("$ADB" devices | grep 'device$' | awk '{print $1}')

if [ ${#DEVICES[@]} -eq 0 ]; then
  print_error "No Android device/emulator connected."
  echo "  Start an emulator or connect a device, then retry."
  exit 1
fi

if [ -n "${ANDROID_SERIAL:-}" ]; then
  DEVICES=("$ANDROID_SERIAL")
fi

for dev in "${DEVICES[@]}"; do
  dev_model=$("$ADB" -s "$dev" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || true)
  print_success "Device connected: ${dev_model:-unknown} ($dev)"
done

if [ ${#DEVICES[@]} -gt 1 ]; then
  print_info "Will install to all ${#DEVICES[@]} devices"
fi

################################################################################
# Install on each device
################################################################################

APP_PACKAGE="com.lattice.webview"

# Convert APK_PATH to native path on Windows/Git-Bash
if command -v cygpath > /dev/null 2>&1; then
  NATIVE_APK_PATH="$(cygpath -w "$APK_PATH")"
else
  NATIVE_APK_PATH="$APK_PATH"
fi

for dev in "${DEVICES[@]}"; do
  export ANDROID_SERIAL="$dev"

  print_header "Installing on Device: $dev"

  if [ "$UNINSTALL_FIRST" = true ]; then
    print_info "Uninstalling existing $APP_PACKAGE..."
    "$ADB" uninstall "$APP_PACKAGE" > /dev/null 2>&1 || print_warning "No existing install (or uninstall failed) — continuing"
  fi

  print_info "Installing APK (this can take a minute)..."
  # -r reinstall keeping data, -d allow downgrade, -g grant all runtime permissions
  if MSYS_NO_PATHCONV=1 "$ADB" install -r -d -g "$NATIVE_APK_PATH"; then
    print_success "Installed on $dev"
  else
    print_error "Install failed on $dev"
    print_warning "If you see INSTALL_FAILED_UPDATE_INCOMPATIBLE, re-run with --uninstall-first"
    exit 1
  fi

  # Launch the app so the user sees it ready
  print_info "Launching $APP_PACKAGE..."
  "$ADB" shell "monkey -p $APP_PACKAGE -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1 || \
    print_warning "Could not launch app — open it manually"
done

################################################################################
# Done
################################################################################

print_header "Installed: lattice-edge ($VARIANT)"

echo "  Installed on ${#DEVICES[@]} device(s)"
echo "  Package: $APP_PACKAGE"
echo ""
echo "  Next: deploy your extension with ./deploy-extension.sh"
echo ""
