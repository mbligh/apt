#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
REVISION=1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# Resolve the current moving release once, then download its immutable asset IDs.
# The API supplies both the release timestamp and the asset SHA-256 digest.
release=$(curl -fsSL --retry 3 https://api.github.com/repos/bashonly/yt-dlp/releases/tags/sabr)
printf '%s' "$release" > "$tmp/release.json"
python3 - "$tmp/release.json" "$tmp/release-info" <<'PY'
import json, re, sys
from datetime import datetime, timezone
r = json.load(open(sys.argv[1]))
a = next(a for a in r['assets'] if a['name'] == 'yt-dlp')
digest = a.get('digest', '')
if not re.fullmatch(r'sha256:[0-9a-f]{64}', digest):
    raise SystemExit('Release asset lacks a valid SHA-256 digest')
version = datetime.fromisoformat(r['published_at'].replace('Z', '+00:00')).astimezone(timezone.utc).strftime('%Y.%m.%d.%H%M%S')
with open(sys.argv[2], 'w') as out:
    out.write(f"{version}\\n{a['id']}\\n{digest[7:]}\\n")
PY
VERSION=$(sed -n '1p' "$tmp/release-info")
ASSET_ID=$(sed -n '2p' "$tmp/release-info")
SHA256=$(sed -n '3p' "$tmp/release-info")
curl -fL --retry 3 -o "$tmp/yt-dlp" \
  "https://github.com/bashonly/yt-dlp/releases/download/sabr/yt-dlp"
echo "$SHA256  $tmp/yt-dlp" | sha256sum -c -
pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/bin" "$pkg/etc" "$pkg/usr/share/doc/yt-dlp-sabr"
install -m 755 "$tmp/yt-dlp" "$pkg/usr/bin/yt-dlp"
install -m 644 packages/yt-dlp-sabr/yt-dlp.conf "$pkg/etc/yt-dlp.conf"
cat > "$pkg/DEBIAN/control" <<EOF
Package: yt-dlp-sabr
Version: ${VERSION}-${REVISION}
Section: video
Priority: optional
Architecture: all
Maintainer: mbligh <noreply@github.com>
Depends: python3, deno, ffmpeg
Provides: yt-dlp
Conflicts: yt-dlp
Replaces: yt-dlp
Description: yt-dlp with bashonly SABR support and local defaults
 Python zipapp from bashonly/yt-dlp@sabr; executable is /usr/bin/yt-dlp.
EOF
printf '/etc/yt-dlp.conf\n' > "$pkg/DEBIAN/conffiles"
echo 'yt-dlp is distributed under the Unlicense; see https://github.com/bashonly/yt-dlp/blob/sabr/LICENSE' > "$pkg/usr/share/doc/yt-dlp-sabr/copyright"
mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/yt-dlp-sabr_${VERSION}-${REVISION}_all.deb"
