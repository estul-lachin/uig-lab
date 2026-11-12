#!/usr/bin/env bash
# Render the showcase's image assets from their sources in tools/assets/ (macOS: Google Chrome + sips).
# Run by hand after editing favicon.svg or og-image.html; the rendered files are committed, so the
# site build and CI never need Chrome.
#   og-image.html -> og-image.png (1200x630 link preview)
#   favicon.svg   -> apple-touch-icon.png (180x180) and favicon.ico (32x32)
set -euo pipefail

cd "$(dirname "$0")/assets"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$chrome" ] || { echo "Google Chrome is required" >&2; exit 1; }
command -v sips >/dev/null || { echo "sips (macOS) is required" >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

shot() {  # shot <html file> <width> <height> <out.png>
  local src=$1
  [[ $src == /* ]] || src=$PWD/$src
  "$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --virtual-time-budget=2000 --window-size="$2,$3" --screenshot="$4" "file://$src" >/dev/null 2>&1
}

shot og-image.html 1200 630 og-image.png

# Chrome won't make a window narrower than about 500px, so render the icon in the middle of the page
# and crop it (sips crops around the center). The SVG is inlined: an <img> may not have loaded yet.
{
  printf '<html><body style="margin:0;height:600px;background:#0a0f0b;display:flex;align-items:center;justify-content:center">'
  printf '<div style="width:180px;height:180px">'
  sed 's/<svg /<svg width="180" height="180" /' favicon.svg
  printf '</div></body></html>'
} >"$tmp/icon.html"
shot "$tmp/icon.html" 600 600 "$tmp/icon-600.png"
sips -c 180 180 "$tmp/icon-600.png" --out apple-touch-icon.png >/dev/null
sips -z 32 32 apple-touch-icon.png --out "$tmp/icon-32.png" >/dev/null

# favicon.ico: a one-image ICO that wraps the 32x32 PNG (allowed since Windows Vista, read by all browsers).
python3 - "$tmp/icon-32.png" favicon.ico <<'EOF'
import struct, sys
png = open(sys.argv[1], "rb").read()
header = struct.pack("<HHH", 0, 1, 1)
entry = struct.pack("<BBBBHHII", 32, 32, 0, 0, 1, 32, len(png), 6 + 16)
open(sys.argv[2], "wb").write(header + entry + png)
EOF

for f in og-image.png apple-touch-icon.png favicon.ico; do
  printf '%-22s %s bytes\n' "$f" "$(wc -c <"$f" | tr -d ' ')"
done
