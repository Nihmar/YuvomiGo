#!/usr/bin/env bash
# Controlli pre-commit (AGENTS.md): format, analisi statica, test.
#
# Uso: ./scripts/check.sh
set -euo pipefail

WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WORKSPACE/app"

echo "==> dart format (check)"
dart format --output=none --set-exit-if-changed lib test

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test

echo "OK: format, analyze e test verdi."
