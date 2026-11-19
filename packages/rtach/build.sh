#!/bin/sh
# Build rtach from pinned upstream source using Zig 0.16.0.
set -eu
cd "$(dirname "$0")/../.."

VERSION=0.2.0
REVISION=2
ARCH=amd64
SOURCE_COMMIT=372fefbaa051e240f3923bad480294a4f65718b7
ZIG_VERSION=0.16.0
ZIG_SHA256=70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00

echo "Building rtach ${VERSION}-${REVISION} from upstream commit $SOURCE_COMMIT"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

curl -fLsS --retry 3 -o "$tmp/zig.tar.xz" \
    "https://ziglang.org/download/$ZIG_VERSION/zig-x86_64-linux-$ZIG_VERSION.tar.xz"
printf '%s  %s\n' "$ZIG_SHA256" "$tmp/zig.tar.xz" | sha256sum -c -
mkdir -p "$tmp/zig"
tar -xf "$tmp/zig.tar.xz" -C "$tmp/zig" --strip-components=1

curl -fLsS --retry 3 -o "$tmp/rtach.tar.gz" \
    "https://github.com/eriklangille/rtach/archive/$SOURCE_COMMIT.tar.gz"
mkdir -p "$tmp/src"
tar -xf "$tmp/rtach.tar.gz" -C "$tmp/src" --strip-components=1
patch -d "$tmp/src" -p1 --batch --forward < packages/rtach/pass-command-arguments.patch

(
    cd "$tmp/src"
    "$tmp/zig/zig" build -Doptimize=ReleaseFast --global-cache-dir "$tmp/zig-cache"
    "$tmp/zig/zig" build test --global-cache-dir "$tmp/zig-cache"
    test -x zig-out/bin/rtach
    zig-out/bin/rtach --version
)

sh packages/rtach/test-command-arguments.sh "$tmp/src/zig-out/bin/rtach"

pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/bin" "$pkg/usr/share/doc/rtach"
install -m 0755 "$tmp/src/zig-out/bin/rtach" "$pkg/usr/bin/rtach"

cat > "$pkg/DEBIAN/control" <<EOF
Package: rtach
Version: ${VERSION}-${REVISION}
Section: utils
Priority: optional
Architecture: $ARCH
Maintainer: mbligh <noreply@github.com>
Depends: libc6
Description: Persistent terminal sessions with output replay
 Keeps programs running across terminal disconnections and replays recent
 terminal output when a client reattaches.
EOF

cat > "$pkg/usr/share/doc/rtach/copyright" <<EOF
Upstream source: https://github.com/eriklangille/rtach
Source commit: $SOURCE_COMMIT
Review upstream licensing before redistribution.
EOF

mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/rtach_${VERSION}-${REVISION}_${ARCH}.deb"
