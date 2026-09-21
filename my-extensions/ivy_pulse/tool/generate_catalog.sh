#!/usr/bin/env bash
# Regenerate the Dart PMCS catalogs from the TM source data in tool/tm_source.
#
# The .mjs files under tool/tm_source are the TM transcriptions with TypeScript
# annotations stripped. Edit those (or re-export them from circle-x), then run
# this script — never hand-edit lib/data/catalog/*.g.dart.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/lib/data/catalog"

command -v node >/dev/null 2>&1 || { echo "node is required" >&2; exit 1; }

node "$ROOT/tool/tm_source/gen-dart.mjs" "$OUT"
command -v dart >/dev/null 2>&1 && dart format "$OUT" >/dev/null
echo "Catalogs regenerated in $OUT"
