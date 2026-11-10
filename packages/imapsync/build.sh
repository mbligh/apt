#!/bin/sh
# Import the upstream imapsync Debian package into the signed mbligh archive.
set -eu
cd "$(dirname "$0")/../.."

VERSION=2.314
URL="https://imapsync.lamiral.info/dist2/old_releases/${VERSION}/imapsync-${VERSION}.deb"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
  -o "$tmp/imapsync.deb" "$URL"

package="$(dpkg-deb -f "$tmp/imapsync.deb" Package)"
version="$(dpkg-deb -f "$tmp/imapsync.deb" Version)"
arch="$(dpkg-deb -f "$tmp/imapsync.deb" Architecture)"
[ "$package" = imapsync ] || { echo "Unexpected package: $package" >&2; exit 1; }
case "$version" in
  "$VERSION"|"$VERSION"-*) ;;
  *) echo "Unexpected version: $version" >&2; exit 1 ;;
esac
case "$arch" in
  all|amd64) ;;
  *) echo "Unexpected architecture: $arch" >&2; exit 1 ;;
esac

mkdir -p dist
cp "$tmp/imapsync.deb" "dist/imapsync_${version}_${arch}.deb"
