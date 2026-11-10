#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
VERSION=2.9.7
REVISION=1
ARCH=amd64
SHA256=c6527f24f4b16031d3ae4fa9f658d5f11534c8d84ce7dc8502420280919c3490
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fL --retry 3 -o "$tmp/deno.zip" "https://github.com/denoland/deno/releases/download/v${VERSION}/deno-x86_64-unknown-linux-gnu.zip"
echo "$SHA256  $tmp/deno.zip" | sha256sum -c -
unzip -q "$tmp/deno.zip" -d "$tmp/extracted"
pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/bin" "$pkg/usr/share/doc/deno"
install -m 755 "$tmp/extracted/deno" "$pkg/usr/bin/deno"
cat > "$pkg/DEBIAN/control" <<EOF
Package: deno
Version: ${VERSION}-${REVISION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Maintainer: mbligh <noreply@github.com>
Depends: libc6
Description: Deno JavaScript and TypeScript runtime
 Official Deno Linux x86-64 binary, repackaged for local APT use.
EOF
echo 'Deno is distributed under the MIT license; see https://github.com/denoland/deno/blob/main/LICENSE.md' > "$pkg/usr/share/doc/deno/copyright"
mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/deno_${VERSION}-${REVISION}_${ARCH}.deb"
