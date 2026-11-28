#!/bin/sh
# Repackage the immutable Debian 13 cfsolve build with tools/video/cf-curl.
set -eu
cd "$(dirname "$0")/../.."

REVISION=1
ARCH=amd64
MODE=${1:-build}
case "$MODE" in build|--resolve) ;; *) echo 'Expected build or --resolve' >&2; exit 2 ;; esac
TOOLS_SOURCE=private-tools/video/cf-curl

test -f "$TOOLS_SOURCE" || {
    echo "Missing private tools/video/cf-curl checkout (TOOLS_DEPLOY_KEY)" >&2
    exit 1
}
# This must be a real source checkout, not a stale copied script.
TOOLS_SHA=$(git -C private-tools log -1 --format=%H -- video/cf-curl)
TOOLS_EPOCH=$(git -C private-tools log -1 --format=%ct -- video/cf-curl)
test -n "$TOOLS_SHA" && test -n "$TOOLS_EPOCH"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

# The build fork publishes one immutable release per master commit.
# Do not depend on GitHub Actions' expiring 90-day artifact downloads.
if [ -n "${GH_TOKEN:-}" ]; then
    set -- -H "Authorization: Bearer $GH_TOKEN"
else
    set --
fi
curl -fsSL --retry 3 "$@" -H 'Accept: application/vnd.github+json' \
    -o "$tmp/releases.json" \
    'https://api.github.com/repos/mbligh/cfsolve/releases?per_page=30'

python3 - "$tmp/releases.json" "${CFSOLVE_RELEASE_TAG:-}" > "$tmp/source-info" <<'PY'
import datetime
import json
import re
import sys

releases = json.load(open(sys.argv[1]))
if not isinstance(releases, list):
    raise SystemExit('GitHub did not return a release list')
wanted = sys.argv[2]
release = next((r for r in releases if re.fullmatch(r'build-[0-9a-f]{12}',
               r.get('tag_name', '')) and not r.get('draft')
               and (not wanted or r['tag_name'] == wanted)), None)
if release is None:
    raise SystemExit('No published, immutable cfsolve build release found')
assets = {a['name']: a for a in release.get('assets', [])}
names = ('cfsolve-debian13-amd64.tar.gz', 'SHA256SUMS')
for name in names:
    if name not in assets:
        raise SystemExit(f'Missing cfsolve release asset: {name}')
    asset = assets[name]
    digest = asset.get('digest') or ''
    if not re.fullmatch(r'sha256:[0-9a-f]{64}', digest):
        raise SystemExit(f'Release asset {name} has no SHA256 digest')
    url = asset.get('browser_download_url') or ''
    if not url.startswith('https://github.com/mbligh/cfsolve/releases/download/'):
        raise SystemExit(f'Unexpected asset download URL: {url}')
    print(url)
    print(digest.removeprefix('sha256:'))
stamp = release.get('published_at') or ''
published = datetime.datetime.fromisoformat(stamp.replace('Z', '+00:00'))
if published.tzinfo is None:
    raise SystemExit('Release has no timezone-aware publication date')
tag = release['tag_name']
source = release.get('target_commitish') or ''
if not re.fullmatch(r'[0-9a-f]{40}', source) or not source.startswith(tag[6:]):
    raise SystemExit('Release target commit does not match release tag')
print(tag)
print(int(published.timestamp()))
PY
ARCHIVE_URL=$(sed -n '1p' "$tmp/source-info")
ARCHIVE_SHA256=$(sed -n '2p' "$tmp/source-info")
SUM_URL=$(sed -n '3p' "$tmp/source-info")
SUM_SHA256=$(sed -n '4p' "$tmp/source-info")
CFSOLVE_TAG=$(sed -n '5p' "$tmp/source-info")
CFSOLVE_EPOCH=$(sed -n '6p' "$tmp/source-info")

# Use the most recently changed input as the version timestamp. A rebuilt
# binary or a new private cf-curl revision therefore yields a new APT version.
if [ "$TOOLS_EPOCH" -gt "$CFSOLVE_EPOCH" ]; then
    SOURCE_DATE_EPOCH="$TOOLS_EPOCH"
else
    SOURCE_DATE_EPOCH="$CFSOLVE_EPOCH"
fi
export SOURCE_DATE_EPOCH
STAMP=$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y%m%d%H%M%S)
VERSION="0.$STAMP+cf${CFSOLVE_TAG#build-}.t$(printf '%s' "$TOOLS_SHA" | cut -c1-12)-$REVISION"

if [ "$MODE" = --resolve ]; then
    printf '%s %s %s\n' "$VERSION" "$CFSOLVE_TAG" "$(git -C private-tools rev-parse HEAD)"
    exit 0
fi
if [ -n "${CFSOLVE_EXPECTED_VERSION:-}" ] && [ "$VERSION" != "$CFSOLVE_EXPECTED_VERSION" ]; then
    echo "Resolved cfsolve version $VERSION differs from preflight $CFSOLVE_EXPECTED_VERSION" >&2
    exit 1
fi
echo "Packaging cfsolve $CFSOLVE_TAG and tools/video/cf-curl $TOOLS_SHA as $VERSION"
curl -fLsS --retry 3 -o "$tmp/cfsolve-debian13-amd64.tar.gz" "$ARCHIVE_URL"
curl -fLsS --retry 3 -o "$tmp/SHA256SUMS" "$SUM_URL"
printf '%s  %s\n' "$ARCHIVE_SHA256" "$tmp/cfsolve-debian13-amd64.tar.gz" | sha256sum -c -
printf '%s  %s\n' "$SUM_SHA256" "$tmp/SHA256SUMS" | sha256sum -c -
(cd "$tmp" && sha256sum -c SHA256SUMS)

mkdir -p "$tmp/source"
tar -xzf "$tmp/cfsolve-debian13-amd64.tar.gz" -C "$tmp/source"
test -x "$tmp/source/challenge"
test -f "$tmp/source/profiles/safari-26-ios.json"
test -d "$tmp/source/profiles/safari-26-ios"
python3 -m py_compile "$TOOLS_SOURCE"

pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/bin" "$pkg/usr/share/cfsolve" \
    "$pkg/usr/share/doc/cfsolve"
install -m 0755 "$tmp/source/challenge" "$pkg/usr/bin/cfsolve"
ln -s cfsolve "$pkg/usr/bin/challenge"
install -m 0755 "$TOOLS_SOURCE" "$pkg/usr/bin/cf-curl"
cp -a "$tmp/source/profiles" "$pkg/usr/share/cfsolve/profiles"
install -m 0644 "$tmp/source/LICENSE" "$pkg/usr/share/doc/cfsolve/LICENSE.upstream"
install -m 0644 "$tmp/source/README.md" "$pkg/usr/share/doc/cfsolve/README.upstream.md"

cat > "$pkg/DEBIAN/control" <<EOF
Package: cfsolve
Version: $VERSION
Section: net
Priority: optional
Architecture: $ARCH
Maintainer: mbligh <noreply@github.com>
Depends: python3, curl, ca-certificates, libc6 (>= 2.41), libgcc-s1
Description: Browserless Cloudflare challenge solver and curl fallback
 Rust cfsolve challenge executable packaged for Debian 13 together
 with the cf-curl HTML GET helper. Includes required browser profiles.
EOF
cat > "$pkg/usr/share/doc/cfsolve/README.Debian" <<EOF
Installed commands:
  /usr/bin/cfsolve    (upstream binary named challenge)
  /usr/bin/challenge  (symlink to cfsolve)
  /usr/bin/cf-curl    (from private mbligh/tools, video/cf-curl)
Browser profile and fingerprint responses:
  /usr/share/cfsolve/profiles/

cf-curl finds these locations without environment overrides.
CFSOLVE_DIR, CFSOLVE_BIN, and CFSOLVE_PROFILE remain optional overrides.

cfsolve release: https://github.com/mbligh/cfsolve/releases/tag/$CFSOLVE_TAG
cf-curl source commit: $TOOLS_SHA in https://github.com/mbligh/tools
Packaged sources are public despite the private tools Git repository.
EOF
cat > "$pkg/usr/share/doc/cfsolve/copyright" <<EOF
cfsolve: https://github.com/mbligh/cfsolve
Upstream: https://github.com/chris124567/cfsolve
License: MIT, except vendored dependencies which retain their own licenses.
Upstream LICENSE is included as LICENSE.upstream.
cf-curl: https://github.com/mbligh/tools (video/cf-curl).
EOF

mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/cfsolve_${VERSION}_${ARCH}.deb"
