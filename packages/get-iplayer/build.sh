#!/bin/sh
# Import a pinned OBS Debian 13 get-iplayer .deb, without the OBS-only keyring dependency.
set -eu
cd "$(dirname "$0")/../.."

VERSION='3.36-1+deb13u3'
LOCAL_VERSION="${VERSION}+mbligh2"
ARCH=all
FILENAME="get-iplayer_${VERSION}_${ARCH}.deb"
URL="https://download.opensuse.org/repositories/home:/m-grant-prg/Debian_13/all/$FILENAME"
# Published by download.opensuse.org in the .deb.mirrorlist file.
SHA256=35e7c205cdf0b2dd0d9b1b6affbda67596a9a014660301b56197393c85b8e2bf

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
  -o "$tmp/$FILENAME" "$URL"
printf '%s  %s\n' "$SHA256" "$tmp/$FILENAME" | sha256sum -c -

package=$(dpkg-deb -f "$tmp/$FILENAME" Package)
version=$(dpkg-deb -f "$tmp/$FILENAME" Version)
arch=$(dpkg-deb -f "$tmp/$FILENAME" Architecture)
[ "$package" = get-iplayer ] || { echo "Unexpected package: $package" >&2; exit 1; }
[ "$version" = "$VERSION" ] || { echo "Unexpected version: $version" >&2; exit 1; }
[ "$arch" = "$ARCH" ] || { echo "Unexpected architecture: $arch" >&2; exit 1; }
dpkg-deb --contents "$tmp/$FILENAME" >/dev/null

# The upstream OBS package depends on the publisher's repository keyring.
# Our own signed APT repository needs no trust of that unrelated repository.
repack="$tmp/repack"
dpkg-deb --raw-extract "$tmp/$FILENAME" "$repack"
# get_iplayer 3.36 cannot process DASH SegmentTimeline manifests without a
# constant @duration, and divides by zero while collecting stream details.
# Skip such manifests so another CDN or HLS variant can still be selected.
# Upstream issue: https://github.com/get-iplayer/get_iplayer/issues/524
python3 - "$repack/usr/bin/get_iplayer" <<'PY'
from pathlib import Path
import sys

script = Path(sys.argv[1])
source = script.read_text()
old = "my $segment_duration = $template->findvalue('@duration') / $template->findvalue('@timescale');"
indent = "\t" * 4
new = ("\n" + indent).join([
    "my $duration = $template->findvalue('@duration');",
    "my $timescale = $template->findvalue('@timescale');",
    "if ( ! $duration || ! $timescale ) {",
    '\tmain::logger "WARNING: Skipping DASH manifest without constant segment duration ($conn->{href})\\n";',
    "\treturn;",
    "}",
    "my $segment_duration = $duration / $timescale;",
])
if source.count(old) != 1:
    raise SystemExit("Expected get_iplayer 3.36 segment-duration expression not found exactly once")
script.write_text(source.replace(old, new))
PY
control="$repack/DEBIAN/control"
grep -q '^Depends: .*mgrant-obs-deb-keyring' "$control" || {
  echo "Expected OBS keyring dependency is missing; review upstream metadata" >&2
  exit 1
}
sed -i \
  -e '/^Depends: /s/, mgrant-obs-deb-keyring//g' \
  -e '/^Depends: /s/mgrant-obs-deb-keyring, //g' \
  "$control"
sed -i "s/^Version: $VERSION$/Version: $LOCAL_VERSION/" "$control"
[ "$(dpkg-deb -f "$tmp/$FILENAME" Version)" = "$VERSION" ] || exit 1
! grep -q 'mgrant-obs-deb-keyring' "$control" || {
  echo "Unexpected remaining OBS keyring dependency" >&2; exit 1;
}
# Use the upstream file's published timestamp for reproducible Debian archives.
export SOURCE_DATE_EPOCH=1789209471
find "$repack" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +

mkdir -p dist
output="dist/get-iplayer_${LOCAL_VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "$repack" "$output"
[ "$(dpkg-deb -f "$output" Version)" = "$LOCAL_VERSION" ] || exit 1
[ "$(dpkg-deb -f "$output" Architecture)" = "$ARCH" ] || exit 1
