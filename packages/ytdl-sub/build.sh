#!/bin/sh
# Repackage the latest stable Linux x86-64 PyInstaller release.
set -eu
umask 022
cd "$(dirname "$0")/../.."

REVISION=$(cat packages/ytdl-sub/revision)
ARCH=amd64
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

# CI passes the exact release resolved by preflight, avoiding a second lookup
# and a race between checking a version and downloading its binary.
if [ -z "${YTDL_SUB_RELEASE:-}" ]; then
    if [ -n "${GH_TOKEN:-}" ]; then
        set -- -H "Authorization: Bearer $GH_TOKEN"
    else
        set --
    fi
    curl -fLsS --retry 3 "$@" \
        https://api.github.com/repos/jmbannon/ytdl-sub/releases/latest \
        -o "$tmp/release.json"
    YTDL_SUB_RELEASE=$(python3 packages/ytdl-sub/release-info < "$tmp/release.json")
fi
read -r VERSION ASSET_ID SHA256 SOURCE_DATE_EPOCH extra <<EOF
$YTDL_SUB_RELEASE
EOF
test -n "$VERSION" && test -n "$ASSET_ID" && test -n "$SHA256" && test -n "$SOURCE_DATE_EPOCH" && test -z "$extra"
export SOURCE_DATE_EPOCH
URL="https://github.com/jmbannon/ytdl-sub/releases/download/$VERSION/ytdl-sub"

# Prefer the public release URL; fall back to the resolved asset ID.
if ! curl -fL --retry 3 -o "$tmp/ytdl-sub" "$URL"; then
    if [ -n "${GH_TOKEN:-}" ]; then
        set -- -H "Authorization: Bearer $GH_TOKEN"
    else
        set --
    fi
    curl -fL --retry 3 "$@" -H 'Accept: application/octet-stream' \
        -o "$tmp/ytdl-sub" \
        "https://api.github.com/repos/jmbannon/ytdl-sub/releases/assets/$ASSET_ID"
fi
printf '%s  %s\n' "$SHA256" "$tmp/ytdl-sub" | sha256sum -c -

pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/bin" "$pkg/usr/lib/ytdl-sub" "$pkg/usr/share/doc/ytdl-sub"
install -m 755 "$tmp/ytdl-sub" "$pkg/usr/lib/ytdl-sub/ytdl-sub"

# The upstream PyInstaller executable may not discover Debian's CA trust store.
# Keep /usr/bin/ytdl-sub as the public entrypoint and respect caller overrides.
cat > "$pkg/usr/bin/ytdl-sub" <<'EOF'
#!/bin/sh
: "${SSL_CERT_FILE:=/etc/ssl/certs/ca-certificates.crt}"
export SSL_CERT_FILE
exec /usr/lib/ytdl-sub/ytdl-sub "$@"
EOF
chmod 755 "$pkg/usr/bin/ytdl-sub"

cat > "$pkg/DEBIAN/control" <<EOF
Package: ytdl-sub
Version: $VERSION-$REVISION
Section: video
Priority: optional
Architecture: $ARCH
Maintainer: mbligh <noreply@github.com>
Depends: libc6 (>= 2.28), ffmpeg, ca-certificates
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

find "$pkg" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/ytdl-sub_${VERSION}-${REVISION}_${ARCH}.deb"
