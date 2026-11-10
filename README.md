# mbligh Debian APT repository

Signed Debian 13 (trixie) packages for amd64, published using GitHub Pages.

See [project.md](project.md) for design decisions.

## Packages

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

The packager accepts **only pure-Python wheels throughout the dependency tree**, does not execute upstream installation hooks at package installation time, and installs private libraries in `/usr/lib/pypi-<name>`. It does not automatically create services, package native extensions, install `data_files` outside its private directory, or handle applications that require extra operating-system libraries. Command-name conflicts with other packages are not resolved automatically. Only install packages from publishers you trust: upstream code still executes when launched. Build isolation is not a security sandbox.

**Versioning:** The archive refuses to overwrite an existing Debian version with different bytes. A changed transitive dependency without a changed root package version will cause a publish failure; pinning root versions alone does not lock the dependency tree. A lockfile and automatic Debian revision management are future improvements. The workflow currently rebuilds every listed package on publication rather than only the changed entry.

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
