#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
VERSION=2026.10.18
REVISION=1
# Pin upstream to a commit. Set this only after verifying the current source.
UPSTREAM_COMMIT="${METUBE_UPSTREAM_COMMIT:-}"
test -n "$UPSTREAM_COMMIT" || { echo "Set METUBE_UPSTREAM_COMMIT to a vetted 40-character commit SHA" >&2; exit 1; }
case "$UPSTREAM_COMMIT" in *[!0123456789abcdef]*|'') echo "Invalid commit SHA" >&2; exit 1;; esac
test "${#UPSTREAM_COMMIT}" -eq 40 || exit 1
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fL --retry 3 -o "$tmp/metube.tar.gz" "https://github.com/alexta69/metube/archive/${UPSTREAM_COMMIT}.tar.gz"
mkdir -p "$tmp/source"
tar -xzf "$tmp/metube.tar.gz" -C "$tmp/source" --strip-components=1
pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/lib/metube" "$pkg/etc/metube" "$pkg/usr/lib/systemd/system" "$pkg/usr/share/doc/metube"
cp -a "$tmp/source/app" "$pkg/usr/lib/metube/"
# Build the frontend; do not ship node_modules.
( cd "$tmp/source/ui"
  corepack enable
  corepack prepare pnpm@12.6.0 --activate
  CI=true pnpm install --frozen-lockfile
  pnpm run build
)
mkdir -p "$pkg/usr/lib/metube/ui/dist"
cp -a "$tmp/source/ui/dist/metube" "$pkg/usr/lib/metube/ui/dist/"
# Use the host Debian 13 Python version and build private dependencies.
python3 -m venv "$pkg/usr/lib/metube/venv"
"$pkg/usr/lib/metube/venv/bin/pip" install --no-cache-dir aiohttp python-socketio mutagen curl-cffi watchfiles
# Remove pip's standalone yt-dlp if transitively installed; the packaged zipapp wins.
"$pkg/usr/lib/metube/venv/bin/pip" uninstall -y yt-dlp >/dev/null 2>&1 || true
find "$pkg/usr/lib/metube" -type d -name __pycache__ -prune -exec rm -rf {} +
install -m 644 packages/metube/metube.conf "$pkg/etc/metube/metube.conf"
install -m 644 packages/metube/ytdl-options.json "$pkg/etc/metube/ytdl-options.json"
install -m 644 packages/metube/metube.service "$pkg/usr/lib/systemd/system/metube.service"
cat > "$pkg/DEBIAN/conffiles" <<'EOF'
/etc/metube/metube.conf
/etc/metube/ytdl-options.json
EOF
cat > "$pkg/DEBIAN/control" <<EOF
Package: metube
Version: ${VERSION}-${REVISION}
Section: video
Priority: optional
Architecture: amd64
Maintainer: mbligh <noreply@github.com>
Depends: python3 (>= 3.13), yt-dlp-sabr, ffmpeg, deno, adduser, ca-certificates
Description: MeTube downloader web UI as a native systemd service
 MeTube with Python dependencies and Angular frontend, without Docker.
EOF
cp "$tmp/source/LICENSE" "$pkg/usr/share/doc/metube/copyright"
mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/metube_${VERSION}-${REVISION}_amd64.deb"
