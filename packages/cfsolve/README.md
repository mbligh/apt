# cfsolve (Debian 13, amd64)

This package combines the successful Linux `challenge` binary from
[mbligh/cfsolve](https://github.com/mbligh/cfsolve) with the Python HTML
fallback tool `video/cf-curl` from the private `mbligh/tools` repository.

## Installed files

- `/usr/bin/cfsolve` — compiled binary from `challenge`
- `/usr/bin/challenge` — symbolic link to `cfsolve`
- `/usr/bin/cf-curl` — executable Python wrapper
- `/usr/share/cfsolve/profiles/` — full browser fingerprint/profile tree

The `cf-curl` default binary lookup uses `PATH` and selects
`/usr/share/cfsolve/profiles/safari-26-ios.json` when present.
No environment overrides are needed on an ordinary installed Debian 13 host.
Local source checkouts and manually installed `/usr/local` setups still work.

## Sources and versioning

- `mbligh/cfsolve` builds on Debian 13 and uploads immutable public GitHub
  Releases tagged `build-<commit12>`. A GitHub Actions artifact is **not** an
  acceptable long-term source because it expires.
- The reusable APT job checks out only `video/cf-curl` from private
  `mbligh/tools` using the existing read-only `TOOLS_DEPLOY_KEY` secret.
- The builder verifies the archive and checksum asset SHA-256 values reported
  by GitHub, plus the archive digest in `SHA256SUMS`.
- The Debian version is `0.<most-recent-source-UTC-timestamp>+cf<commit12>.t<tools12>-<revision>`.
  Either source changing changes the version. If only the local packaging recipe
  changes, explicitly increase `REVISION` in `build.sh` to avoid overwriting
  a previously published immutable package version.
- `SOURCE_DATE_EPOCH` uses the newest source timestamp for stable Debian
  archive metadata.

Because the APT archive is public, the installed `cf-curl` source is public
inside the .deb even though the complete tools repository is private.

## Workflow

Run [Build cfsolve](../../actions/workflows/package-cfsolve.yml) manually, or
allow its normal `main`-branch trigger when a packaging file changes.
The reusable build tests installation inside `debian:trixie`, runs both Rust
CLI aliases' `--help`, checks Python syntax, and asserts the Python wrapper
selects the correct executable/profile without overrides.

The generic APT pipeline stages the immutable .deb in R2 and triggers the
serialized signed-index publisher only if the package is new or changed.
Once indexed, install or upgrade using:

```sh
sudo apt update
sudo apt install cfsolve
```

The hourly workflow checks both upstream sources at minute 43, compares the
computed version with the authoritative R2 Packages index, and skips the
binary download, dependency installation, build, smoke test and publication
when an equal or newer package is already indexed. It pins the release tag
and private tools checkout commit between preflight and build. Manual
dispatch remains available for immediate checks. No cross-repository write
token or additional secrets are required. The schedule may be delayed by
GitHub Actions. Local artifact-changing recipe edits still require bumping
REVISION. The preflight-only refactor leaves REVISION unchanged.

## Diagnostics

The workflow uploads `debian-packages` artifacts containing the exact
`.deb` sent to the R2 staging service. If the build fails, inspect the
`Build cfsolve and cf-curl` workflow run before installing the package.
