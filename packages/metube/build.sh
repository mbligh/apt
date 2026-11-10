#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
VERSION=2026.10.18
REVISION=1
# Pin upstream to a commit. Set this only after verifying the current source.
UPSTREAM_COMMIT=f02f2ac0252563df13286cd1643fac9ca1bc08d9
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
# --target installs pure Python modules and native extensions at their final
# import path without a non-relocatable virtualenv.
python3 -m pip install --no-cache-dir --target "$pkg/usr/lib/metube/python" \
  -r packages/metube/requirements.txt
# yt-dlp comes exclusively from the separately packaged zipapp.
test ! -e "$pkg/usr/lib/metube/python/yt_dlp"
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
Depends: python3 (>= 3.13), python3 (<< 3.14), yt-dlp-sabr, ffmpeg, deno, ca-certificates
Description: MeTube downloader web UI as a native systemd service
 MeTube with Python dependencies and Angular frontend, without Docker.
EOF
cp "$tmp/source/LICENSE" "$pkg/usr/share/doc/metube/copyright"
install -m 755 packages/metube/postinst "$pkg/DEBIAN/postinst"
install -m 755 packages/metube/postrm "$pkg/DEBIAN/postrm"
mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/metube_${VERSION}-${REVISION}_amd64.deb"
