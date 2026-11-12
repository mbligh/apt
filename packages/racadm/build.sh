#!/bin/sh
# Import Dell's original RACADM Debian packages (iDRAC7/iDRAC8 + HAPI).
# Dell's 11.3 tools archive includes Ubuntu 22 amd64 .debs.
set -eu
cd "$(dirname "$0")/../.."

VERSION=11.3.0.0
URL=https://dl.dell.com/FOLDER12638439M/1/Dell-iDRACTools-Web-LX-11.3.0.0-795_A00.tar.gz

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
  --user-agent 'Mozilla/5.0' -o "$tmp/idrac-tools.tar.gz" "$URL"
# Avoid trusting arbitrary paths from the vendor archive during extraction.
tar -tzf "$tmp/idrac-tools.tar.gz" | grep -Eq '(^|/)racadm/UBUNTU22/x86_64/srvadmin-idracadm8[^/]*\.deb$' || {
  echo "Dell archive does not contain the expected Ubuntu RACADM packages" >&2; exit 1;
}
mkdir "$tmp/extract"
tar -xzf "$tmp/idrac-tools.tar.gz" -C "$tmp/extract" \
  --wildcards --no-anchored 'racadm/UBUNTU22/x86_64/*.deb'
mkdir -p dist
for package in srvadmin-hapi srvadmin-idracadm7 srvadmin-idracadm8; do
  found=
  for file in $(find "$tmp/extract" -type f -name "$package*.deb"); do
    actual=$(dpkg-deb -f "$file" Package)
    [ "$actual" = "$package" ] || continue
    arch=$(dpkg-deb -f "$file" Architecture)
    [ "$arch" = amd64 ] || { echo "Unexpected architecture $arch for $package" >&2; exit 1; }
    version=$(dpkg-deb -f "$file" Version)
    case "$version" in
      "$VERSION"|"$VERSION"-*|"$VERSION".*) ;;
      *) echo "Unexpected version $version for $package" >&2; exit 1 ;;
    esac
    [ -z "$found" ] || { echo "Duplicate $package in vendor archive" >&2; exit 1; }
    found=$file
  done
  [ -n "$found" ] || { echo "Missing $package in vendor archive" >&2; exit 1; }
  cp "$found" "dist/$(basename "$found")"
done
