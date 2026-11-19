# mbligh apt repository — project outline

## Active build/publishing architecture (November 2026)

The repository is served from **Cloudflare R2** at `https://apt.mbligh.org` (Debian 13/trixie, amd64 and all).

Each package has **one** GitHub Actions job: build, verify, upload the GitHub artifact, then upload immutable `.deb` objects directly to R2. Already-indexed packages with an identical SHA-256 are no-ops; same-version/different-byte builds fail and require a revision bump.

New or recovered uploads are recorded in durable `pending/<run-id>.json` manifests in R2. The serialized `publish-r2.yml` consumes these manifests, verifies the referenced objects, **only** regenerates and signs APT metadata, and removes markers after publishing `InRelease`. A failed index can be retried manually with the original build run ID, or with a blank run ID to reconcile all pending uploads, without rebuilding or uploading `.deb` files.

The package job starts `publish-r2.yml` using `workflow_dispatch` **only after** `scripts/r2-publish stage` records at least one unindexed package. An unchanged build still succeeds and retains its GitHub artifact, but no index job starts. A failed upload or dispatch fails the package job. Pending R2 manifests survive interruptions and can be indexed manually; GitHub Actions no longer starts the publisher on every successful package workflow completion.

A green package build means **built and uploaded to R2**, not necessarily indexed. The signing secret is used only in the index publisher. R2 credentials are passed only to the upload step.

Each current PyPI distribution gets a distinct trigger; `scripts/build-pypi-debs --package <normalized-name>` builds only that entry. Roots are pinned in `pypi-packages.txt`, wheel closures and hashes are locked under `pypi-locks/`, and Debian revisions are maintained in `pypi-revisions.txt`. Python 3.13 and pip 26.2.2 are used for lock generation and Debian builds. Native-wheel architecture fixes and lock adoption use `-3` revisions for duckdb, roombapy-prime, and plexapi. `pypi-plexapi` packages pinned PyPI `plexapi==4.18.3` and uses `pypi-exposed.txt` to opt in to normal Debian system-Python imports, validated by an install/import smoke test in Debian trixie. Opting in places bundled dependencies on sys.path, so other PyPI packages remain isolated by default. The legacy Pages publisher is manual fallback. Previous project phases below contain historical Pages plans rather than the active architecture.

The scheduled `mbligh-tools` and `yt-dlp-sabr` builds now use upstream-derived `SOURCE_DATE_EPOCH` to produce repeatable Debian archive timestamps. Both use Debian revision `-2` to avoid collisions with previously published `-1` packages. `yt-dlp-sabr` also includes the zero-padded GitHub asset ID in its version so a moving release tag that replaces a binary cannot silently reuse a version. Identical scheduled rebuilds should become no-ops, while genuine upstream updates remain publishable. R2's immutable-version hash checks remain mandatory.

The rtach Debian package applies `packages/rtach/pass-command-arguments.patch` to upstream commit `372fefbaa051e240f3923bad480294a4f65718b7`. This propagates additional executable arguments through both the normal master and the macOS spawnd launch path. The package increments its Debian revision to `0.2.0-3` and tests `sh -c`, `bash -l -c`, and interactive `-A` attachment. Builds explicitly set `-Dtarget=x86_64-linux-gnu -Dcpu=baseline` to prevent AVX-512 native-runner instructions from crashing older Xeon processors. Existing default shell integration remains enabled when no explicit arguments are supplied.

## Purpose and operating principles

Host a small, signed Debian APT repository for software maintained or repackaged by mbligh. Keep the *runtime* operational interface conventional: dpkg/apt own installation and upgrades, systemd owns service lifecycle, journald handles logs, and normal host process/network tools remain useful. Avoid Docker, VMs and bespoke application updaters unless there is a concrete dependency or isolation reason.

This repository is the **distribution/publishing repository**, not the source repository for each application. Application source and packaging definitions stay with their projects; build pipelines produce versioned .deb artifacts, then publish them here. Initially target Debian 13 (trixie), amd64 and architecture-independent packages; add architectures/suites only when needed.

## Public repository layout and publication

Publish a static APT archive from GitHub Pages, ultimately at `https://apt.mbligh.org` (DNS and Pages configuration still to be done). Use conventional `dists/trixie/main/binary-amd64/Packages{,.gz}` and `pool/main/` paths, plus `InRelease` and `Release.gpg` metadata. A `.nojekyll` file should be present in the published root. Prefer `reprepro` for archive management, with `apt-ftparchive` as an alternative if needed.

GitHub Actions should validate packages, import them into the archive, sign release metadata, and deploy the static tree to Pages. Stage and validate the complete archive before deployment; avoid publishing an index that references packages not yet available. Keep enough previous versions for rollback, while monitoring GitHub Pages storage/bandwidth limits. GitHub Pages is public, so **do not put private packages or secrets in the published archive**.

Use a dedicated APT archive signing key/subkey. Store the signing private key as a restricted CI secret (or move signing to a separately controlled publisher if warranted), publish the public key/keyring and its independently verified fingerprint, and document rotation/recovery. Never use `trusted=yes` or disable signature checks.

## Client configuration

Install the verified archive public key at `/usr/share/keyrings/mbligh-archive-keyring.gpg` (eventually via a small keyring package). Example `/etc/apt/sources.list.d/mbligh.sources`:

```deb822
Types: deb
URIs: https://apt.mbligh.org
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/mbligh-archive-keyring.gpg
```

Then `apt update`, `apt install <package>`, and ordinary upgrades. The domain, keyring, and repository do not exist as working services until deployed; the example is a target configuration, not an instruction to run immediately. Consider APT pinning if package names could overlap Debian's official packages.

## apt-cacher-ng: planned local shared cache

Plan to run `apt-cacher-ng` on **slagg**, listening on TCP port 3142, accessible only from trusted LAN clients. It is an **on-demand caching proxy**, not a complete offline Debian mirror. It caches requested packages and indexes; it does not guarantee that an uncached package is available offline. Keep the cache on persistent storage, monitor usage and cleanup, and do not expose it to the internet.

Initial setup on slagg:

```sh
sudo apt install apt-cacher-ng
sudo systemctl enable --now apt-cacher-ng
```

For clients using HTTP Debian mirrors, create `/etc/apt/apt.conf.d/02proxy`:

```aptconf
Acquire::http::Proxy "http://slagg:3142";
```

For standard Debian repositories, **HTTP is acceptable** when APT verifies signed Release metadata and package hashes. Switching Debian `URIs` from `https://deb.debian.org/debian` to `http://deb.debian.org/debian` (and likewise the security archive) makes conventional apt-cacher-ng caching straightforward. This is optional: HTTPS can be retained if transport confidentiality is desired, but ordinary CONNECT tunneling does **not** cache the encrypted payload. Avoid changing non-Debian sources indiscriminately.

For the custom GitHub Pages repository, **retain HTTPS on the client by default**. GitHub Pages serves HTTPS; simply changing its URL to HTTP does not make caching work. The default proxy setup above only intercepts HTTP, so the custom repository will initially be fetched directly over HTTPS. If bandwidth warrants it, configure and test an explicit apt-cacher-ng HTTPS backend/remapping arrangement (or an alternative local mirror) for the custom archive, ensuring Release signatures are still checked. Do not assume arbitrary HTTPS URLs are transparently cacheable.

A more complete mirror (e.g. `debmirror`) remains a future option if offline upgrades or complete local package availability become important.

## Debian package build conventions

Prefer upstream Debian packages when available. For our own software and justified third-party repackaging, build real .deb packages using standard Debian tooling (`dpkg-buildpackage`, `debhelper`, `dh`, optionally `sbuild` for clean builds), not hand-crafted install scripts or container-dependent runtime wrappers.

Conventions:
- Packaging files under `debian/` in the application's own source repo; standard `control`, `rules`, `changelog`, copyright and install files as appropriate.
- Debian-compatible versions, correct `Architecture: all` versus `amd64`, declared `Depends`, and repeatable CI builds.
- Files in conventional locations: binaries under `/usr/bin` or `/usr/lib/<package>`, configuration under `/etc`, state under `/var/lib/<package>`; no application writes into `/usr`.
- Native systemd unit files, logging to journald, and package-safe upgrades; use Debian maintainer-script helpers rather than manually manipulating services unnecessarily.
- Prefer Debian-provided dependencies. If Python dependencies cannot be packaged reasonably, a *private*, self-contained environment under `/usr/lib/<package>` is an explicit documented exception, not a second runtime administration model. Never let package installation run `pip install` against the system Python or download unpinned dependencies.
- No mandatory Docker at runtime or for routine service management. Build isolation (including clean chroots) is acceptable when useful.
- Validate with `lintian` and clean install/upgrade/remove tests before publishing; do not overwrite an existing package version with different bytes.
- If a third-party app is repackaged, record its upstream version, source, license, patches and update strategy.

## Implementation stages

1. Establish archive signing key, GitHub Pages deployment, DNS and static archive layout.
2. Publish a minimal test .deb, verify signature/keyring bootstrap and install via apt on a test host.
3. Add a reusable GitHub Actions build-and-publish workflow for application repos.
4. Deploy apt-cacher-ng on slagg and configure HTTP Debian mirror caching on clients; verify cache hits.
5. Evaluate caching/mirroring the custom HTTPS archive and later a partial Debian mirror if necessary.

## Status

Initial packaging and archive workflows exist in GitHub; PyPI repackaging is now implemented but has not yet been CI-verified with a nonempty manifest. Pages deployment, signing key configuration, and apt-cacher-ng status must be verified separately.


## PyPI-to-Debian packaging

A manifest-driven builder (`pypi-packages.txt`, `scripts/build-pypi-debs`) automatically generates `pypi-*` Debian packages from PyPI wheels and their resolved dependencies (`Architecture: all` for pure Python, `amd64` if any native Linux x86-64 wheels are included). Build-time pip runs only in GitHub Actions or a developer environment; installed systems need only APT and the system Python 3.13. Application imports are isolated under `/usr/lib/pypi-<name>`, and console-script wrappers are placed in `/usr/bin`. The builder targets Debian 13 and rejects unsupported wheel platforms, source distributions, and unsupported manifest syntax.

The publication workflow now includes the manifest and builder as triggers and imports generated debs into the existing signed archive. Validation and publishing are separate workflows; no unverified packages are intentionally deployed. Existing publication limitations remain: version and wheel lock updates require explicit Debian revision bumps, command names may conflict, and no automatic service configuration or native-extension compilation is attempted. Future work: automated revisions, clean-install smoke tests for other PyPI packages, dependency metadata checks, and command-conflict detection.


## Dell PERC controller utility

Import the original Dell PERC CLI `perccli_007.1623.0000.0000_all.deb` unchanged from the [`perccli-7.1623` GitHub release](https://github.com/mbligh/apt/releases/tag/perccli-7.1623). The importer pins SHA-256 `e46d955241c932023caf63862cd9dacb2b723b7f944340efb0e5afb6a2681e9d`, obtained from GitHub's uploaded asset digest, and validates the Debian package identity and version. This avoids Dell CDN HTTP 403 responses on GitHub Actions runners. It runs in the build and publish workflows.

PERCCLI is proprietary Dell software. The user uploaded the original package to a public release; the applicable redistribution permission has not been independently verified.

## Node.js 24 and Desktop Commander

Build `nodejs24` as a parallel amd64-only, pinned, SHA-256-verified Node.js 24.22.2 LTS runtime from the official Linux release. Install just the Node binary under `/usr/lib/nodejs24/bin/node`, exposing `/usr/bin/node24`, without replacing the distribution's `/usr/bin/node` and without shipping npm or npx. Packaging version `24.22.2-1`. Updating this runtime requires a new upstream version and verified SHA-256.

Build `desktop-commander` 0.3.1-2 from upstream `@wonderwhy-er/desktop-commander` in CI, using npm only at build time. Bundle its runtime dependencies and invoke `/usr/bin/node24` directly; depend on `nodejs24 (>= 24.22.2)`. Keep its remote agent opt-in per user: no automatic system-level startup, root execution, or remote access until the user starts and pairs it. The vendor's remote relay processes command and result traffic; give the agent account limited privileges.

Both packages are included in the existing build and signed-APT-publish workflows. CI checks SHA-256, installs both packages on Ubuntu 24.04 runners, verifies `node24 --version`, entrypoint syntax, and `desktop-commander remote --help` with a timeout. A Debian 13 end-to-end pairing test has not been performed. Desktop Commander transitive npm dependencies are still resolved on CI builds (no checked-in lockfile); this must be addressed before claiming reproducible output. The publishing pipeline rejects overwriting an existing Debian version with different bytes, so dependency changes require a package revision bump.

## imapsync package

Import the upstream imapsync 2.314 Debian package from the versioned upstream archive at `imapsync.lamiral.info/dist2/old_releases/2.314/`. The build verifies the package name, version, and architecture before adding the original `.deb` to `dist/`; it does not rebuild the Perl application. Both package build and signed repository publication workflows run this import. No external runtime service is required. The upstream archive does not publish a checksum alongside the download; adding an independently verified SHA-256 pin is a future hardening task. Normal archive signing protects the resulting published package and APT metadata, not the initial upstream download.


## Cloudflare R2 publication (staged)

The primary `publish-r2.yml` workflow migrated the existing Pages archive to R2 bucket `mbligh-apt` using `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` and the existing `APT_SIGNING_KEY` GitHub secrets. It retains immutable `.deb` objects and signed SHA256 by-hash indexes; the legacy GitHub Pages workflow is retained as a manual-only fallback. The R2 custom domain at `apt.mbligh.org` was verified with `apt-get update` and an `imapsync` package download on November 10, 2026. Source fingerprints stored as a publication manifest in R2 control subsequent incremental rebuilds.

## Dell RACADM

Import original Dell iDRAC Tools 11.3.0.0 amd64 packages from the vendor's Linux tar archive: `srvadmin-hapi`, `srvadmin-idracadm7`, and `srvadmin-idracadm8` (Ubuntu 22 vendor builds). `packages/racadm/build.sh` validates package identities, architecture, and versions; it does not change vendor binaries. Both CI build and R2 publication workflows now check that APT can resolve dependencies in a clean Debian 13 (Trixie) environment before releasing new RACADM packages. This is a dependency simulation, not proof of local RACADM runtime compatibility. Dell has not supplied Debian 13-specific packages; Dell vendor licensing and redistribution terms must be checked before public distribution. The vendor archive's SHA-256 is not pinned yet and should be verified against an authoritative digest. The upload must not be considered complete until publication workflow succeeds.

## PMTiles CLI

`packages/pmtiles/build.sh` packages the official pinned go-pmtiles v1.31.2 Linux amd64 release. The release archive SHA-256 is checked before installing its `pmtiles` executable into `/usr/bin`; the complete upstream CLI and subcommands are supplied in one Debian package. The R2 publisher automatically discovers this package and rebuilds it when its packaging sources change. The Debian package build workflow smoke-tests its CLI commands.


## ytdl-sub CLI

Package the upstream jmbannon/ytdl-sub release 2026.11.10.post2 as Debian
`ytdl-sub_2026.11.10.post2-2_amd64.deb`. The pinned SHA-256 verifies the
official x86-64 PyInstaller executable. This is a self-contained build with its
own Python/yt-dlp dependencies and upstream presets: no `pip` invocation at
installation or runtime, and no Docker requirement. Install the upstream binary
at `/usr/lib/ytdl-sub/ytdl-sub`, with a POSIX shell launcher at
`/usr/bin/ytdl-sub` that defaults `SSL_CERT_FILE` to Debian's system CA bundle
(`/etc/ssl/certs/ca-certificates.crt`) if unset, preserving explicit overrides.
This fixes HTTPS verification for channel artwork fetched by the bundled
Python's urllib. Depend on FFmpeg, glibc and `ca-certificates`, and recommend Deno
for yt-dlp's optional JavaScript runtime needs. No daemon, system account,
configuration or state directory is created; CLI configuration is owned by the
invoking user. Upstream source: https://github.com/jmbannon/ytdl-sub;
license: GPL-3. The build and R2 publication workflows install the package in
a Debian 13 container and smoke-test `ytdl-sub -h` before release.
Updates require advancing the pinned release version and digest.

## AMD Solarflare sfutils

Repackage official AMD Solarflare Linux Utilities 8.3.4.1000 (SF-107601-LS issue 76) from the vendor x86_64 ZIP/RPM as a Debian 13 `sfutils` package, using `alien --to-deb --keep-version` without importing RPM maintainer scripts. Preserve vendor binaries and bundled firmware; do not install or rebuild a kernel driver. Provides `sfupdate`, `sfboot`, `sfkey`, and `sfctool`. No firmware is flashed automatically on installation. Main package build, R2 publisher, and legacy Pages fallback build the package; the first two smoke-test installation on Debian 13. Source: https://www.amd.com/en/support/downloads/solarflare-downloads.html/ethernet-adapters/solarflare/x2-series.html . The upstream ZIP is SHA-256 pinned (`842bc13284a778c3be01af7e15cc106293d974b48ebcb4726120f9e8619c95c0`) from the official download observed in CI; AMD's redistribution terms for this proprietary firmware/tools archive must be verified before relying on public republishing. Firmware flashing should be initiated manually with console or alternate NIC access and verified board-specific compatibility.

## Private-source mbligh-tools package

Provide `mbligh-tools` (`Architecture: all`) for new Debian installations,
initially containing just `/usr/bin/g` from the private `mbligh/tools`
repository, with `python3` and `git` package dependencies. Package source
is not checked in to this public repository; a read-only SSH deploy key,
stored as the `TOOLS_DEPLOY_KEY` GitHub Actions secret in `mbligh/apt`,
allows the R2 publisher to sparse-checkout `tools/g` from `master`.
The public Debian artifact intentionally exposes that file, but no other
part of the upstream private repository.

The R2 publisher stages the upstream file and a Debian version constructed
from the most recent `tools/g` commit timestamp and abbreviated SHA, then
runs the existing source-fingerprint planner. Changed content builds an
immutable package and is incorporated into signed APT indexes; unchanged
content is not rebuilt. A six-hour GitHub Actions schedule catches source
changes without any cross-repository write permission or manual APT commits.
The workflow also runs on APT source changes and manual dispatches, and tests
an installed `g mv` with a real Git staging area before publication.

Do not use `GITHUB_TOKEN` for cross-repository read access: it is scoped to
`mbligh/apt`. Do not commit the private key, and do not use a writable deploy
key. The publishing workflow intentionally fails when `TOOLS_DEPLOY_KEY`
is absent. Initial publication and end-to-end APT installation remain to be
verified once the user configures that key. The scheduled workflow may fail
if Actions is disabled or the private-source checkout loses access.
