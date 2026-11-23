#!/bin/sh
# Repackage the official OpenCode v2 standalone CLI; no npm, Node.js or Bun required.
set -eu
umask 022
cd "$(dirname "$0")/../.."
. packages/opencode/version

ARCH=amd64
URL="https://github.com/anomalyco/opencode/releases/download/v${VERSION}/opencode-linux-x64-baseline.tar.gz"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

curl -fLsS --retry 3 --retry-delay 2 -o "$tmp/opencode.tar.gz" "$URL"
printf '%s  %s\n' "$SHA256" "$tmp/opencode.tar.gz" | sha256sum -c -

mkdir -p "$tmp/unpacked"
tar -xzf "$tmp/opencode.tar.gz" -C "$tmp/unpacked" --no-same-owner --no-same-permissions
binary=$(find "$tmp/unpacked" -type f -name opencode -print -quit)
[ -n "$binary" ] && [ -x "$binary" ] || {
    echo "OpenCode archive does not contain an executable opencode binary" >&2
    exit 1
}

pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/bin" "$pkg/usr/share/doc/opencode"
install -m 0755 "$binary" "$pkg/usr/bin/opencode"
install -m 0644 packages/opencode/LICENSE "$pkg/usr/share/doc/opencode/copyright"

cat > "$pkg/DEBIAN/control" <<EOF
Package: opencode
Version: ${VERSION}-${REVISION}
Section: devel
Priority: optional
Architecture: ${ARCH}
Maintainer: mbligh <noreply@github.com>
Depends: libc6 (>= 2.36), libstdc++6, ca-certificates
Homepage: https://opencode.ai
Description: Open-source terminal AI coding agent
 Standalone upstream OpenCode v2 CLI for Linux x86-64 (baseline CPU target).
 Includes its own runtime; does not require installing Node.js, Bun or npm.
EOF

# Fixed timestamps make repeated builds of an unchanged release byte-identical,
# as required by the immutable R2 package store.
find "$pkg" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
mkdir -p dist
SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" dpkg-deb --build --root-owner-group \
    "$pkg" "dist/opencode_${VERSION}-${REVISION}_${ARCH}.deb"
