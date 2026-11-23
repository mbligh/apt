#!/bin/sh
# Bundle the upstream application, Electron, and locked production dependencies.
# npm is used only in the CI build. Installed machines need no npm/npx.
set -eu
umask 022
cd "$(dirname "$0")/../.."
. packages/agentify-desktop/version

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir "$tmp/source"
git -C "$tmp/source" init -q
git -C "$tmp/source" remote add origin https://github.com/agentify-sh/desktop.git
git -C "$tmp/source" fetch -q --depth 1 origin "$UPSTREAM_COMMIT"
git -C "$tmp/source" -c advice.detachedHead=false checkout -q --detach FETCH_HEAD
test "$(git -C "$tmp/source" rev-parse HEAD)" = "$UPSTREAM_COMMIT"
app="$tmp/source"
test "$(node -p "require('$app/package.json').version")" = "$VERSION"
test -f "$app/package-lock.json"

# npm ci checks upstream lockfile integrity hashes. Do not execute dependency
# lifecycle scripts; run only Electron's pinned binary installer explicitly.
(
  cd "$app"
  npm ci --omit=dev --ignore-scripts --no-audit --no-fund
  node node_modules/electron/install.js
)
test -x "$app/node_modules/electron/dist/electron"
test -f "$app/node_modules/electron/cli.js"
test -f "$app/node_modules/@modelcontextprotocol/sdk/dist/esm/server/mcp.js"
test -f "$app/node_modules/zod/package.json"

pkg="$tmp/pkg"
dest="$pkg/usr/lib/agentify-desktop"
mkdir -p "$pkg/DEBIAN" "$dest" "$pkg/usr/bin" \
  "$pkg/usr/share/doc/agentify-desktop" "$pkg/usr/share/applications"
cp -a "$app"/. "$dest"/
rm -rf "$dest/.git" "$dest/.github" "$dest/tests" "$dest/completed" \
  "$dest/scripts" "$dest/.gitignore" "$dest/dist"

# Chromium sandbox helper: retain its setuid mode, not --no-sandbox.
test -f "$dest/node_modules/electron/dist/chrome-sandbox"
chmod 4755 "$dest/node_modules/electron/dist/chrome-sandbox"

cat > "$pkg/usr/bin/agentify-desktop" <<'EOF'
#!/bin/sh
exec /usr/bin/node24 /usr/lib/agentify-desktop/bin/agentify-desktop.mjs "$@"
EOF
cat > "$pkg/usr/bin/agentify-desktop-mcp" <<'EOF'
#!/bin/sh
exec /usr/bin/agentify-desktop mcp "$@"
EOF
cat > "$pkg/usr/bin/agentify-desktop-gui" <<'EOF'
#!/bin/sh
exec /usr/bin/agentify-desktop gui "$@"
EOF
chmod 755 "$pkg/usr/bin/agentify-desktop" "$pkg/usr/bin/agentify-desktop-mcp" "$pkg/usr/bin/agentify-desktop-gui"

cat > "$pkg/usr/share/applications/agentify-desktop.desktop" <<'EOF'
[Desktop Entry]
Name=Agentify Desktop
Comment=Browser session manager and MCP server
Exec=agentify-desktop
Terminal=false
Type=Application
Categories=Development;Network;
Icon=applications-internet
EOF

cat > "$pkg/DEBIAN/control" <<EOF
Package: agentify-desktop
Version: ${VERSION}-${REVISION}
Section: devel
Priority: optional
Architecture: amd64
Maintainer: mbligh <noreply@github.com>
Depends: nodejs24 (>= 24.22.2), ca-certificates, libc6 (>= 2.36), libnss3, libnspr4, libgtk-3-0t64, libatk-bridge2.0-0t64, libasound2t64, libgbm1, libdrm2, libxss1, libx11-6, libxkbcommon0
Recommends: xdg-utils
Homepage: https://github.com/agentify-sh/desktop
Description: Desktop browser session manager and MCP server
 Unofficial Agentify Desktop 0.2.4 repackage with bundled Electron runtime
 and lockfile-pinned dependencies; no npm or npx needed at runtime.
EOF
cp "$app/LICENSE" "$pkg/usr/share/doc/agentify-desktop/copyright"
cp "$app/TRADEMARKS.md" "$pkg/usr/share/doc/agentify-desktop/TRADEMARKS.md"
cat > "$pkg/usr/share/doc/agentify-desktop/README.Debian" <<EOF
Unofficial repackage of https://github.com/agentify-sh/desktop
Upstream commit: $UPSTREAM_COMMIT
Upstream code: MPL-2.0. Bundled dependencies retain their own licenses.
Upstream Agentify trademarks are reserved; see TRADEMARKS.md.
Requires a graphical desktop session for browser windows.
OpenCode MCP command: /usr/bin/agentify-desktop mcp
EOF

find "$pkg" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
mkdir -p dist
SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" dpkg-deb --build --root-owner-group \
  "$pkg" "dist/agentify-desktop_${VERSION}-${REVISION}_amd64.deb"
