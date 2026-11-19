# mbligh Debian APT repository

Signed Debian 13 (trixie) packages for amd64, published to Cloudflare R2.

See [project.md](project.md) for design decisions.

## Current CI pipeline

Each package has **one** GitHub Actions job: build, verify, upload the GitHub artifact, then upload immutable `.deb` objects directly to R2. Already-indexed packages with an identical SHA-256 are no-ops; same-version/different-byte builds fail and require a revision bump.

New or recovered uploads are recorded in durable `pending/<run-id>.json` manifests in R2. The serialized `publish-r2.yml` consumes these manifests, verifies the referenced objects, **only** regenerates and signs APT metadata, and removes markers after publishing `InRelease`. A failed index can be retried manually with the original build run ID, or with a blank run ID to reconcile all pending uploads, without rebuilding or uploading `.deb` files.

The package job starts `publish-r2.yml` using `workflow_dispatch` **only after** `scripts/r2-publish stage` records at least one unindexed package. An unchanged build still succeeds and retains its GitHub artifact, but no index job starts. A failed upload or dispatch fails the package job. Pending R2 manifests survive interruptions and can be indexed manually; GitHub Actions no longer starts the publisher on every successful package workflow completion.

A green package build means **built and uploaded to R2**, not necessarily indexed. The signing secret is used only in the index publisher. R2 credentials are passed only to the upload step.

The legacy `publish-apt.yml` is a manual-only GitHub Pages fallback. The historical Pages-era notes below are superseded by this section.


## Packages

- `pypi-plexapi`: PlexAPI 4.18.3 (Debian revision `-3`), repackaged from PyPI as a Debian package using the per-package GitHub Actions workflow. Includes its pip-resolved dependencies and exposes `plexapi` to Debian's system Python via an opt-in `.pth` file. Install with `sudo apt install pypi-plexapi`, then `python3 -c 'from plexapi.server import PlexServer'`.

- `rtach`: persistent terminal sessions with scrollback replay, packaged as `0.2.0-3` from pinned upstream source with a local patch for executable argument forwarding. `rtach -A /tmp/session bash -l` now starts a login shell. Zig builds explicitly target generic x86-64 (not the native GitHub runner CPU) to avoid AVX-512 illegal instructions on Xeon E5 v4 hosts. The patch preserves the existing shell-integration behavior when no arguments follow the executable.

- `mbligh-tools`: architecture-independent `/usr/bin/g` Git convenience command, built from the private `mbligh/tools` repository's `tools/g`. The APT publisher reads only that file using an SSH deploy key; version numbers follow the latest source commit affecting `tools/g`. Install with `sudo apt install mbligh-tools`.

- `sfutils`: AMD Solarflare Linux Utilities 8.3.4.1000 (`SF-107601-LS`), converted from AMD's x86_64 RPM for Debian 13. Includes `sfupdate`, `sfboot`, `sfkey`, and `sfctool`. Firmware updates are **manual only**; installation does not flash the NIC. AMD upstream download is over HTTPS, with pinned SHA-256 `842bc13284a778c3be01af7e15cc106293d974b48ebcb4726120f9e8619c95c0`; public redistribution rights remain to be verified. See [AMD downloads](https://www.amd.com/en/support/downloads/solarflare-downloads.html/ethernet-adapters/solarflare/x2-series.html).

- `ytdl-sub`: upstream 2026.11.10.post2 standalone Linux amd64 binary, repackaged as `2026.11.10.post2-2`. Provides `ytdl-sub` for automated subscriptions and Plex/Jellyfin metadata; depends on FFmpeg and Debian's `ca-certificates`, and recommends Deno. Its launcher defaults `SSL_CERT_FILE` to `/etc/ssl/certs/ca-certificates.crt` (unless already set) so the bundled PyInstaller Python can verify HTTPS channel-artwork downloads. The upstream release is SHA-256 verified.

- `pmtiles`: upstream go-pmtiles v1.31.2 CLI, packaged for Debian amd64. Provides the full `pmtiles` command and all of its upstream subcommands, including `extract`, `show`, `verify`, `convert`, and `serve`. This is distinct from Tippecanoe's `tippecanoe-decode` (a separate upstream project).

- `imapsync`: upstream 2.314 Debian package, imported for copying selected IMAP folders between servers (such as Dovecot and Gmail). Install with `sudo apt install imapsync` after publication.

- `deno`: upstream Deno 2.9.7, packaged as `2.9.7-1`
- `nodejs24`: upstream Node.js 24.22.2 LTS runtime, parallel install as `/usr/bin/node24` (no npm; does not replace Debian's Node.js)
- `desktop-commander`: Remote Desktop Commander 0.3.1, packaged as `0.3.1-2` with a dependency on `nodejs24`
- `perccli`: Dell PERC CLI 7.1623.0.0, imported unchanged from GitHub release `perccli-7.1623` (SHA-256 verified). Provides PERC/HBA physical-drive and enclosure management, including locate LEDs. Dell proprietary software; verify distribution rights before public publication.
- `radarr`: upstream 6.4.4.10685, native systemd service (pending CI verification)
- `sonarr`: upstream 4.0.20.3014, native systemd service (pending CI verification)
- `yt-dlp-sabr`: bashonly SABR fork, packaged as `2026.08.19.233452-1`, providing `/usr/bin/yt-dlp` and `/etc/yt-dlp.conf`


- `mongodb-org-server`: MongoDB 9.0.4 amd64, imported unchanged from release `mongodb-9.0.4` (SHA-256 verified)
- `mongodb-database-tools`: 100.19.1 amd64 (database import/export and backup tools)
- `mongodb-atlas-cli`: 1.59.2 amd64 (Atlas administration CLI)
- `mongodb-compass`: 1.53.0-1~deb13 amd64 (desktop GUI; Debian 13 t64 dependency adjustments; release asset filename uses `1.53.0-1.deb13`)
- `mongodb-mongosh`: 2.13.0 amd64 (interactive shell)

The MongoDB importer requires all five original `.deb` assets in GitHub release `mongodb-9.0.4`, using their exact filenames. Publishing fails rather than silently omitting a missing asset. All SHA-256 hashes are pinned in `scripts/import-mongodb-release.sh`.

## Initial setup (repository owner)

1. Create a dedicated, passwordless *repository-only* OpenPGP signing key in an isolated GnuPG home. Keep its private key backed up securely, never in Git.
2. In GitHub repository **Settings → Secrets and variables → Actions**, create a secret named `APT_SIGNING_KEY` containing the ASCII-armored **private** key export. A passphrase-protected key needs an additional unattended signing mechanism; the current workflow expects an unencrypted CI-only key.
3. In **Settings → Pages**, choose **GitHub Actions** as the build and deployment source. If prompted, allow deployment to the `github-pages` environment.
4. In **Actions → Publish signed APT repository**, run the workflow manually.
5. Check the workflow output, published `InRelease`, and signing fingerprint.
6. Optionally set a custom domain `apt.mbligh.org` in Pages, add the DNS record GitHub recommends, and enable HTTPS. Until then, use the actual GitHub Pages URL.

Example key creation on a trusted machine (replace the UID):

```sh
export GNUPGHOME="$(mktemp -d)"
chmod 700 "$GNUPGHOME"
gpg --batch --pinentry-mode loopback --passphrase '' --quick-generate-key 'mbligh APT Archive <apt@mbligh.org>' ed25519 sign 0
gpg --armor --export-secret-keys > apt-signing-private.asc
gpg --armor --export > apt-signing-public.asc
gpg --with-colons --fingerprint
# Back up the private key securely, enter its ASCII armor as the GitHub Actions secret,
# and remove temporary unencrypted private-key files after setup.
```

**Security:** The archive signing private key is a deployment credential. A compromised repository workflow or GitHub Actions secret can compromise clients trusting this archive. Verify the public-key fingerprint independently before configuring clients.

## Client setup

After Pages is deployed, download the public key from the published repository URL, **verify its fingerprint against the original key**, then install it:

```sh
curl -fL https://apt.mbligh.org/mbligh-archive-keyring.gpg -o /tmp/mbligh-archive-keyring.gpg
gpg --show-keys --fingerprint /tmp/mbligh-archive-keyring.gpg
sudo install -m 644 /tmp/mbligh-archive-keyring.gpg /usr/share/keyrings/mbligh-archive-keyring.gpg
sudo tee /etc/apt/sources.list.d/mbligh.sources >/dev/null <<'EOF'
Types: deb
URIs: https://apt.mbligh.org
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/mbligh-archive-keyring.gpg
EOF
sudo apt update
apt-cache policy deno yt-dlp-sabr
```

Replace `https://apt.mbligh.org` with the actual Pages URL until custom-domain DNS is configured. Do **not** disable APT signature checks.

## Build and publication

`Build Debian packages` builds the two pinned packages as downloadable GitHub Actions artifacts. `Publish signed APT repository` independently rebuilds them, signs the repository metadata with `reprepro`, and deploys to Pages. Upstream release archives are SHA-256 checked.

**Current limitation:** Each publication builds a fresh archive containing the current versions only. Previous versions are not retained for rollback yet. Do not depend on historical versions remaining downloadable. The next improvement is persistent archive history and a reusable artifact-based publishing pipeline.

## Radarr and Sonarr (fresh installs)

Both packages create dedicated system users, share a `media` group, keep application state in `/var/lib/radarr` and `/var/lib/sonarr`, and provide native systemd units. Their upstream tarballs are pinned to release URLs and GitHub-published SHA-256 digests. The applications listen on their normal default ports (Radarr 7878, Sonarr 8989); restrict access using host firewall/network policy. Add the download client and media storage users to the `media` group and configure shared directory permissions separately. Application self-updates should be disabled in Settings once installed; upgrades must come from APT.

**Verification required:** confirm the new packages build and install successfully on Debian 13 amd64, including service start, upgrade, removal and purge, before using on a production host. The publishing workflow automatically builds all package scripts on push; a failure in any package prevents publication. Existing unrelated build failures can therefore block deployment.


## Automatically repackaging PyPI packages

Each PyPI package uses a committed `pypi-locks/<name>.txt` with the complete
wheel dependency closure, exact filenames and SHA-256 hashes. CI rejects
changed wheels instead of silently resolving different dependencies. The
builder runs Python 3.13 and pip 26.2.2, and verifies hashes during both
download and installation.

To refresh locks, pin the distribution version in `pypi-packages.txt` and
run **Generate PyPI wheel locks** (download its artifact), or locally:

```sh
python3.13 -m venv /tmp/pypi-packager
/tmp/pypi-packager/bin/pip install 'pip==26.2.2'
/tmp/pypi-packager/bin/python scripts/lock-pypi-wheels
```

Commit the resulting `pypi-locks/*.txt` and bump that package's Debian revision
in `pypi-revisions.txt` whenever its wheel lock or packaging changes. Existing
published Debian versions cannot be replaced with different bytes.


Edit [pypi-packages.txt](pypi-packages.txt) on `main` and add one PyPI distribution name per line, optionally pinned with `==`:

```text
httpie==3.2.4
```

On push, **Test PyPI Debian packages** checks the build and **Publish signed APT repository** rebuilds the packages and includes them in the signed archive. Packages are named `pypi-<normalized-name>`; commands exported by upstream `console_scripts` retain their original names. Empty/comment-only manifests produce no PyPI packages. A failed build prevents publication; check Actions logs. Publication still requires `APT_SIGNING_KEY` and configured Pages.

Build locally with Python 3.13, `pip`, and `dpkg-deb`:

```sh
python3.13 -m venv /tmp/pypi-packager
/tmp/pypi-packager/bin/python -m pip install -U pip
/tmp/pypi-packager/bin/python scripts/build-pypi-debs
```

Names in `pypi-exposed.txt` opt in to system-Python imports via `/usr/lib/python3/dist-packages/pypi-<name>.pth`. This is necessary for libraries without command-line entrypoints, such as `plexapi`; it also makes the package's bundled dependencies importable by other Python programs, so use this opt-in deliberately. All other PyPI packages retain their isolated import paths.

The packager accepts **only binary wheels** (pure Python or compatible Linux x86-64 wheels) throughout the dependency tree, producing `Architecture: all` or `amd64` packages as appropriate. It does not execute upstream installation hooks at package installation time, and installs private libraries in `/usr/lib/pypi-<name>`. It does not automatically create services, package native extensions, install `data_files` outside its private directory, or handle applications that require extra operating-system libraries. Command-name conflicts with other packages are not resolved automatically. Only install packages from publishers you trust: upstream code still executes when launched. Build isolation is not a security sandbox.

**Versioning:** The archive refuses to overwrite an existing Debian version with different bytes. Dependency versions and wheel SHA-256 hashes are locked; revisions are tracked in `pypi-revisions.txt` and must be bumped when the lock or packaging changes. The first locked revisions are `duckdb 2.0.0-3`, `roombapy-prime 0.7.1-3`, and `plexapi 4.18.3-3`. Automatic revision management is future work.

## Dell PERCCLI

`packages/perccli/build.sh` imports the [official Dell PERCCLI 7.1623 Debian package](https://github.com/mbligh/apt/releases/tag/perccli-7.1623) uploaded as a release asset. The SHA-256 is pinned to the digest reported by GitHub for the uploaded asset (`e46d955241c932023caf63862cd9dacb2b723b7f944340efb0e5afb6a2681e9d`). The original `.deb` is copied unchanged; the build checks its package name, version and architecture. The resulting executable is normally `/opt/MegaRAID/perccli/perccli64`.

```sh
sudo apt update
sudo apt install perccli
sudo /opt/MegaRAID/perccli/perccli64 /c0/eall/sall show
```

**Redistribution:** PERCCLI is proprietary Dell software. Public redistribution through GitHub Releases and Pages requires permission under Dell's applicable license; the repository has not independently verified those rights.

## Node.js 24 and Desktop Commander Remote MCP

`nodejs24` contains only the SHA-256-verified upstream Node.js 24.22.2 executable and license, installed at `/usr/lib/nodejs24/bin/node`, with `/usr/bin/node24` as its command. Debian's `/usr/bin/node` and system `nodejs` package are untouched. This package intentionally includes **no** npm or npx. It is currently amd64 only.

`desktop-commander` packages upstream `@wonderwhy-er/desktop-commander` version 0.3.1 as Debian version `0.3.1-2`. It depends on `nodejs24 (>= 24.22.2)`, so ordinary APT dependency resolution brings in the runtime. npm is used **only by the GitHub Actions build**, to bundle upstream dependencies; there are no npm commands at runtime or package installation.

```sh
sudo apt update
sudo apt install desktop-commander
node24 --version           # v24.22.2
# Start and pair the remote agent as an ordinary, unprivileged user:
desktop-commander remote
```

The agent is **not** enabled automatically as a privileged system service; it only runs when started. Pair it using upstream Desktop Commander instructions and stop it to disconnect. Remote execution passes through the vendor's cloud service, so give the user account only the permissions it needs.

`packages/nodejs24/build.sh` checks the official release SHA-256 `48cc0e21e048790e54c0cf5749c2725005313d652651c40b7a21feb9697aaf75`. CI builds both .debs, installs them and checks the selected Node version and Desktop Commander entrypoint syntax before publication. This is not a full remote pairing/integration test. Desktop Commander transitive npm dependencies are still resolved afresh in CI; a checked-in lockfile remains necessary for full reproducibility. Package publication is dependent on the existing signed archive workflow succeeding.

## mbligh-tools: private source, public Debian package

The `mbligh-tools` package currently contains only `g`, installed to
`/usr/bin/g`, with dependencies `git` and `python3`. Debian package names
use hyphens, not underscores. Machines need only the signed APT repository:
`sudo apt update && sudo apt install mbligh-tools`.

`mbligh/tools` is private and `mbligh/apt` is public. GitHub Actions'
default `GITHUB_TOKEN` cannot check out a private sibling repository.
Configure a **read-only deploy key** once:

1. On your own machine, run
   `ssh-keygen -t ed25519 -f ./mbligh-tools-deploy -N '' -C mbligh-apt-read-tools`
   in a private directory.
2. In **mbligh/tools → Settings → Deploy keys**, add the contents of
   `mbligh-tools-deploy.pub`. Leave **Allow write access** unchecked.
3. In **mbligh/apt → Settings → Secrets and variables → Actions**, create
   the repository secret `TOOLS_DEPLOY_KEY`, using the *entire private key*
   from `mbligh-tools-deploy` (not the `.pub` file).
4. Remove the local private-key copy securely after storing a separate
   protected backup, if desired. Never commit either secret to Git.

The active [R2 publishing workflow](.github/workflows/publish-r2.yml)
uses sparse checkout to obtain `tools/g`, then stages it *only inside the
ephemeral CI workspace*. The build script
[`packages/mbligh-tools/build.sh`](packages/mbligh-tools/build.sh)
creates an `Architecture: all` Debian package from that staged file.
The upstream file's last commit timestamp and SHA form the Debian version,
so unchanged sources keep a stable version. The existing R2 build manifest
detects changes to the staged source and only rebuilds the package when
needed. The publishing workflow runs on changes to the APT repo, manually,
and every six hours to discover changes to `tools/g`. Ordinary client
`apt upgrade` then installs newly published versions.

**Source visibility:** although the upstream repository remains private,
the installed Python script `g` is *not secret*: it is part of the publicly
downloadable `.deb`. No other files from `mbligh/tools` are packaged.

Until `TOOLS_DEPLOY_KEY` exists, the R2 publishing workflow deliberately
fails before attempting publication rather than shipping an outdated copy.
After configuring the deploy key, run
[Publish APT repository to Cloudflare R2](../../actions/workflows/publish-r2.yml)
manually to publish the first package. The workflow smoke-tests `g mv`
and native Git argument passthrough before publication. Do not consider the
package published until that run succeeds.
