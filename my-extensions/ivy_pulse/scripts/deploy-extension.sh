#!/usr/bin/env bash
set -euo pipefail

################################################################################
# Deploy Lattice Edge Extension
#
# Default: builds and pushes extension files to the device for offline use.
#
# Usage: deploy-extension.sh [options] [extension_dir]
#   extension_dir:      path to the extension (default: current directory)
#   --serve:            serve from dev machine instead of pushing to device
#   --register:         auto-register in SharedPreferences
#   --no-build:         skip flutter build web (use existing build output)
#   --wasm:             use wasm dev server (fast load, recompile on restart; implies --serve)
#   --port PORT:        port for the web dev server (default: 8080, serve mode only)
#
# Environment:
#   HOST_IP=x.x.x.x    override auto-detected host IP (serve mode only)
################################################################################

# Color codes
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
# Pubspec parsing helpers
################################################################################

get_field() {
  grep -m1 "^$1:" "$EXT_DIR/pubspec.yaml" | sed "s/^$1:[[:space:]]*//" | sed "s/^['\"]//;s/['\"]$//" || true
}

get_section_field() {
  local section="$1" key="$2"
  sed -n "/^${section}:/,/^[^ ]/p" "$EXT_DIR/pubspec.yaml" | grep -m1 "^[[:space:]]*${key}:" | sed "s/^[[:space:]]*${key}:[[:space:]]*//" | sed "s/^['\"]//;s/['\"]$//" || true
}

################################################################################
# Register extension in SharedPreferences
################################################################################

register_extension() {
  local url="$1"

  local pkg_name="$ID"
  local description version icon section display_mode sect_desc ext_id display_name
  description="$(get_field description | tr -s '[:space:]' ' ' | sed 's/>[[:space:]]*$//')"
  version="$(get_field version)"

  section="lattice_edge_extension"
  icon="$(get_section_field "$section" icon)"
  if [ -z "$icon" ]; then
    section="lattice_plugin"
    icon="$(get_section_field "$section" icon)"
  fi

  display_mode="$(get_section_field "$section" display_mode)"
  display_mode="${display_mode:-panel}"
  sect_desc="$(get_section_field "$section" description)"
  [ -n "$sect_desc" ] && description="$sect_desc"

  ext_id="web_$(echo "$pkg_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')"
  display_name="$(echo "$pkg_name" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')"
  [ -n "$version" ] && display_name="$display_name (v$version)"

  local manifest="{\"id\":\"$ext_id\",\"name\":\"$display_name\",\"type\":\"web\",\"url\":\"$url\",\"displayMode\":\"$display_mode\""
  [ -n "$description" ] && manifest="$manifest,\"description\":\"$description\""
  [ -n "$icon" ] && manifest="$manifest,\"icon\":\"$icon\""
  if [[ "$url" == file://* ]] && [ -f "$EXT_DIR/assets/logo.png" ]; then
    local device_path="/sdcard/LatticeEdge/extensions/$pkg_name"
    manifest="$manifest,\"iconImagePath\":\"$device_path/assets/logo.png\""
  fi
  manifest="$manifest}"

  print_info "Manifest: $manifest"

  local app_package="com.lattice.webview"
  local prefs_file="shared_prefs/FlutterSharedPreferences.xml"
  local prefs_tmp prefs_out

  prefs_tmp="$(mktemp)"
  if ! "$ADB" shell "run-as $app_package cat $prefs_file" > "$prefs_tmp" 2>/dev/null; then
    print_error "Could not read SharedPreferences. Is $app_package installed and debuggable?"
    rm -f "$prefs_tmp"
    exit 1
  fi

  prefs_out="$(mktemp)"

  python3 -c "
import sys, json, re

manifest = json.loads(sys.argv[1])
ext_id = sys.argv[2]
prefs_in = sys.argv[3]
prefs_out = sys.argv[4]

with open(prefs_in, 'r', encoding='utf-8') as f:
    xml = f.read()

m = re.search(r'name=\"flutter\.web_plugins\">([^<]*)</string>', xml)
if m:
    try:
        existing = json.loads(m.group(1))
    except:
        existing = []
    filtered = [e for e in existing if e.get('id') != ext_id]
    filtered.append(manifest)
    new_json = json.dumps(filtered, separators=(',', ':'))
    xml = xml[:m.start(1)] + new_json + xml[m.end(1):]
else:
    new_json = json.dumps([manifest], separators=(',', ':'))
    xml = xml.replace('</map>', '    <string name=\"flutter.web_plugins\">' + new_json + '</string>\n</map>')

with open(prefs_out, 'w', encoding='utf-8') as f:
    f.write(xml)
" "$manifest" "$ext_id" "$prefs_tmp" "$prefs_out"

  "$ADB" shell "run-as $app_package sh -c 'cat > $prefs_file'" < "$prefs_out"
  rm -f "$prefs_tmp" "$prefs_out"

  print_success "Extension registered"

  print_info "Restarting $app_package..."
  "$ADB" shell "am force-stop $app_package" > /dev/null 2>&1
  sleep 1
  "$ADB" shell "monkey -p $app_package -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
  print_success "App restarted"
}

################################################################################
# Parse arguments
################################################################################

DEPLOY_ON_DEVICE=true
REGISTER=false
NO_BUILD=false
WASM=false
PORT=8080
EXT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --deploy-on-device) DEPLOY_ON_DEVICE=true; shift ;;
    --serve) DEPLOY_ON_DEVICE=false; shift ;;
    --register) REGISTER=true; shift ;;
    --no-build) NO_BUILD=true; shift ;;
    --wasm) WASM=true; DEPLOY_ON_DEVICE=false; shift ;;
    --port)
      if [ $# -lt 2 ]; then
        print_error "--port requires a value"
        exit 1
      fi
      PORT="$2"; shift 2
      ;;
    *) [ -z "$EXT_DIR" ] && EXT_DIR="$1"; shift ;;
  esac
done

EXT_DIR="${EXT_DIR:-$(pwd)}"
EXT_DIR="$(cd "$EXT_DIR" && pwd)"

################################################################################
# Validate extension directory
################################################################################

print_header "Deploy Lattice Edge Extension"

if [ ! -f "$EXT_DIR/pubspec.yaml" ]; then
  print_error "No pubspec.yaml found in $EXT_DIR"
  echo "  Make sure you are in an extension directory or pass the path as an argument."
  exit 1
fi

# Extract extension ID from pubspec name field
ID=$(grep -m1 '^name:' "$EXT_DIR/pubspec.yaml" | sed 's/^name:[[:space:]]*//')
if [ -z "$ID" ]; then
  print_error "Could not read 'name:' from pubspec.yaml"
  exit 1
fi

print_info "Extension: $ID"
print_info "Directory: $EXT_DIR"

# Check for manifest section (warn only)
if ! grep -q 'lattice_edge_extension:' "$EXT_DIR/pubspec.yaml" && \
   ! grep -q 'lattice_plugin:' "$EXT_DIR/pubspec.yaml"; then
  print_warning "No 'lattice_edge_extension:' or 'lattice_plugin:' section in pubspec.yaml"
  print_warning "The host app will use defaults (entry: web/index.html, display_mode: panel)"
fi

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
# Verify device connected
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

# If ANDROID_SERIAL is set, target only that device
if [ -n "${ANDROID_SERIAL:-}" ]; then
  DEVICES=("$ANDROID_SERIAL")
fi

for dev in "${DEVICES[@]}"; do
  dev_model=$("$ADB" -s "$dev" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || true)
  print_success "Device connected: ${dev_model:-unknown} ($dev)"
done

if [ ${#DEVICES[@]} -gt 1 ]; then
  print_info "Will deploy to all ${#DEVICES[@]} devices"
fi

resolve_host_ip() {
  if [ "$IS_EMULATOR" = true ]; then
    # Use adb reverse so the emulator accesses the server via localhost,
    # bypassing the slow virtual network (10.0.2.2 truncates large files)
    "$ADB" reverse "tcp:$PORT" "tcp:$PORT" >/dev/null 2>&1 || true
    print_info "Set up adb reverse tcp:$PORT for emulator" >&2
    echo "127.0.0.1"
    return
  fi
  local ip=""
  if command -v ip > /dev/null 2>&1; then
    ip=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1)
  fi
  if [ -z "$ip" ] && command -v ifconfig > /dev/null 2>&1; then
    ip=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}')
  fi
  if [ -z "$ip" ]; then
    ip=$(ipconfig 2>/dev/null | grep -m1 'IPv4' | sed 's/.*: //' | tr -d '\r' || true)
  fi
  if [ -z "$ip" ]; then
    print_error "Could not detect host IP address."
    echo "  Set HOST_IP environment variable manually."
    exit 1
  fi
  echo "$ip"
}

if [ "$DEPLOY_ON_DEVICE" = false ]; then
  ################################################################################
  # Serve mode (default)
  ################################################################################

  # Serve mode targets a single device
  export ANDROID_SERIAL="${DEVICES[0]}"
  if [ ${#DEVICES[@]} -gt 1 ]; then
    print_warning "Serve mode targets one device. Using: $ANDROID_SERIAL"
  fi

  # Detect emulator vs physical device
  IS_EMULATOR=false
  QEMU=$("$ADB" shell getprop ro.kernel.qemu 2>/dev/null | tr -d '\r' || true)
  if [ "$QEMU" = "1" ]; then
    IS_EMULATOR=true
  fi

  # Check if port is already in use
  PORT_PID="$(netstat -ano 2>/dev/null | grep ":$PORT " | grep 'LISTEN' | awk '{print $NF}' | head -1)"
  if [ -z "$PORT_PID" ]; then
    PORT_PID="$(lsof -ti ":$PORT" 2>/dev/null | head -1 || true)"
  fi
  if [ -n "$PORT_PID" ]; then
    print_warning "Port $PORT is already in use (PID $PORT_PID)"
    printf "  Kill the process? [y/N] "
    read -r answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
      kill "$PORT_PID" 2>/dev/null || taskkill //PID "$PORT_PID" //F 2>/dev/null || true
      sleep 1
      print_success "Process killed"
    else
      print_error "Port $PORT is in use. Use --port to specify a different port."
      exit 1
    fi
  fi

  HOST_IP="${HOST_IP:-$(resolve_host_ip)}"
  SERVE_URL="http://${HOST_IP}:${PORT}"

  print_header "Serve Mode"
  print_info "URL: $SERVE_URL"
  if [ "$IS_EMULATOR" = true ]; then
    print_info "Emulator detected — using 10.0.2.2 (host loopback alias)"
  else
    print_info "Physical device — using host LAN IP: $HOST_IP"
  fi

  # Check if extension is already registered with this URL (skip restart if so)
  ALREADY_REGISTERED=false
  PREFS_CHECK="$(mktemp)"
  if "$ADB" shell "run-as com.lattice.webview cat shared_prefs/FlutterSharedPreferences.xml" > "$PREFS_CHECK" 2>/dev/null; then
    if grep -q "$SERVE_URL" "$PREFS_CHECK" 2>/dev/null; then
      ALREADY_REGISTERED=true
    fi
  fi
  rm -f "$PREFS_CHECK"

  if [ "$ALREADY_REGISTERED" = true ]; then
    print_success "Extension already registered at $SERVE_URL (skipping app restart)"
  else
    print_header "Registering Extension"
    register_extension "$SERVE_URL"
  fi

  if [ "$WASM" = true ]; then
    print_header "Starting Wasm Dev Server"
    print_info "Extension: $ID"
    print_info "Serving at: $SERVE_URL"
    print_info "Recompiles on restart (~1s). Press Ctrl+C to stop, then re-run to pick up changes."
    echo ""
    cd "$EXT_DIR" && exec flutter run -d web-server --web-port "$PORT" --web-hostname 0.0.0.0 --wasm
  fi

  # Build release web
  if [ "$NO_BUILD" = true ]; then
    print_info "Skipping build (--no-build)"
  else
    print_header "Building Web (release)"
    (cd "$EXT_DIR" && flutter build web --no-web-resources-cdn)
    print_success "Web build complete"
  fi

  if [ ! -f "$EXT_DIR/build/web/index.html" ]; then
    print_error "build/web/index.html not found. Run without --no-build first."
    exit 1
  fi

  print_header "Starting Web Server"
  print_info "Extension: $ID"
  print_info "Serving at: $SERVE_URL"
  print_info "Press Ctrl+C to stop"
  echo ""

  exec python3 -m http.server "$PORT" --directory "$EXT_DIR/build/web" --bind 0.0.0.0

else
  ################################################################################
  # Build web
  ################################################################################

  if [ "$NO_BUILD" = true ]; then
    print_info "Skipping build (--no-build)"
  else
    print_header "Building Web"
    (cd "$EXT_DIR" && flutter build web --no-web-resources-cdn)
    print_success "Web build complete"
  fi

  if [ ! -f "$EXT_DIR/build/web/index.html" ]; then
    print_error "build/web/index.html not found. Run without --no-build first."
    exit 1
  fi

  ################################################################################
  # Push to device
  ################################################################################

  DEVICE_PATH="/sdcard/LatticeEdge/extensions/$ID"

  # Convert EXT_DIR to native path for adb (Windows binary doesn't understand MSYS paths)
  if command -v cygpath > /dev/null 2>&1; then
    NATIVE_EXT_DIR="$(cygpath -w "$EXT_DIR")"
  else
    NATIVE_EXT_DIR="$EXT_DIR"
  fi

  for dev in "${DEVICES[@]}"; do
    export ANDROID_SERIAL="$dev"

    print_header "Deploying to Device: $dev"

    print_info "Target: $DEVICE_PATH"

    "$ADB" shell "mkdir -p '$DEVICE_PATH/web'" > /dev/null 2>&1

    # MSYS_NO_PATHCONV prevents Git Bash on Windows from mangling /sdcard/ paths
    print_info "Pushing pubspec.yaml..."
    MSYS_NO_PATHCONV=1 "$ADB" push "$NATIVE_EXT_DIR/pubspec.yaml" "$DEVICE_PATH/pubspec.yaml" > /dev/null 2>&1

    print_info "Pushing web build..."
    MSYS_NO_PATHCONV=1 "$ADB" push "$NATIVE_EXT_DIR/build/web/." "$DEVICE_PATH/web/" > /dev/null 2>&1

    # Push icon if present
    if [ -f "$EXT_DIR/assets/logo.png" ]; then
      print_info "Pushing icon..."
      "$ADB" shell "mkdir -p '$DEVICE_PATH/assets'" > /dev/null 2>&1
      MSYS_NO_PATHCONV=1 "$ADB" push "$NATIVE_EXT_DIR/assets/logo.png" "$DEVICE_PATH/assets/logo.png" > /dev/null 2>&1
    fi

    ############################################################################
    # Verify
    ############################################################################

    if "$ADB" shell "ls '$DEVICE_PATH/pubspec.yaml' '$DEVICE_PATH/web/index.html'" > /dev/null 2>&1; then
      print_success "Deployment verified on $dev"
    else
      print_error "Verification failed on $dev — files may not have been pushed correctly."
      exit 1
    fi

    ############################################################################
    # Register (optional)
    ############################################################################

    if [ "$REGISTER" = true ]; then
      print_header "Registering Extension on $dev"

      ENTRY="$(get_section_field lattice_edge_extension entry)"
      [ -z "$ENTRY" ] && ENTRY="$(get_section_field lattice_plugin entry)"
      ENTRY="${ENTRY:-web/index.html}"

      register_extension "file://$DEVICE_PATH/$ENTRY"
    fi

  done

  ################################################################################
  # Restart host app so it loads the fresh build (clears WebView cache)
  ################################################################################

  APP_PACKAGE="com.lattice.webview"
  for dev in "${DEVICES[@]}"; do
    export ANDROID_SERIAL="$dev"
    print_info "Restarting $APP_PACKAGE on $dev..."
    "$ADB" shell "am force-stop $APP_PACKAGE" > /dev/null 2>&1
  done
  sleep 1
  for dev in "${DEVICES[@]}"; do
    export ANDROID_SERIAL="$dev"
    "$ADB" shell "monkey -p $APP_PACKAGE -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
  done
  print_success "App restarted on ${#DEVICES[@]} device(s)"

  ################################################################################
  # Done
  ################################################################################

  print_header "Deployed: $ID"

  echo "  Deployed to ${#DEVICES[@]} device(s)"
  echo "  Files pushed to: $DEVICE_PATH"

  if [ "$REGISTER" = true ]; then
    echo "  Extension registered — it should appear in the extension grid."
  else
    echo ""
    echo "  First-time setup (one time only):"
    echo "    1. Open Lattice Edge on the device"
    echo "    2. Tap the Settings gear icon"
    echo "    3. Under \"Register Plugin\", tap \"Browse for Plugin Package\""
    echo "    4. Navigate to: LatticeEdge > extensions > $ID"
    echo "    5. Select the folder — the extension will appear in the grid"
    echo ""
    echo "  Or re-run with --register to auto-register."
  fi
  echo ""
  echo "  For subsequent deploys, just re-run this script."
  echo "  The extension updates automatically on next load."
  echo ""
fi
