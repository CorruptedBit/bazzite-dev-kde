# bazzite-dev-kde

A personal [bootc](https://github.com/bootc-dev/bootc) image based on [Bazzite](https://github.com/ublue-os/bazzite-deck:stable) (KDE Plasma spin), customized with development tooling on top of the stock gaming image.

Published at: `ghcr.io/corruptedbit/bazzite-dev-kde`

## What's in the image

On top of the Bazzite KDE base, this image adds:

- **Visual Studio Code** (from Microsoft's official repo)
- **Zed** editor (via the [Terra](https://terra.fyi/) repo, enabled only during the build)
- **Custom Nerd Fonts**: [CascadiaCode](https://github.com/microsoft/cascadia-code) and FantasqueSansMono, copied into `/usr/share/fonts` and registered with `fc-cache`
- Custom `ujust` recipes (`system_files/usr/ublue-os/just/60-custom.just`):
  - `ujust install-dev-tools` — Claude Code, starship, git-graph, zellij (via Homebrew)
  - `ujust enable-starship` — wires up starship in `~/.bashrc`
  - `ujust install-utilities` — chezmoi, yt-dlp, htop, cmatrix (Homebrew) + Gear Lever, Bitwarden (Flatpak)
- **Custom wallpaper** ("Rancho") under `/usr/share/wallpapers`

All package installation logic lives in [`build_files/build.sh`](./build_files/build.sh), which is invoked from the [`Containerfile`](./Containerfile) during the image build.

## Switching to this image

From a system already running a bootc image (Bazzite, Bluefin, Aurora, Fedora Atomic, ...):

```bash
sudo bootc switch ghcr.io/corruptedbit/bazzite-dev-kde:latest
```

Reboot to apply.

## Repository layout

- **`Containerfile`** — entrypoint for the image build. Pulls in `build_files/` and `system_files/` via a `FROM scratch` context stage (`ctx`), then runs `build.sh` against the Bazzite base image.
- **`build_files/build.sh`** — installs packages, copies `system_files/` into the image root, enables `podman.socket`.
- **`system_files/`** — mirrors the final image's root filesystem (fonts, wallpaper, custom `ujust` recipes). Its contents are merged into `/` by `build.sh`, not by a separate `COPY` in the `Containerfile`.
- **`image-template.env`** — build metadata (`IMAGE_NAME`, `REPO_ORGANIZATION`, description, keywords, default tag, BIB image), loaded by the `Justfile` via `set dotenv-filename`.
- **`Justfile`** — local build/test commands (see below).
- **`disk_config/`** — `bootc-image-builder` configs:
  - `disk.toml` — for `qcow2`/`raw` VM images (20 GiB filesystem minimum).
  - `iso.toml` — for the bare-metal/VM installer ISO. Its kickstart `%post` runs `bootc switch` to this image's `ghcr.io` tag once Anaconda finishes installing the base OS. Note: `bootc-image-builder`'s `anaconda-iso` type **always partitions automatically** ("installs to the first disk found") regardless of which Anaconda modules are enabled — only steps like user creation can be made interactive (kept on, here, via the `Users` module). It is **not** a fully interactive installer like the official Fedora/Bazzite media.
  - `iso-kde.toml` / `iso-gnome.toml` — reference variants kept for comparison; `iso.toml` is the one actually used by the workflow and is based on the KDE variant (GNOME's disables more Anaconda modules, relying on `gnome-initial-setup` post-install instead — not applicable here).

## GitHub Actions

- **`build.yml`** — builds the OCI image and pushes it to GHCR. **Automatic triggers (`push` to `main`, daily cron) are currently commented out** — see "Disk space on GitHub-hosted runners" below for why. Only `pull_request` (build-only, no push) and `workflow_dispatch` (manual run) remain active. The image is built and pushed locally instead (see below); uncomment the `push`/`schedule` blocks in `build.yml` if you want automatic CI builds back.
- **`build-disk.yml`** — manual workflow (`workflow_dispatch`) that turns the published OCI image into a `qcow2` and an `anaconda-iso` via `bootc-image-builder`, uploading the result as a job artifact (or to S3, if configured).

### Disk space on GitHub-hosted runners

The combination of a large base image (Bazzite) plus extra packages exceeds the ~14 GB free on a standard GitHub-hosted runner during the rechunk step, which needs to materialize the uncompressed ~11-12 GB rootfs multiple times at once (existing image + chunker image + temporary ostree repo + newly encapsulated blobs). In practice this adds up to ~40 GB+ of simultaneous disk usage, which doesn't fit even after `remove-swapfile: true` and `ublue-os/remove-unwanted-software` reclaim their usual ~50 GB ceiling.

Rather than chase this further on GitHub's free runners (splitting into two jobs, paid larger runners, etc.), the simplest fix for personal use is what's described below: build and push from a local machine, which has no such ceiling.

## Building and pushing locally

This is the primary way this image gets built and published, now that automatic CI builds are disabled.

Requires [`just`](https://just.systems/) and `podman` (both ship by default on Bazzite).

```bash
# Build the image
just build bazzite-dev-kde latest

# Optional: rechunk for smaller incremental updates
sudo just ostree-rechunk bazzite-dev-kde latest

# Push to GHCR
podman login ghcr.io -u corruptedbit
podman push localhost/bazzite-dev-kde:latest ghcr.io/corruptedbit/bazzite-dev-kde:latest
```

### Building a VM image or ISO

```bash
# QCOW2 for a VM
just build-qcow2 bazzite-dev-kde latest

# Bare-metal/VM installer ISO (points at the local build by default;
# pass a ghcr.io/... reference to build straight from the published image)
just build-iso bazzite-dev-kde latest
```

Note: at the time of writing, `build-iso` passes `--type iso` to `bootc-image-builder`, while current upstream docs list `anaconda-iso` (used by `build-disk.yml`) as the valid type — worth double-checking if this recipe errors out.

## Container signing

Builds are signed with [cosign](https://docs.sigstore.dev/cosign/overview/); the private key is stored as the `SIGNING_SECRET` repository secret, the public key is committed as `cosign.pub`.

## Credit

This repository started from [ublue-os/image-template](https://github.com/ublue-os/image-template). A copy of the original template README is kept at [`README-ublue.md`](./README-ublue.md) for reference on generic bootc-image-template usage (cosign setup, ArtifactHub indexing, full `Justfile` recipe reference, etc.).
