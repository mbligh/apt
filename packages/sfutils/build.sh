#!/bin/sh
# Repackage AMD's upstream Solarflare Linux Utilities x86_64 RPM for Debian 13.
# SF-107601-LS includes sfupdate, sfboot, sfkey and sfctool.
# No firmware is written or NIC configuration changed during package installation.
set -eu
cd "$(dirname "$0")/../.."

VERSION=8.3.4.1000
ARCHIVE=SF-107601-LS-76-Solarflare-Linux-Utilities-RPM-64bit.zip
URL=https://www.amd.com/content/dam/amd/en/support/downloads/solarflare/firmware-utilities/8-3-4-1000/$ARCHIVE

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
  -o "$tmp/$ARCHIVE" "$URL"
echo "AMD sfutils download sha256 (record for independent verification):"
sha256sum "$tmp/$ARCHIVE"

# Require exactly one compatible, versioned vendor RPM in the ZIP.
entries=$(unzip -Z -1 "$tmp/$ARCHIVE" | grep -E '(^|/)sfutils-[^/]+\.x86_64\.rpm$' || :)
count=$(printf '%s\n' "$entries" | grep -c . || :)
[ "$count" -eq 1 ] || {
  echo "Expected exactly one x86_64 sfutils RPM in the AMD archive; found $count" >&2
  exit 1
}
rpmfile=$tmp/$(basename "$entries")
unzip -p "$tmp/$ARCHIVE" "$entries" > "$rpmfile"

name=$(rpm -qp --qf '%{NAME}' "$rpmfile")
version=$(rpm -qp --qf '%{VERSION}' "$rpmfile")
arch=$(rpm -qp --qf '%{ARCH}' "$rpmfile")
[ "$name" = sfutils ] && [ "$version" = "$VERSION" ] && [ "$arch" = x86_64 ] || {
  echo "Unexpected upstream RPM: $name $version $arch" >&2
  exit 1
}
rpm -qpl "$rpmfile" | grep -Eq '/(sbin|bin)/sfupdate$' || {
  echo "Vendor RPM lacks sfupdate" >&2; exit 1;
}
rpm -qpl "$rpmfile" | grep -Eq '/(sbin|bin)/sfboot$' || {
  echo "Vendor RPM lacks sfboot" >&2; exit 1;
}

# AMD's own documentation recommends alien conversion for Debian/Ubuntu.
# Deliberately omit --scripts: do not import RPM installation/removal hooks.
(
  cd "$tmp"
  alien --to-deb --keep-version "$(basename "$rpmfile")"
)

set -- "$tmp"/sfutils_*_amd64.deb
[ "$#" -eq 1 ] && [ -f "$1" ] || {
  echo "alien did not produce exactly one amd64 Debian package" >&2
  exit 1
}
package=$(dpkg-deb -f "$1" Package)
deb_arch=$(dpkg-deb -f "$1" Architecture)
deb_version=$(dpkg-deb -f "$1" Version)
[ "$package" = sfutils ] && [ "$deb_arch" = amd64 ] || {
  echo "Unexpected Debian package: $package $deb_version $deb_arch" >&2
  exit 1
}
case "$deb_version" in
  "$VERSION"-*) ;;
  *) echo "Unexpected Debian package version: $deb_version" >&2; exit 1 ;;
esac
dpkg-deb --contents "$1" | grep -Eq '\./usr/(sbin|bin)/sfupdate$' || {
  echo "Converted Debian package lacks sfupdate" >&2; exit 1;
}
mkdir -p dist
cp "$1" dist/
