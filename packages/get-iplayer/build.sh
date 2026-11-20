#!/bin/sh
# Import the pinned openSUSE Build Service Debian 13 get-iplayer package unchanged.
set -eu
cd "$(dirname "$0")/../.."

VERSION='3.36-1+deb13u3'
ARCH=all
FILENAME="get-iplayer_${VERSION}_${ARCH}.deb"
URL="https://download.opensuse.org/repositories/home:/m-grant-prg/Debian_13/all/$FILENAME"
# Published by download.opensuse.org in the .deb.mirrorlist file.
SHA256=35e7c205cdf0b2dd0d9b1b6affbda67596a9a014660301b56197393c85b8e2bf

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
  -o "$tmp/$FILENAME" "$URL"
printf '%s  %s\n' "$SHA256" "$tmp/$FILENAME" | sha256sum -c -

package=$(dpkg-deb -f "$tmp/$FILENAME" Package)
version=$(dpkg-deb -f "$tmp/$FILENAME" Version)
arch=$(dpkg-deb -f "$tmp/$FILENAME" Architecture)
[ "$package" = get-iplayer ] || { echo "Unexpected package: $package" >&2; exit 1; }
[ "$version" = "$VERSION" ] || { echo "Unexpected version: $version" >&2; exit 1; }
[ "$arch" = "$ARCH" ] || { echo "Unexpected architecture: $arch" >&2; exit 1; }
dpkg-deb --contents "$tmp/$FILENAME" >/dev/null

mkdir -p dist
cp "$tmp/$FILENAME" "dist/$FILENAME"
