# mbligh apt repository — project outline

## ytdl-sub package

Repackage the upstream self-contained Linux amd64 executable with a pinned release and GitHub-published SHA-256. Version `2026.11.26-1` bundles yt-dlp `2026.11.23`, which fixes the November 23 YouTube n-challenge regression (yt-dlp #18123). The embedded yt-dlp is independent of the standalone yt-dlp-sabr package. Keep the existing CA trust wrapper and Debian installation smoke test. Release discovery remains manual; update the version and digest together to publish new upstream releases.

## Agentify Desktop 0.2.4 package

Packages upstream Agentify Desktop from the exact release-commit pin in
`packages/agentify-desktop/version`. There are no Linux release binaries.
The CI build uses `npm ci --omit=dev --ignore-scripts` against upstream's
integrity-checked lockfile, then installs the matching Electron binary.
It bundles the source app, production dependencies and Electron under
`/usr/lib/agentify-desktop`. Launchers in `/usr/bin` call the existing
`nodejs24` package; no npm/npx is required on installed hosts.
Electron's sandbox helper retains setuid mode, rather than disabling sandbox.

The package has its own version preflight to skip unchanged published builds,
and uses the shared Debian 13 smoke tests and immutable R2 publisher. A
Debian revision bump is required whenever packaging contents change.
A push that only changes workflow infrastructure skips an already-published
Agentify version successfully; the preflight checks the full push diff for
changes under `packages/agentify-desktop/` before requiring a revision bump.
A corrupt downloaded package index fails preflight instead of causing a rebuild.

A graphical desktop session is needed for the browser. OpenCode should be
configured to invoke `agentify-desktop mcp` over stdio on the same machine.
Upstream code is MPL-2.0; upstream TRADEMARKS.md reserves product branding.
This is an unofficial repackage and does not imply upstream endorsement.


## OpenCode CLI v2 packaging (no npm)

Package the official OpenCode v2 Linux glibc x86-64 **baseline** CLI binary,
not the desktop application and not an npm package. Pin the upstream release
version, GitHub-published SHA-256 digest and release timestamp in
`packages/opencode/version`; fetch the exact tarball by version and
verify it before extracting the single executable. Install the bundled-runtime
binary at `/usr/bin/opencode` and the upstream MIT license under
`/usr/share/doc/opencode`. No npm, Node.js, Bun, or other
JavaScript build step is involved.

Normalize package file timestamps and use SOURCE_DATE_EPOCH to keep the
same version/revision byte-for-byte reproducible. The separate
`package-opencode.yml` workflow checks the published APT index
before retrieving the 130 MB upstream archive; manual rebuilds skip an
already-indexed version, and a packaging change with an already published
version fails until REVISION is bumped. The reusable build job smoke-tests
installation, `--version`, and `--help` in a clean Debian 13
container and checks that npm, Node.js and Bun are not package dependencies.
Successful builds use the existing immutable R2 staging and signed-index path.


## cfsolve and cf-curl Debian 13 package (November 2026)

`packages/cfsolve/build.sh` repackages the immutable `challenge` executable
and browser profile tree from the public `mbligh/cfsolve` Debian 13 GitHub
Release, together with `video/cf-curl` checked out from private `mbligh/tools`
using the pre-existing read-only `TOOLS_DEPLOY_KEY`. Installs
`/usr/bin/cfsolve`, its `/usr/bin/challenge` symlink, `/usr/bin/cf-curl`,
and full `/usr/share/cfsolve/profiles`. The wrapper now prefers this Debian
profile path while retaining its `/usr/local` and source-checkout options.

Binary release archive and SHA256SUMS are verified against GitHub release asset
digests. Package versions contain the most recent source timestamp and both
source commit identifiers; packaging-only changes require incrementing the
Debian revision. The standard one-package workflow builds, validates clean
Debian 13 installation, stages to R2 and triggers signing/indexing only when
there is a new package. See `packages/cfsolve/README.md`.
No Rust toolchain or build container is required on installed hosts.

## Patched jellyfin-web (12.4) packaging

`packages/jellyfin-web/build.sh` fetches a pinned commit of the
`mbligh-v12.4` branch in `mbligh/jellyfin-web`, verifies the checkout,
builds with Node 24/npm and TypeScript checks in GitHub Actions, and packages
only `dist/` as an `Architecture: all` replacement for Debian's
`jellyfin-web`. Runtime has no Node/npm dependencies. The Debian version
includes the patch commit timestamp and abbreviated SHA, sorts above
`12.4+deb13` and below an upstream 12.5 release. The installed path and
`config.json` conffile match the official Debian package. The fork now
uses portrait series/movie posters for Next Up and Continue Watching, and
16:9 episode artwork in season lists. The episode-image preference
still switches the home-page cards back to landscape thumbnails.

The per-package `package-jellyfin-web.yml` workflow invokes the common
build/validation/stage job, uploads the immutable .deb directly to Cloudflare
R2, and requests the existing signing/index workflow. Edit the pinned SHA to
build a new fork revision. No fork-side secrets or cross-repository deployment
tokens are needed. The APT workflow runs on recipe changes or manual dispatch;
fork source commits alone do not trigger a new APT build.

When the BBC provides a DASH `SegmentTimeline` without a constant `@duration` on `SegmentTemplate`, get_iplayer 3.36 can divide by zero while enumerating streams. The local patch guards absent or zero `@duration` / `@timescale` values and skips that manifest, allowing other CDNs or stream formats to be tried. This avoids globally excluding DASH and deliberately does **not** implement full `SegmentTimeline` support. See [upstream issue #524](https://github.com/get-iplayer/get_iplayer/issues/524). CI verifies installed Perl syntax and the patched guard on Debian 13.

## Active build/publishing architecture (November 2026)
## get-iplayer package

Import the openSUSE Build Service `home:m-grant-prg` Debian 13 package `get-iplayer_3.36-1+deb13u3_all.deb` as version `3.36-1+deb13u3+mbligh2`. Its `mgrant-obs-deb-keyring` dependency refers to the upstream OBS repository and is removed in the local package; mbligh's signed APT repository does not require trusting that unrelated key. Keep all application files and other dependencies unchanged. Normalize archive timestamps and owners for repeatable builds. Source URL: `https://download.opensuse.org/repositories/home:/m-grant-prg/Debian_13/all/get-iplayer_3.36-1+deb13u3_all.deb`. Pin its openSUSE-published SHA-256 (`35e7c205cdf0b2dd0d9b1b6affbda67596a9a014660301b56197393c85b8e2bf`), verify the Debian package name, version and architecture, and validate clean installation plus `get_iplayer --version` on Debian 13 before uploading through the standard R2 staging/signing pipeline. The upstream package is third-party, not an official Debian package; moving to another upstream release requires explicitly updating the version and digest. No automatic periodic update is configured.


The repository is served from **Cloudflare R2** at `https://apt.mbligh.org` (Debian 13/trixie, amd64 and all).

The shared Ubuntu 24.04 build job installs its packaging prerequisites using only the runner's official Ubuntu APT sources (`/etc/apt/sources.list.d/ubuntu.sources`), with three download retries and strict update-error handling. Unrelated preconfigured third-party repositories cannot block this setup; APT signature verification remains enabled. This runner-only change does not change Debian package contents or revisions.

Each package has **one** GitHub Actions job: build, verify, upload the GitHub artifact, then upload immutable `.deb` objects directly to R2. Already-indexed packages with an identical SHA-256 are no-ops; same-version/different-byte builds fail and require a revision bump.

New or recovered uploads are recorded in durable `pending/<run-id>.json` manifests in R2. The serialized `publish-r2.yml` consumes these manifests, verifies the referenced objects, **only** regenerates and signs APT metadata, and removes markers after publishing `InRelease`. A failed index can be retried manually with the original build run ID, or with a blank run ID to reconcile all pending uploads, without rebuilding or uploading `.deb` files.

The package job starts `publish-r2.yml` using `workflow_dispatch` **only after** `scripts/r2-publish stage` records at least one unindexed package. An unchanged build still succeeds and retains its GitHub artifact, but no index job starts. A failed upload or dispatch fails the package job. Pending R2 manifests survive interruptions and can be indexed manually; GitHub Actions no longer starts the publisher on every successful package workflow completion.

A green package build means **built and uploaded to R2**, not necessarily indexed. The signing secret is used only in the index publisher. R2 credentials are passed only to the upload step.

Each current PyPI distribution gets a distinct trigger; `scripts/build-pypi-debs --package <normalized-name>` builds only that entry. Roots are pinned in `pypi-packages.txt`, wheel closures and hashes are locked under `pypi-locks/`, and Debian revisions are maintained in `pypi-revisions.txt`. Python 3.13 and pip 26.2.2 are used for lock generation and Debian builds. Native-wheel architecture fixes and lock adoption use `-3` revisions for duckdb, roombapy-prime, and plexapi. `pypi-plexapi` packages pinned PyPI `plexapi==4.18.3` and uses `pypi-exposed.txt` to opt in to normal Debian system-Python imports, validated by an install/import smoke test in Debian trixie. Opting in places bundled dependencies on sys.path, so other PyPI packages remain isolated by default. The legacy Pages publisher is manual fallback. Previous project phases below contain historical Pages plans rather than the active architecture.

The scheduled `mbligh-tools` and `yt-dlp-sabr` builds now use upstream-derived `SOURCE_DATE_EPOCH` to produce repeatable Debian archive timestamps. Both use Debian revision `-2` to avoid collisions with previously published `-1` packages. `yt-dlp-sabr` also includes the zero-padded GitHub asset ID in its version so a moving release tag that replaces a binary cannot silently reuse a version. Identical scheduled rebuilds should become no-ops, while genuine upstream updates remain publishable. R2's immutable-version hash checks remain mandatory.

The rtach Debian package applies `packages/rtach/pass-command-arguments.patch` to upstream commit `372fefbaa051e240f3923bad480294a4f65718b7`. This propagates additional executable arguments through both the normal master and the macOS spawnd launch path. The package increments its Debian revision to `0.2.0-3` and tests `sh -c`, `bash -l -c`, and interactive `-A` attachment. Builds explicitly set `-Dtarget=x86_64-linux-gnu -Dcpu=baseline` to prevent AVX-512 native-runner instructions from crashing older Xeon processors. Existing default shell integration remains enabled when no explicit arguments are supplied.

PyPI workflows now perform a cheap published-version preflight before any dependency installation or wheel download, skipping already-published pinned versions. The scheduled DuckDB rebuild was removed because it never discovered upstream releases. A push that changes wheel locks, the PyPI builder, or exposed-import membership without moving the upstream pin must increase the respective Debian revision; failing to do so stops in preflight. The PyPI builder now pins outer Debian archive timestamps through `SOURCE_DATE_EPOCH`, with the three existing `-3` revisions advanced to `-4`. The all-packages PyPI test workflow remains manually runnable but no longer repeats all builds on every push. Upstream release discovery and lock updates are still explicit/manual.

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
