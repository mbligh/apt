#!/usr/bin/env bash
set -euo pipefail

# Import the unmodified upstream package supplied as a GitHub Release asset.
release='mongodb-9.0.4'
filename='mongodb-org-server_9.0.4_amd64.deb'
sha256='f4753cec65e9ce4dd23d933f4637f5e6134ed7c0286774fb953be9a079b79e96'
url="https://github.com/mbligh/apt/releases/download/${release}/${filename}"

mkdir -p dist
curl --fail --location --retry 3 "$url" -o "dist/$filename"
printf '%s  %s\n' "$sha256" "dist/$filename" | sha256sum -c -
test "$(dpkg-deb -f "dist/$filename" Package)" = mongodb-org-server
test "$(dpkg-deb -f "dist/$filename" Version)" = 9.0.4
test "$(dpkg-deb -f "dist/$filename" Architecture)" = amd64
