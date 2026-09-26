#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$WORKSPACE/app"

# Carica .env se presente
if [[ -f "$WORKSPACE/scripts/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$WORKSPACE/scripts/.env"
  set +a
fi

YUVOMI_URL="${YUVOMI_URL:-http://omvnas:4000}"
YUVOMI_TOKEN="${YUVOMI_TOKEN:-}"
OPENAPI_PATH="${OPENAPI_PATH:-/api/v1/openapi.json}"

if [[ -z "$YUVOMI_TOKEN" ]]; then
  echo "Errore: YUVOMI_TOKEN non impostato." >&2
  exit 1
fi

OUT="$APP_DIR/api/openapi.json"
SANITIZED="$APP_DIR/api/openapi.sanitized.json"
mkdir -p "$APP_DIR/api"

echo "→ $YUVOMI_URL$OPENAPI_PATH"
HTTP_CODE=$(curl -sS -o "$OUT" -w "%{http_code}" \
  -H "Authorization: Bearer $YUVOMI_TOKEN" \
  "$YUVOMI_URL$OPENAPI_PATH")

case "$HTTP_CODE" in
  200) ;;
  401) echo "401: token mancante o non valido." >&2; exit 1 ;;
  403) echo "403: l'utente/token non è admin." >&2; exit 1 ;;
  *)   echo "Errore HTTP $HTTP_CODE" >&2; head -c 300 "$OUT" >&2; exit 1 ;;
esac

if ! grep -q '"openapi"' "$OUT"; then
  echo "Il file non sembra OpenAPI." >&2
  exit 1
fi

# Salva la versione dell'app per riferimento (parse JSON robusto)
VERSION=$(python3 -c "import json; print(json.load(open('$OUT'))['info']['version'])")
echo "OK: v$VERSION → $OUT ($(wc -c < "$OUT") bytes)"
echo "$VERSION" > "$APP_DIR/api/.yuvomi-version"

# Prep: aggiunge operationId ai path con punti (il generatore non li
# gestisce); la spec sorgente resta intatta.
python3 "$WORKSPACE/scripts/prep_spec.py" "$OUT" "$SANITIZED"

cd "$APP_DIR"
# --delete-conflicting-outputs: se un model sparisce dalla spec, il file
# generato vecchio non deve restare appeso.
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
echo "Client rigenerato, analyze pulito e test passati."
