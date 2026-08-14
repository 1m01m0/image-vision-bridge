#!/bin/bash
# ocr.sh — extract all visible text from an image.
# Usage: ocr.sh <image> [languages]
#   languages: comma separated Vision names, default "zh-Hans,en-US"
# Strategy: macOS Vision (on-device, multilingual) -> tesseract fallback (eng).
set -uo pipefail
IMG="$1"
LANGS="${2:-zh-Hans,en-US}"
DIR="$(cd "$(dirname "$0")" && pwd)"
[ -n "$IMG" ] || { echo "ERROR: usage: ocr.sh <image> [languages]"; exit 2; }
[ -f "$IMG" ] || { echo "ERROR: no such file: $IMG"; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
NORM="$TMP/norm.png"

# Normalize: convert to PNG (HEIC/WebP/GIF/TIFF -> PNG, first frame), cap width.
python3 - "$IMG" "$NORM" <<'PYEOF' 2>/dev/null
import sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src)
im.load()
im = im.convert('RGB')
if im.width > 4096:
    im = im.resize((4096, int(im.height * 4096 / im.width)), Image.LANCZOS)
im.save(dst, 'PNG')
PYEOF
if [ ! -f "$NORM" ] && command -v sips >/dev/null 2>&1; then
  sips -s format png "$IMG" --out "$NORM" >/dev/null 2>&1
fi
if [ ! -f "$NORM" ]; then
  echo "ERROR: cannot normalize image (PIL and sips both failed): $IMG"
  exit 3
fi

# 1) macOS Vision OCR
VOUT="$(osascript -l JavaScript "$DIR/vision-ocr.jxa" "$NORM" "$LANGS" 2>/dev/null)"
VRC=$?
if [ $VRC -eq 0 ] && ! printf '%s' "$VOUT" | grep -q '^ERROR:'; then
  echo "## OCR (macOS Vision, on-device; languages: $LANGS)"
  echo "$VOUT"
  exit 0
fi

# 2) tesseract fallback (only when Vision errored/crashed)
if command -v tesseract >/dev/null 2>&1; then
  TOUT="$(tesseract "$NORM" stdout -l eng 2>/dev/null | sed '/^$/d')"
  if [ -n "$TOUT" ]; then
    echo "## OCR (tesseract fallback, eng; Vision failed: $(printf '%s' "$VOUT" | head -1))"
    echo "$TOUT"
    exit 0
  fi
fi

echo "## OCR: no engine produced text."
echo "Vision result was: $VOUT"
exit 1
