#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
VERSION=6.4.4.10685
REVISION=1
URL='https://github.com/Radarr/Radarr/releases/download/v6.4.4.10685/Radarr.master.6.4.4.10685.linux-core-x64.tar.gz'
SHA256=a1d726129535e739d4efaf93b5fdd771bb1c78349f55ceac70e365e37b5a12a3
APP=radarr
NAME=Radarr
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fL --retry 3 "$URL" -o "$tmp/upstream.tar.gz"
echo "$SHA256  $tmp/upstream.tar.gz" | sha256sum -c -
mkdir "$tmp/extracted"
tar -xzf "$tmp/upstream.tar.gz" -C "$tmp/extracted"
test -f "$tmp/extracted/$NAME/$NAME"
pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/lib/$APP" "$pkg/lib/systemd/system" "$pkg/usr/share/doc/$APP"
cp -a "$tmp/extracted/$NAME/." "$pkg/usr/lib/$APP/"
chmod 755 "$pkg/usr/lib/$APP/$NAME"
cat > "$pkg/lib/systemd/system/$APP.service" <<EOF
[Unit]
Description=$NAME media manager
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$APP
Group=media
UMask=0002
ExecStart=/usr/lib/$APP/$NAME -nobrowser -data=/var/lib/$APP
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
NoNewPrivileges=true
ProtectSystem=full
ReadWritePaths=/var/lib/$APP

[Install]
WantedBy=multi-user.target
EOF
cat > "$pkg/DEBIAN/control" <<EOF
Package: $APP
Version: ${VERSION}-${REVISION}
Section: video
Priority: optional
Architecture: amd64
Maintainer: mbligh <noreply@github.com>
Depends: adduser, libc6, libicu76, libssl3t64, libsqlite3-0, zlib1g, ca-certificates
Description: $NAME media management service
 Official upstream Linux x64 release repackaged for native systemd.
EOF
cat > "$pkg/DEBIAN/postinst" <<EOF
#!/bin/sh
set -e
if [ "\$1" = configure ]; then
  getent group media >/dev/null || addgroup --system media
  if ! id $APP >/dev/null 2>&1; then
    adduser --system --home /var/lib/$APP --no-create-home --ingroup media $APP
  fi
  install -d -o $APP -g media -m 2775 /var/lib/$APP
  if [ -d /run/systemd/system ]; then
    systemctl daemon-reload
    systemctl enable $APP.service
    systemctl restart $APP.service
  fi
fi
EOF
cat > "$pkg/DEBIAN/prerm" <<EOF
#!/bin/sh
set -e
if [ "\$1" = remove ] || [ "\$1" = upgrade ] || [ "\$1" = deconfigure ]; then
  if [ -d /run/systemd/system ]; then systemctl stop $APP.service || true; fi
fi
EOF
cat > "$pkg/DEBIAN/postrm" <<EOF
#!/bin/sh
set -e
if [ "\$1" = remove ] || [ "\$1" = purge ]; then
  if [ -d /run/systemd/system ]; then
    systemctl disable $APP.service || true
    systemctl daemon-reload
  fi
fi
if [ "\$1" = purge ]; then rm -rf /var/lib/$APP; fi
EOF
chmod 755 "$pkg/DEBIAN/"{postinst,prerm,postrm} 2>/dev/null || chmod 755 "$pkg/DEBIAN/postinst" "$pkg/DEBIAN/prerm" "$pkg/DEBIAN/postrm"
printf 'Upstream: %s\nSHA256: %s\nLicense: GPL-3.0-or-later; see upstream repository.\n' "$URL" "$SHA256" > "$pkg/usr/share/doc/$APP/copyright"
mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/${APP}_${VERSION}-${REVISION}_amd64.deb"
