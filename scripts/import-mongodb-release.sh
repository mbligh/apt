#!/usr/bin/env bash
set -euo pipefail

# Import original upstream Debian packages uploaded to GitHub Releases.
# Checksums are pinned to the supplied files, not fetched dynamically.
release='mongodb-9.0.4'
mkdir -p dist
while read -r filename sha256 package version; do
  [[ -n "$filename" && "$filename" != \#* ]] || continue
  url="https://github.com/mbligh/apt/releases/download/${release}/${filename}"
  curl --fail --location --retry 3 "$url" -o "dist/$filename"
  printf '%s  %s\n' "$sha256" "dist/$filename" | sha256sum -c -
  test "$(dpkg-deb -f "dist/$filename" Package)" = "$package"
  test "$(dpkg-deb -f "dist/$filename" Version)" = "$version"
  test "$(dpkg-deb -f "dist/$filename" Architecture)" = amd64
done <<'PACKAGES'
mongodb-org-server_9.0.4_amd64.deb f4753cec65e9ce4dd23d933f4637f5e6134ed7c0286774fb953be9a079b79e96 mongodb-org-server 9.0.4
mongodb-database-tools-debian13-x86_64-100.19.1.deb a7d7ec436baf53300df83246bc4ed3702a4abf2d72dc34e42bab9657935d6a4c mongodb-database-tools 100.19.1
mongodb-atlas-cli_1.59.2_linux_x86_64.deb 2330f8a4fe2881030a26a14b006599659be78c6d90e1fc1cdb6df951a6cde553 mongodb-atlas-cli 1.59.2
mongodb-compass_1.53.0_amd64.deb c3660c1f295b2c94b6f8186bfdfcb78681d489b4badb3b78e18c1f237e5de9cd mongodb-compass 1.53.0
mongodb-mongosh_2.13.0_amd64.deb 63b71930a7065acd199fe68babba6dda2c045aa1786f6091089c595773638119 mongodb-mongosh 2.13.0
PACKAGES
