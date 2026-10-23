#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/lib/data/catalog"

command -v node >/dev/null 2>&1 || { echo "node is required" >&2; exit 1; }

node "$ROOT/tool/tm_source/gen-dart.mjs" "$ROOT/lib"
if command -v dart >/dev/null 2>&1; then
  dart format "$OUT" "$ROOT/lib/domain/entities/vehicle_type.g.dart" >/dev/null
fi
echo "Catalogs regenerated in $OUT"
