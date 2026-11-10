# mbligh/apt

Build and publish a signed Debian 13 (trixie) APT repository at apt.mbligh.org.

## Publishing design

The existing GitHub Pages publisher remains available during migration. The new manual `publish-r2.yml` workflow writes to the Cloudflare R2 bucket `mbligh-apt` using repository secrets `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, and the existing `APT_SIGNING_KEY`. The first publish migrates packages from the existing Pages endpoint (including historical versions). The domain should only be switched after verification.

A successful-publication fingerprint manifest in R2 controls which package definitions are rebuilt. Each new `.deb` is immutable at `pool/main/`. The publication index retains old versions, publishes SHA256 by-hash indexes, then signs and uploads `InRelease` last. Publication state updates last. Existing source builds and the optional PyPI pipeline are reused. After the R2 endpoint is confirmed operational, change the primary publisher from Pages to R2.

## Operations

Run `Publish APT repository to Cloudflare R2` manually to initialize R2. Verify the `dists/trixie/InRelease`, `Packages.gz`, and package downloads on the bucket's public test hostname before connecting `apt.mbligh.org`. Keep Pages enabled until then. Avoid running two R2 publishers concurrently.
