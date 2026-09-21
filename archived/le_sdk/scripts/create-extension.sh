#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <extension_id> [\"Extension Name\"] [\"Description\"] [output_dir]"
  echo "  extension_id: snake_case identifier (e.g. my_extension)"
  echo "  Extension Name: human-readable name (default: derived from ID)"
  echo "  Description: one-line description (default: empty)"
  echo "  output_dir: target directory (default: my-extensions/)"
  exit 1
fi

ID="$1"

# Validate extension_id is a valid Dart package name (lowercase, underscores, no leading digit)
if ! echo "$ID" | grep -qE '^[a-z][a-z0-9_]*$'; then
  echo "Warning: '$ID' is not a valid Dart package name."
  echo "  Must be lowercase_with_underscores, start with a letter, and use only [a-z0-9_]."
  echo "  See https://dart.dev/tools/pub/pubspec#name"
  printf "Continue anyway? [y/N] "
  read -r answer
  if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    exit 1
  fi
fi

# Convert snake_case to Title Case for name (portable — works on macOS and Linux)
NAME="${2:-$(echo "$ID" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')}"
DESC="${3:-A Lattice Edge extension}"
# Convert snake_case to PascalCase for class name (portable — uses sed -E, supported by both GNU and BSD sed)
CLASS=$(echo "$ID" | sed -E 's/(^|_)([a-z])/\U\2/g')
# Fallback for BSD sed (macOS) which doesn't support \U:
if echo "$CLASS" | grep -q '_'; then
  CLASS=$(echo "$ID" | awk -F_ '{for(i=1;i<=NF;i++) printf "%s", toupper(substr($i,1,1)) substr($i,2)}')
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates/lattice_edge_extension"
OUTPUT_BASE="${4:-$SCRIPT_DIR/../my-extensions}"
TARGET_DIR="$OUTPUT_BASE/$ID"

if [ -d "$TARGET_DIR" ]; then
  echo "Error: $TARGET_DIR already exists"
  exit 1
fi

echo "Creating extension: $NAME ($ID)"
mkdir -p "$TARGET_DIR/lib" "$TARGET_DIR/assets"

# Compute relative path from TARGET_DIR to the SDK packages directory
SDK_ABS="$(cd "$SCRIPT_DIR/../packages/le_sdk" && pwd)"
TARGET_ABS="$(mkdir -p "$TARGET_DIR" && cd "$TARGET_DIR" && pwd)"
SDK_PATH="$(python3 -c "import os, pathlib; print(pathlib.PurePosixPath(pathlib.Path(os.path.relpath('$SDK_ABS', '$TARGET_ABS'))))" 2>/dev/null \
  || python -c "import os, pathlib; print(pathlib.PurePosixPath(pathlib.Path(os.path.relpath('$SDK_ABS', '$TARGET_ABS'))))")"

# Copy and substitute templates
for tmpl in "$TEMPLATE_DIR"/*.template "$TEMPLATE_DIR"/lib/*.template; do
  [ -f "$tmpl" ] || continue
  dest="$TARGET_DIR/$(echo "${tmpl#$TEMPLATE_DIR/}" | sed "s/\.template$//" | sed "s/__ID__/$ID/g")"
  mkdir -p "$(dirname "$dest")"
  sed -e "s/__ID__/$ID/g" -e "s/__NAME__/$NAME/g" -e "s/__DESCRIPTION__/$DESC/g" -e "s/__CLASS__/$CLASS/g" -e "s|__SDK_PATH__|$SDK_PATH|g" "$tmpl" > "$dest"
done

# Create placeholder icon
cp "$TEMPLATE_DIR/assets/logo.png" "$TARGET_DIR/assets/logo.png" 2>/dev/null || touch "$TARGET_DIR/assets/logo.png"

# Copy bundled fonts (Roboto for offline web support)
mkdir -p "$TARGET_DIR/fonts"
cp "$TEMPLATE_DIR/fonts/"*.ttf "$TARGET_DIR/fonts/" 2>/dev/null || true

# Add web platform support
(cd "$TARGET_DIR" && flutter create . --platforms web) > /dev/null 2>&1

echo ""
echo "Extension created at: $TARGET_DIR"
echo ""
echo "Next steps:"
echo "  cd $TARGET_DIR"
echo "  flutter pub get"
echo "  flutter run -d <device>     # standalone preview"
echo "  flutter build web           # web build for host testing"
echo ""
echo "See docs/developer-guide.md for full instructions."
