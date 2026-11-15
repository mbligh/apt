#!/bin/sh
# Package the complete upstream go-pmtiles CLI (all pmtiles subcommands).
set -eu
cd "$(dirname "$0")/../.."

VERSION=1.31.2
REVISION=1
ARCH=amd64
SHA256=3ed7dbf4ec2e6dfe5e25b6f70d1ffc932729f93c86db353bf514dd71010a312f
URL="https://github.com/protomaps/go-pmtiles/releases/download/v${VERSION}/go-pmtiles_${VERSION}_Linux_x86_64.tar.gz"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
curl -fL --retry 3 -o "$tmp/pmtiles.tar.gz" "$URL"
echo "$SHA256  $tmp/pmtiles.tar.gz" | sha256sum -c -

mkdir -p "$tmp/unpacked"
tar -xzf "$tmp/pmtiles.tar.gz" -C "$tmp/unpacked"
binary=$(find "$tmp/unpacked" -type f -name pmtiles -print -quit)
[ -n "$binary" ] || { echo "Upstream archive has no pmtiles executable" >&2; exit 1; }

pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/bin" "$pkg/usr/share/doc/pmtiles"
install -m 755 "$binary" "$pkg/usr/bin/pmtiles"
cat > "$pkg/DEBIAN/control" <<EOF
Package: pmtiles
Version: ${VERSION}-${REVISION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Maintainer: mbligh <noreply@github.com>
Description: PMTiles command-line utility
 Official go-pmtiles CLI, including its archive inspection, extract,
 convert, serve, verify and other subcommands.
EOF
cat > "$pkg/usr/share/doc/pmtiles/copyright" <<EOF
Source: https://github.com/protomaps/go-pmtiles
License: BSD-3-Clause
See upstream repository for full copyright and license notices.
EOF
mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/pmtiles_${VERSION}-${REVISION}_${ARCH}.deb"
