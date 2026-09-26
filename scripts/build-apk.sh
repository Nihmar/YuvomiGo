#!/usr/bin/env bash
# Build dell'APK Android di YuvomiGo.
#
# Uso:
#   ./scripts/build-apk.sh                      # debug, universale (tutti gli ABI)
#   ./scripts/build-apk.sh release               # release, universale
#   ./scripts/build-apk.sh debug arm64-v8a       # debug, solo arm64 (più piccolo)
#   ./scripts/build-apk.sh release arm64-v8a x86_64   # release, più ABI
#   ./scripts/build-apk.sh debug --install       # build + install su device adb collegato
#
# Opzioni:
#   <mode>            debug (default) | release
#   <abi>...          opzionale: arm64-v8a, armebi-v7a, x86_64, x86
#   --install         installa su un device adb collegato (richiede adb nel PATH o SDK)
set -euo pipefail

WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$WORKSPACE/app"

MODE="debug"
INSTALL=0
ABIS=()

for arg in "$@"; do
  case "$arg" in
    debug|release) MODE="$arg" ;;
    --install) INSTALL=1 ;;
    arm64-v8a|armeabi-v7a|x86_64|x86) ABIS+=("$arg") ;;
    *) echo "Argomento non valido: $arg" >&2; echo "Uso: $0 [debug|release] [abi...] [--install]" >&2; exit 2 ;;
  esac
done

cd "$APP_DIR"

FLAGS=()
if [[ "$MODE" == "release" ]]; then
  FLAGS+=(--release)
else
  FLAGS+=(--debug)
fi
if [[ ${#ABIS[@]} -gt 0 ]]; then
  FLAGS+=(--target-platform "$(IFS=,; echo "${ABIS[*]}")")
fi

echo "==> flutter build apk ${FLAGS[*]:-<universale>} (mode=$MODE)"
flutter build apk "${FLAGS[@]}"

# Trova l'APK prodotto per la mode corrente (debug → app-debug.apk, release → app-release.apk).
OUT_DIR="build/app/outputs/flutter-apk"
SUFFIX="$MODE"
echo
echo "==> APK:"
find "$OUT_DIR" -name "app-${SUFFIX}*.apk" -exec ls -lh {} \;

if [[ "$INSTALL" -eq 1 ]]; then
  ADB=""
  command -v adb >/dev/null 2>&1 && ADB="adb"
  if [[ -z "$ADB" && -n "${ANDROID_HOME:-}" && -x "$ANDROID_HOME/platform-tools/adb" ]]; then
    ADB="$ANDROID_HOME/platform-tools/adb"
  fi
  if [[ -n "$ADB" ]]; then
    DEVICES="$("$ADB" devices | grep -c 'device$' || true)"
    if [[ "$DEVICES" -ge 1 ]]; then
      APK=$(ls -t "$OUT_DIR"/app-*.apk | head -1)
      echo "==> adb install -r $APK"
      "$ADB" install -r "$APK"
    else
      echo "Nessun device adb collegato: installa manualmente l'APK." >&2
    fi
  else
    echo "adb non trovato: installa manualmente l'APK." >&2
  fi
fi
