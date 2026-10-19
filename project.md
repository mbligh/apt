# mbligh apt repository — project outline

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

A manifest-driven builder (`pypi-packages.txt`, `scripts/build-pypi-debs`) automatically generates architecture-independent `pypi-*` packages from pure-Python wheels and their resolved dependencies. Build-time pip runs only in GitHub Actions or a developer environment; installed systems need only APT and the system Python 3.13. Application imports are isolated under `/usr/lib/pypi-<name>`, and console-script wrappers are placed in `/usr/bin`. The builder targets Debian 13 and rejects native wheels, source distributions, and unsupported manifest syntax.

The publication workflow now includes the manifest and builder as triggers and imports generated debs into the existing signed archive. Validation and publishing are separate workflows; no unverified packages are intentionally deployed. Existing publication limitations remain: transitive dependencies are not locked, updates to a root package without a version bump can collide with archived bytes, command names may conflict, and no automatic service configuration or native-extension builds are attempted. Future work: lockfile with hashes, clean-install smoke tests, dependency metadata checks, command-conflict detection, automated Debian revisions, and optional architecture-specific builds.

