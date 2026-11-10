#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."

VERSION=0.3.1
REVISION=1
ARCH=all
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# npm is a BUILD dependency only; no npm/npx on installed hosts.
mkdir -p "$tmp/upstream"
npm install --prefix "$tmp/upstream" --omit=dev --no-audit --no-fund --save-exact "@wonderwhy-er/desktop-commander@$VERSION"
app="$tmp/upstream/node_modules/@wonderwhy-er/desktop-commander"
test -f "$app/dist/index.js"
test "$(node -p "require('$app/package.json').version")" = "$VERSION"

pkg="$tmp/pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/lib/desktop-commander" "$pkg/usr/bin" "$pkg/usr/share/doc/desktop-commander"
cp -a "$tmp/upstream/node_modules" "$pkg/usr/lib/desktop-commander/"
cat > "$pkg/usr/bin/desktop-commander" <<'EOF'
#!/bin/sh
exec /usr/bin/node /usr/lib/desktop-commander/node_modules/@wonderwhy-er/desktop-commander/dist/index.js "$@"
EOF
chmod 755 "$pkg/usr/bin/desktop-commander"
cat > "$pkg/DEBIAN/control" <<EOF
Package: desktop-commander
Version: ${VERSION}-${REVISION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Maintainer: mbligh <noreply@github.com>
Depends: nodejs (>= 22.12), ca-certificates
Description: Desktop Commander MCP server and remote device agent
 Remote MCP agent and filesystem/terminal tools, with JavaScript
 dependencies bundled at build time. No npm is needed at runtime.
EOF
cat > "$pkg/usr/share/doc/desktop-commander/copyright" <<EOF
Upstream: https://github.com/wonderwhy-er/DesktopCommanderMCP
Upstream npm package: @wonderwhy-er/desktop-commander@$VERSION
Main project license: MIT
Bundled dependencies retain their upstream licenses in their package directories.
EOF
mkdir -p dist
dpkg-deb --build --root-owner-group "$pkg" "dist/desktop-commander_${VERSION}-${REVISION}_${ARCH}.deb"
