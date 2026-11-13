#!/usr/bin/env bash
# Скачивает компилятор C3 нужной версии в ./.c3c (раннер c3lings подхватит его сам).
set -euo pipefail
VERSION="${1:-v0.8.5_1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "$(uname -s)" in
    Linux)  ASSET="c3-linux.tar.gz" ;;
    Darwin) ASSET="c3-macos.zip" ;;
    *) echo "Скачайте компилятор вручную: https://github.com/c3lang/c3c/releases/tag/$VERSION"; exit 1 ;;
esac
URL="https://github.com/c3lang/c3c/releases/download/$VERSION/$ASSET"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Скачиваю $URL"
curl -fL -o "$TMP/$ASSET" "$URL"
rm -rf "$ROOT/.c3c"; mkdir -p "$ROOT/.c3c"
case "$ASSET" in
    *.tar.gz) tar xzf "$TMP/$ASSET" -C "$ROOT/.c3c" ;;
    *.zip)    unzip -q "$TMP/$ASSET" -d "$ROOT/.c3c" ;;
esac
C3C="$(find "$ROOT/.c3c" -name c3c -type f | head -1)"
chmod +x "$C3C"
"$C3C" --version | head -1
echo "Готово: $C3C"
