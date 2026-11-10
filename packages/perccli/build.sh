#!/bin/sh
# Import the original Dell PERCCLI Debian package from our pinned GitHub release.
set -eu
cd "$(dirname "$0")/../.."

VERSION=007.1623.0000.0000
FILENAME=perccli_${VERSION}_all.deb
URL=https://github.com/mbligh/apt/releases/download/perccli-7.1623/$FILENAME
SHA256=e46d955241c932023caf63862cd9dacb2b723b7f944340efb0e5afb6a2681e9d

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
curl -fL --retry 3 -o "$tmp/$FILENAME" "$URL"
echo "$SHA256  $tmp/$FILENAME" | sha256sum -c -

package=$(dpkg-deb -f "$tmp/$FILENAME" Package)
version=$(dpkg-deb -f "$tmp/$FILENAME" Version)
arch=$(dpkg-deb -f "$tmp/$FILENAME" Architecture)
[ "$package" = perccli ] || { echo "Unexpected package: $package" >&2; exit 1; }
[ "$version" = "$VERSION" ] || { echo "Unexpected version: $version" >&2; exit 1; }
[ "$arch" = all ] || { echo "Unexpected architecture: $arch" >&2; exit 1; }

mkdir -p dist
cp "$tmp/$FILENAME" "dist/$FILENAME"
