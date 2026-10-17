#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
VERSION=2026.08.19.233452
REVISION=1
SHA256=8e851af222deaeeced7a9444a3c961fa054dc850e92d400e3ff73110f7bd9f4d
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fL --retry 3 -o "$tmp/yt-dlp" "https://github.com/bashonly/yt-dlp/releases/download/sabr/yt-dlp"
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
