#!/bin/sh
# Repackage the upstream Linux x86-64 PyInstaller release, with a pinned digest.
set -eu
cd "$(dirname "$0")/../.."

VERSION=2026.11.10.post2
REVISION=1
ARCH=amd64
SHA256=032bf52d19770779f575f00950c8f1082f5b51e64e3e31f3158b33b25bebfbbb
URL="https://github.com/jmbannon/ytdl-sub/releases/download/$VERSION/ytdl-sub"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
curl -fL --retry 3 -o "$tmp/ytdl-sub" "$URL"
printf '%s  %s\n' "$SHA256" "$tmp/ytdl-sub" | sha256sum -c -

pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/bin" "$pkg/usr/share/doc/ytdl-sub"
install -m 755 "$tmp/ytdl-sub" "$pkg/usr/bin/ytdl-sub"

cat > "$pkg/DEBIAN/control" <<EOF
Package: ytdl-sub
Version: $VERSION-$REVISION
Section: video
Priority: optional
Architecture: $ARCH
Maintainer: mbligh <noreply@github.com>
Depends: libc6 (>= 2.28), ffmpeg
Recommends: deno
Description: yt-dlp subscription downloader and metadata generator
 Automates media downloading, organization and metadata generation for
 media libraries such as Plex, Jellyfin, Emby and Kodi.
 This package installs the upstream self-contained Linux x86-64 executable.
EOF

cat > "$pkg/usr/share/doc/ytdl-sub/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: ytdl-sub
Source: https://github.com/jmbannon/ytdl-sub/tree/$VERSION

Files: *
Copyright: Jesse Bannon and ytdl-sub contributors
License: GPL-3
 On Debian systems the full GPL-3 license is available in
 /usr/share/common-licenses/GPL-3.
EOF

mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/ytdl-sub_$VERSION-$REVISION_$ARCH.deb"
