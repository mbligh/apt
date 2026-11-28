#!/bin/sh
# Build the patched Jellyfin Web 12.4 frontend, not the .NET server.
set -eu
cd "$(dirname "$0")/../.."

# Update this pin and commit a new recipe whenever the source patch changes.
SOURCE_COMMIT=37181a580319b3c4484533b7ba56e40bdd66f43d
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
    npm test -- src/components/images/imageLoader.test.ts src/apps/modern/features/libraries/utils/path.test.ts
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
Season episode listings show air dates, omit estimated end times, and clamp descriptions to six lines.
Backports upstream lazy thumbnail loading fix (#8824).
Library default landing screens honor server-stored preferences.
Scroll wheel volume control during playback is disabled by default, with a per-user opt-in.
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
 Continue Watching, widescreen 16:9 episode thumbnails, original air dates,
 compact season episode descriptions, the upstream thumbnail loading fix,
 server-stored library landing preferences, and opt-in scroll wheel volume control.
 Includes no Node.js or npm runtime dependency.
EOF
# Normalize archive timestamps so rebuilding the pinned source is repeatable.
find "$pkg" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/jellyfin-web_${version}_all.deb"
