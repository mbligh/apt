#!/usr/bin/env bash
set -euo pipefail

# The apt-repo branch is the durable archive. Pages is a generated deployment.
mkdir -p site
if git ls-remote --exit-code --heads origin apt-repo >/dev/null 2>&1; then
  git fetch origin apt-repo
  git archive FETCH_HEAD | tar -x -C site
fi

mkdir -p site/pool/main site/dists/trixie/main/binary-amd64
for deb in dist/*.deb; do
  filename="$(basename "$deb")"
  package="$(dpkg-deb -f "$deb" Package)"
  version="$(dpkg-deb -f "$deb" Version)"
  arch="$(dpkg-deb -f "$deb" Architecture)"
  case "$arch" in amd64|all) ;; *) echo "Unsupported architecture: $arch" >&2; exit 1;; esac
  target="site/pool/main/$filename"
  if [[ -e "$target" ]]; then
    if ! cmp -s "$deb" "$target"; then
      echo "Refusing to overwrite $package $version with different bytes. Bump Debian revision." >&2
      exit 1
    fi
  else
    cp "$deb" "$target"
  fi
done

(
  cd site
  dpkg-scanpackages --multiversion pool/main /dev/null > dists/trixie/main/binary-amd64/Packages
  gzip -n -9 -c dists/trixie/main/binary-amd64/Packages > dists/trixie/main/binary-amd64/Packages.gz
  cat > release.conf <<'EOF'
APT::FTPArchive::Release::Origin "mbligh";
APT::FTPArchive::Release::Label "mbligh";
APT::FTPArchive::Release::Suite "trixie";
APT::FTPArchive::Release::Codename "trixie";
APT::FTPArchive::Release::Architectures "amd64";
APT::FTPArchive::Release::Components "main";
APT::FTPArchive::Release::Description "mbligh Debian 13 packages";
EOF
  apt-ftparchive -c release.conf release dists/trixie > dists/trixie/Release
  rm release.conf
  gpg --batch --yes --local-user "$SIGNING_FINGERPRINT" --clearsign -o dists/trixie/InRelease dists/trixie/Release
  gpg --batch --yes --local-user "$SIGNING_FINGERPRINT" --detach-sign -o dists/trixie/Release.gpg dists/trixie/Release
  gpg --batch --export "$SIGNING_FINGERPRINT" > mbligh-archive-keyring.gpg
  gpg --batch --armor --export "$SIGNING_FINGERPRINT" > mbligh-archive-keyring.asc
  touch .nojekyll
)
gpg --batch --verify site/dists/trixie/InRelease
test -s site/dists/trixie/main/binary-amd64/Packages.gz

# Commit the complete static archive to its own branch, independently of main.
# An orphan branch avoids duplicating the packaging source history.
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git -C "$tmp" init -q
git -C "$tmp" checkout -q -b apt-repo
cp -a site/. "$tmp/"
git -C "$tmp" add -A
git -C "$tmp" commit -qm "Publish APT archive from ${GITHUB_SHA:-main}"
git -C "$tmp" remote add origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
# Do not force-push: concurrent/competing changes must not be silently lost.
if git ls-remote --exit-code --heads origin apt-repo >/dev/null 2>&1; then
  git -C "$tmp" fetch -q origin apt-repo
  git -C "$tmp" merge -q --allow-unrelated-histories -s ours origin/apt-repo
fi
git -C "$tmp" push -q origin HEAD:refs/heads/apt-repo
