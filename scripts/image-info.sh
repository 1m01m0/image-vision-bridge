#!/bin/bash
# image-info.sh — metadata, dimensions, format, and dominant colors.
# Usage: image-info.sh <image>
set -uo pipefail
IMG="$1"
[ -f "$IMG" ] || { echo "ERROR: no such file: $IMG"; exit 2; }

echo "## Image info: $IMG"
SIZE=$(ls -lh "$IMG" | awk '{print $5}')
echo "  file size: $SIZE"
if command -v sips >/dev/null 2>&1; then
  sips -g format -g pixelWidth -g pixelHeight -g dpiWidth -g dpiHeight -g space -g hasAlpha "$IMG" 2>/dev/null \
    | grep -E '^  (format|pixelWidth|pixelHeight|dpiWidth|dpiHeight|space|hasAlpha):'
fi

python3 - "$IMG" <<'PYEOF'
import sys
from PIL import Image
path = sys.argv[1]
try:
    im = Image.open(path)
    im.load()
    small = im.convert('RGB')
    small.thumbnail((160, 160))
    q = small.quantize(colors=5, method=2)
    pal = q.getpalette() or []
    counts = sorted(q.getcolors() or [], reverse=True)
    total = sum(c for c, _ in counts) or 1
    print('  dominant colors:')
    for c, idx in counts[:5]:
        r, g, b = pal[idx * 3:idx * 3 + 3]
        print('    #%02x%02x%02x  (r=%d,g=%d,b=%d)  ~%d%%' % (r, g, b, r, g, b, round(c / total * 100)))
    g = im.convert('L')
    g.thumbnail((100, 100))
    px = list(g.getdata())
    avg = sum(px) // max(len(px), 1)
    print('  average brightness: %d/255 (%s)' % (avg, 'dark' if avg < 85 else 'light'))
except Exception as e:
    print('  (color analysis skipped: %s)' % e)
PYEOF
