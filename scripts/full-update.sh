#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/fetch-release.sh" "$@"
"$SCRIPT_DIR/update-openapi.sh"
