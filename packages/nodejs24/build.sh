#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."

VERSION=24.22.2
REVISION=1
ARCH=amd64
UPSTREAM="node-v${VERSION}-linux-x64"
# SHA-256 from the Node.js release team's signed SHASUMS256 list.
SHA256=48cc0e21e048790e54c0cf5749c2725005313d652651c40b7a21feb9697aaf75
URL="https://nodejs.org/dist/v${VERSION}/${UPSTREAM}.tar.xz"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fL --retry 3 -o "$tmp/node.tar.xz" "$URL"
echo "$SHA256  $tmp/node.tar.xz" | sha256sum -c -
tar -xJf "$tmp/node.tar.xz" -C "$tmp" "$UPSTREAM/bin/node" "$UPSTREAM/LICENSE"

pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/lib/nodejs24/bin" "$pkg/usr/bin" "$pkg/usr/share/doc/nodejs24"
install -m 755 "$tmp/$UPSTREAM/bin/node" "$pkg/usr/lib/nodejs24/bin/node"
ln -s ../lib/nodejs24/bin/node "$pkg/usr/bin/node24"
install -m 644 "$tmp/$UPSTREAM/LICENSE" "$pkg/usr/share/doc/nodejs24/copyright"

cat > "$pkg/DEBIAN/control" <<EOF
Package: nodejs24
Version: ${VERSION}-${REVISION}
Section: interpreters
Priority: optional
Architecture: ${ARCH}
Maintainer: mbligh <noreply@github.com>
Depends: libc6 (>= 2.36), libstdc++6, libgcc-s1
Description: Node.js 24 LTS runtime (parallel, no npm)
 Official upstream Linux x86-64 Node.js binary, installed as /usr/bin/node24.
 Does not replace Debian's /usr/bin/node or install npm/npx.
EOF

mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/nodejs24_${VERSION}-${REVISION}_${ARCH}.deb"
