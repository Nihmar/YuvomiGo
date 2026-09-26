#!/usr/bin/env bash
set -euo pipefail

REPO="ulsklyc/yuvomi"
WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF_DIR="$WORKSPACE/reference"
TAG="${1:-}"

if [[ -z "$TAG" ]]; then
  TAG=$(gh release view --repo "$REPO" --json tagName -q .tagName)
  echo "Nessun tag specificato, uso l'ultima release: $TAG"
fi

DEST="$REF_DIR/$TAG"

if [[ -f "$DEST/.complete" ]]; then
  echo "Release $TAG già presente in $DEST"
else
  echo "Scarico la release $TAG da $REPO..."
  mkdir -p "$DEST"
  gh release download "$TAG" --repo "$REPO" --archive=zip --dir "$DEST"

  mkdir -p "$DEST/_tmp"
  for f in "$DEST"/*.zip; do
    unzip -q -o "$f" -d "$DEST/_tmp"
  done

  INNER=$(find "$DEST/_tmp" -mindepth 1 -maxdepth 1 -type d | head -1)
  if [[ -n "$INNER" ]]; then
    shopt -s dotglob
    mv "$INNER"/* "$DEST"/
    shopt -u dotglob
  fi

  rm -rf "$DEST/_tmp" "$DEST"/*.zip
  touch "$DEST/.complete"
fi

ln -sfn "$DEST" "$REF_DIR/current"
echo "Release corrente: $TAG"
