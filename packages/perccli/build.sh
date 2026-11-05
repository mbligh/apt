#!/bin/sh
# Import Dell's original PERCCLI Debian package without rebuilding the binary.
set -eu
cd "$(dirname "$0")/../.."

URL=https://dl.dell.com/FOLDER11213122M/1/PERCCLI_7.2616.0_Linux.tar.gz
SHA256=74ab1e99b9d8bcf92077cc9913574ca244a3a552bc0c5e77c416c569eebc4c46
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

curl -fL --retry 3 -o "$tmp/perccli.tar.gz" "$URL"
echo "$SHA256  $tmp/perccli.tar.gz" | sha256sum -c -
mkdir "$tmp/extracted"
tar -xzf "$tmp/perccli.tar.gz" -C "$tmp/extracted"

# Dell distributes a native Debian package in the Linux tarball.
find "$tmp/extracted" -type f -name 'perccli_*.deb' > "$tmp/matches"
if [ "$(wc -l < "$tmp/matches")" -ne 1 ]; then
    echo 'Expected exactly one Dell perccli Debian package in archive' >&2
    exit 1
fi
deb=$(cat "$tmp/matches")
package=$(dpkg-deb -f "$deb" Package)
arch=$(dpkg-deb -f "$deb" Architecture)
version=$(dpkg-deb -f "$deb" Version)
[ "$package" = perccli ] || { echo "Unexpected package: $package" >&2; exit 1; }
case "$arch" in amd64|all) ;; *) echo "Unexpected architecture: $arch" >&2; exit 1 ;; esac
case "$version" in 007.2616.*|7.2616.*) ;; *)
    echo "Unexpected version: $version" >&2; exit 1 ;;
esac
mkdir -p dist
cp "$deb" "dist/$(basename "$deb")"
