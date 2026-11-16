#!/bin/sh
# Build the g command from a staged, authenticated mbligh/tools checkout.
set -eu
cd "$(dirname "$0")/../.."

source=packages/mbligh-tools/upstream-g
version_file=packages/mbligh-tools/upstream-version
if [ ! -f "$source" ] || [ ! -f "$version_file" ]; then
    echo "mbligh-tools: private tools/g and its version must be staged by publish-r2.yml" >&2
    exit 1
fi
version=$(cat "$version_file")
if ! printf '%s\n' "$version" | grep -Eq '^0\.[0-9]{14}\+git[0-9a-f]{12}-1$'; then
    echo "mbligh-tools: invalid version: $version" >&2
    exit 1
fi
python3 - "$source" <<'PY'
import ast
from pathlib import Path
import sys
ast.parse(Path(sys.argv[1]).read_text())
PY

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/bin" "$pkg/usr/share/doc/mbligh-tools"
install -m 755 "$source" "$pkg/usr/bin/g"
cat > "$pkg/DEBIAN/control" <<EOF
Package: mbligh-tools
Version: $version
Section: vcs
Priority: optional
Architecture: all
Maintainer: mbligh <noreply@github.com>
Depends: git, python3
Description: mbligh Git convenience command
 Installs g, the Git wrapper from mbligh/tools, with custom
 synchronization operations and pass-through for ordinary Git commands.
EOF
cat > "$pkg/usr/share/doc/mbligh-tools/README.Debian" <<EOF
Source: private repository mbligh/tools (tools/g)
Version: $version
The installed command is /usr/bin/g. The package is public even though
its upstream Git repository is private; the installed Python source is
included in the public .deb archive.
EOF
mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/mbligh-tools_${version}_all.deb"
