#!/usr/bin/env bash
# Package circle-x source without build output and development caches.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: package-zip.sh [output.zip]

Creates a source ZIP containing the circle-x/ folder, excluding generated
builds, caches, local IDE settings, logs, and existing ZIP files.

The default output is circle-x-source.zip beside the circle-x/ folder.
A custom output path is relative to your current working directory.
The output directory must already exist. An existing ZIP is replaced only
after the new archive passes its integrity check.

Examples:
  ./scripts/package-zip.sh
  ./scripts/package-zip.sh /tmp/circle-x.zip
EOF
}

die() { printf 'Error: %s\n' "$1" >&2; exit 1; }

if [[ "${1:-}" == '-h' || "${1:-}" == '--help' ]]; then
  usage
  exit 0
fi
[[ $# -le 1 ]] || die 'Expected at most one output path. Use --help for usage.'

for tool in zip unzip; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool is required."
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
EXT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PARENT_DIR="$(dirname -- "$EXT_DIR")"
EXT_NAME="$(basename -- "$EXT_DIR")"
[[ -f "$EXT_DIR/pubspec.yaml" ]] || die "No pubspec.yaml in $EXT_DIR"

OUTPUT="${1:-$PARENT_DIR/circle-x-source.zip}"
[[ "$OUTPUT" == *.zip ]] || die 'Output must end in .zip.'
[[ ! -d "$OUTPUT" ]] || die "Output is a directory: $OUTPUT"
[[ -d "$(dirname -- "$OUTPUT")" ]] || die 'Output directory does not exist.'
OUTPUT_DIR="$(cd -- "$(dirname -- "$OUTPUT")" && pwd)"
OUTPUT="$OUTPUT_DIR/$(basename -- "$OUTPUT")"

# Always create a fresh archive so files removed since the last run cannot linger.
STAGING_DIR="$(mktemp -d "$OUTPUT_DIR/.circle-x-package.XXXXXX")"
trap 'rm -rf -- "$STAGING_DIR"' EXIT

printf 'Packaging %s...\n' "$EXT_NAME"
(
  cd -- "$PARENT_DIR"
  zip -q -r "$STAGING_DIR/source.zip" "$EXT_NAME/" \
    -x '*/build/*' '*/.dart_tool/*' '*/.gradle/*' '*/.cxx/*' \
       '*/.git/*' '*/.idea/*' '*/coverage/*' '*/lattice_edge_build/*' \
       '*/.flutter-plugins-dependencies' '*/local.properties' \
       '*.iml' '*.log' '*/__pycache__/*' '*.pyc' '*.zip' '*.ZIP' \
       '*/.circle-x-package.*/*'
)

unzip -tq "$STAGING_DIR/source.zip"
mv -f -- "$STAGING_DIR/source.zip" "$OUTPUT"
printf 'Created: %s\n' "$OUTPUT"
ls -lh -- "$OUTPUT"
