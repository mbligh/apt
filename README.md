# mbligh Debian APT repository

Signed Debian 13 (trixie) packages for amd64, published using GitHub Pages.

See [project.md](project.md) for design decisions.

## Packages

- `deno`: upstream Deno 2.9.7, packaged as `2.9.7-1`
- `yt-dlp-sabr`: bashonly SABR fork, packaged as `2026.08.19.233452-1`, providing `/usr/bin/yt-dlp` and `/etc/yt-dlp.conf`

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
