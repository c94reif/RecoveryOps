#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# build-extension.sh
#
# Runs `flutter build web` and composes a self-contained
# lattice_edge_build/ folder ready to push to a device/emulator.
#
# Output structure:
#   <extension>/lattice_edge_build/
#   ├── pubspec.yaml
#   ├── web/          (compiled Flutter web app)
#   ├── assets/       (logo.png if present)
#   └── fonts/        (custom fonts if present)
#
# Usage:
#   ./scripts/build-extension.sh [options] [extension_dir]
#
# Options:
#   --no-build   Skip flutter build web (reuse existing build output)
#   --clean      Run flutter clean before building
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}>${NC} $1"; }
ok()    { echo -e "${GREEN}OK${NC} $1"; }
die()   { echo -e "${RED}FAIL${NC} $1" >&2; exit 1; }

NO_BUILD=false
CLEAN=false
EXT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --no-build) NO_BUILD=true; shift ;;
    --clean)    CLEAN=true; shift ;;
    -h|--help)
      sed -n '2,/^# ──/{ /^# ──/d; s/^# \?//p }' "${BASH_SOURCE[0]}"
      exit 0 ;;
    *) [ -z "$EXT_DIR" ] && EXT_DIR="$1"; shift ;;
  esac
done

EXT_DIR="${EXT_DIR:-$(pwd)}"
EXT_DIR="$(cd "$EXT_DIR" && pwd)"

[ -f "$EXT_DIR/pubspec.yaml" ] || die "No pubspec.yaml in $EXT_DIR"

EXT_NAME=$(grep -m1 '^name:' "$EXT_DIR/pubspec.yaml" | sed 's/^name:[[:space:]]*//')
[ -n "$EXT_NAME" ] || die "Could not read 'name:' from pubspec.yaml"

BUILD_DIR="$EXT_DIR/lattice_edge_build"

info "Extension: $EXT_NAME"
info "Source:    $EXT_DIR"
info "Output:    $BUILD_DIR"

# ── Build ────────────────────────────────────────────────────────────

if [ "$NO_BUILD" = false ]; then
  if [ ! -d "$EXT_DIR/web" ]; then
    info "Enabling web platform..."
    (cd "$EXT_DIR" && flutter create . --platforms web) 2>&1 | tail -3
  fi

  if [ "$CLEAN" = true ]; then
    info "Cleaning..."
    (cd "$EXT_DIR" && flutter clean)
  fi

  info "Running flutter pub get..."
  (cd "$EXT_DIR" && flutter pub get)

  info "Building web..."
  (cd "$EXT_DIR" && flutter build web --no-web-resources-cdn)
  ok "Flutter build complete"
fi

[ -f "$EXT_DIR/build/web/index.html" ] || die "build/web/index.html not found. Run without --no-build first."

# ── Compose lattice_edge_build ───────────────────────────────────────

info "Composing lattice_edge_build/..."

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cp "$EXT_DIR/pubspec.yaml" "$BUILD_DIR/pubspec.yaml"

cp -r "$EXT_DIR/build/web" "$BUILD_DIR/web"

if [ -f "$EXT_DIR/assets/logo.png" ]; then
  mkdir -p "$BUILD_DIR/assets"
  cp "$EXT_DIR/assets/logo.png" "$BUILD_DIR/assets/logo.png"
fi

if [ -d "$EXT_DIR/fonts" ]; then
  cp -r "$EXT_DIR/fonts" "$BUILD_DIR/fonts"
fi

ok "lattice_edge_build/ ready"

# ── Push to connected devices/emulators ──────────────────────────────

DEVICE_PATH="/sdcard/Documents/$EXT_NAME"

ADB=$(command -v adb 2>/dev/null || echo "${ANDROID_HOME:-${HOME}/Android/Sdk}/platform-tools/adb")
if ! "$ADB" version > /dev/null 2>&1; then
  die "adb not found. Install Android SDK platform-tools or set ANDROID_HOME."
fi

SERIALS=$("$ADB" devices | grep -w 'device$' | awk '{print $1}')
if [ -z "$SERIALS" ]; then
  die "No devices/emulators connected."
fi

for SERIAL in $SERIALS; do
  info "Pushing to $SERIAL at $DEVICE_PATH..."
  "$ADB" -s "$SERIAL" shell "rm -rf '$DEVICE_PATH'" 2>/dev/null || true
  "$ADB" -s "$SERIAL" push "$BUILD_DIR/." "$DEVICE_PATH/" || die "Push failed for $SERIAL"

  if "$ADB" -s "$SERIAL" shell "ls '$DEVICE_PATH/web/index.html'" >/dev/null 2>&1; then
    ok "$SERIAL: deployed"
  else
    die "$SERIAL: verification failed"
  fi
done

echo ""
echo "  Deployed $EXT_NAME to $DEVICE_PATH on $(echo "$SERIALS" | wc -l) device(s)"
echo ""
