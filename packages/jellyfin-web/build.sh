#!/bin/sh
# Build the patched Jellyfin Web 12.4 frontend, not the .NET server.
set -eu
cd "$(dirname "$0")/../.."

# Update this pin and commit a new recipe whenever the source patch changes.
SOURCE_COMMIT=a54e7faaa586ef2d709ee4a170e7e38f6bb87e97
SOURCE_REPO=https://github.com/mbligh/jellyfin-web.git
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

git init -q "$tmp/source"
git -C "$tmp/source" remote add origin "$SOURCE_REPO"
git -C "$tmp/source" fetch --depth 1 origin "$SOURCE_COMMIT"
git -C "$tmp/source" -c advice.detachedHead=false checkout --detach FETCH_HEAD
test "$(git -C "$tmp/source" rev-parse HEAD)" = "$SOURCE_COMMIT"

# Keep the Debian version greater than upstream 12.4+deb13 but below 12.5.
# A new patch commit gets a new version without overwriting R2 objects.
SOURCE_DATE_EPOCH="$(git -C "$tmp/source" show -s --format=%ct HEAD)"
export SOURCE_DATE_EPOCH
stamp="$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y%m%d%H%M%S)"
short="$(printf '%s' "$SOURCE_COMMIT" | cut -c1-12)"
version="12.4+deb13+mbligh${stamp}.git${short}"
echo "Building jellyfin-web $version from $SOURCE_COMMIT"

(
    cd "$tmp/source"
    CI=true npm ci --no-audit --no-fund
    npm run build:check
    npm run build:production
)
test -s "$tmp/source/dist/index.html"
test -s "$tmp/source/dist/config.json"
test -s "$tmp/source/dist/serviceworker.js"

pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/share/jellyfin/web" "$pkg/usr/share/doc/jellyfin-web"
cp -a "$tmp/source/dist/." "$pkg/usr/share/jellyfin/web/"
install -m 644 "$tmp/source/LICENSE" "$pkg/usr/share/doc/jellyfin-web/copyright"
cat > "$pkg/usr/share/doc/jellyfin-web/README.mbligh" <<EOF
Jellyfin Web 12.4 from https://github.com/mbligh/jellyfin-web
Git revision: $SOURCE_COMMIT
Patch branch: mbligh-v12.4
Shows series/movie posters in portrait Next Up and Continue Watching cards by default.
Season episode thumbnails are widescreen 16:9.
No runtime Node.js/npm dependency.
EOF
# Preserve existing admin edits to the upstream-configured conffile.
printf '%s\n' '/usr/share/jellyfin/web/config.json' > "$pkg/DEBIAN/conffiles"
cat > "$pkg/DEBIAN/control" <<EOF
Package: jellyfin-web
Version: $version
Section: video
Priority: optional
Architecture: all
Maintainer: mbligh <noreply@github.com>
Recommends: jellyfin-server
Homepage: https://github.com/mbligh/jellyfin-web
Description: Jellyfin Web client (mbligh poster and episode-image patches)
 Jellyfin 12.4 frontend with portrait series/movie art in Next Up and
 Continue Watching, plus widescreen 16:9 episode thumbnails.
 Includes no Node.js or npm runtime dependency.
EOF
# Normalize archive timestamps so rebuilding the pinned source is repeatable.
find "$pkg" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/jellyfin-web_${version}_all.deb"
