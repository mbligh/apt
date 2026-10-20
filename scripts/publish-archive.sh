#!/usr/bin/env bash
set -euo pipefail

# Seed from the last Git-backed archive for older packages. New releases are\n# deployed directly as Pages artifacts, avoiding GitHub Git blob limits.
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
      if [[ "$package" == pypi-* ]]; then
        # PyPI wheels may rebuild differently without changing the pinned root
        # version. Preserve the already-published immutable Debian artifact.
        echo "Reusing existing $package $version from archive (rebuilt bytes differ)."
        continue
      fi
      echo "Reusing existing $package $version from archive (rebuilt bytes differ)." >&2
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

# Deploy site/ directly via upload-pages-artifact; do not commit binaries to Git.\necho "Prepared Pages archive: $(du -sh site | cut -f1)"\n