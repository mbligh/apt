#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
APP="$(basename "$(dirname "$0")")"
case "$APP" in
 radarr) NAME=Radarr; URL='https://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64';;
 sonarr) NAME=Sonarr; URL='https://services.sonarr.tv/v1/download/main/latest?version=4&os=linux&arch=x64';;
 *) exit 1;;
esac
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fL --retry 3 "$URL" -o "$tmp/upstream.tar.gz"
mkdir "$tmp/extracted"
tar -xzf "$tmp/upstream.tar.gz" -C "$tmp/extracted"
test -x "$tmp/extracted/$NAME/$NAME"
VERSION="$(find "$tmp/extracted/$NAME" -maxdepth 1 -name '*.dll' | head -1 >/dev/null; tar -tzf "$tmp/upstream.tar.gz" | head -1 >/dev/null; echo "${PACKAGE_VERSION:-}")"
test -n "$VERSION" || { echo 'Set PACKAGE_VERSION to the verified upstream version (e.g. 4.0.0)' >&2; exit 1; }
case "$VERSION" in *[!0-9.a-zA-Z+~:-]*|'') echo 'Invalid version' >&2; exit 1;; esac
pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/lib/$APP" "$pkg/lib/systemd/system" "$pkg/usr/share/doc/$APP"
cp -a "$tmp/extracted/$NAME/." "$pkg/usr/lib/$APP/"
cat > "$pkg/lib/systemd/system/$APP.service" <<EOF
[Unit]
Description=$NAME media manager
After=network.target
[Service]
Type=simple
User=$APP
Group=media
UMask=0002
ExecStart=/usr/lib/$APP/$NAME -nobrowser -data=/var/lib/$APP
Restart=on-failure
TimeoutStopSec=20
[Install]
WantedBy=multi-user.target
EOF
cat > "$pkg/DEBIAN/control" <<EOF
Package: $APP
Version: ${VERSION}-1
Section: video
Priority: optional
Architecture: amd64
Maintainer: mbligh <noreply@github.com>
Depends: adduser, libc6, libsqlite3-0, libicu72 | libicu76, libssl3 | libssl3t64
Description: $NAME media management daemon
 Repackaged upstream stable Linux build.
EOF
cat > "$pkg/DEBIAN/postinst" <<EOF
#!/bin/sh
set -e
if [ "\$1" = configure ]; then
  getent group media >/dev/null || addgroup --system media
  id $APP >/dev/null 2>&1 || adduser --system --home /var/lib/$APP --no-create-home --ingroup media $APP
  install -d -o $APP -g media -m 2775 /var/lib/$APP
fi
#DEBHELPER#
EOF
chmod 755 "$pkg/DEBIAN/postinst"
cat > "$pkg/DEBIAN/prerm" <<EOF
#!/bin/sh
set -e
if [ "\$1" = remove ] || [ "\$1" = deconfigure ]; then
 systemctl stop $APP.service 2>/dev/null || true
fi
EOF
chmod 755 "$pkg/DEBIAN/prerm"
echo "Upstream: $URL; consult upstream repository for license and notices." > "$pkg/usr/share/doc/$APP/copyright"
mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/${APP}_${VERSION}-1_amd64.deb"
