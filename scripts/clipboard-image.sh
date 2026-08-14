#!/bin/bash
# clipboard-image.sh — save the image currently in the clipboard to a PNG file.
# Usage: clipboard-image.sh [outputPath]   (default: ./clipboard-image.png)
set -uo pipefail
OUT="${1:-./clipboard-image.png}"
osascript -l JavaScript - "$OUT" <<'JXAEOF'
function run(argv) {
  ObjC.import('AppKit');
  ObjC.import('Foundation');
  const out = argv[0] || 'clipboard-image.png';
  const pb = $.NSPasteboard.generalPasteboard;
  const raw = pb.types ? pb.types.js : [];
  const types = raw.map(function (t) { return (t && t.js !== undefined) ? t.js : String(t); });
  const hasImage = types.some(function (t) { return /png|tiff|jpeg|jpg|image|bitmap/.test(String(t)); });
  if (!hasImage) {
    return 'ERROR: clipboard contains no image (types: ' + types.join(', ') + ')';
  }
  const img = $.NSImage.alloc.initWithPasteboard(pb);
  if (img.isNil()) return 'ERROR: could not read image from clipboard';
  const rep = $.NSBitmapImageRep.imageRepWithData(img.TIFFRepresentation);
  const png = rep.representationUsingTypeProperties($.NSBitmapImageFileTypePNG, $.NSDictionary.dictionary);
  const ok = png.writeToFileAtomically(out, true);
  return ok ? 'saved: ' + out : 'ERROR: write failed: ' + out;
}
JXAEOF
