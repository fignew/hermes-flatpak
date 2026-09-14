# Hermes Flatpak

Daily-built Flatpak packages of [Hermes Desktop](https://github.com/NousResearch/hermes-agent)
(`dev.nousresearch.hermes`), tracked from upstream `main` and published release
tags, for both x86_64 and aarch64.

## Install

**Nightly (tracked from upstream `main`, rebuilt daily):**

1. Grab the bundle matching your arch from the
   [nightly release](https://github.com/fignew/hermes-flatpak/releases/tag/nightly):
   - `Hermes-<ver>-x86_64.flatpak`
   - `Hermes-<ver>-aarch64.flatpak`
2. Install:
   ```sh
   flatpak install --user ./Hermes-<ver>-x86_64.flatpak
   ```

**Release builds** (matching upstream release tags): see the
[releases page](https://github.com/fignew/hermes-flatpak/releases) for
tagged builds.

## Sandbox / permissions

This flatpak uses Flathub-style least-privilege grants (deliberately **no**
`--filesystem=home`):

```text
network — LLM API + gateway + updates (agent core requirement)
wayland, x11 — windowing
pulseaudio — voice conversations
dri — GPU acceleration
xdg-download — file handoff; everything else goes through portals
org.freedesktop.Notifications — desktop notifications
org.a11y.Bus — accessibility (computer-use element targeting)
```

All user data lives under `~/.var/app/dev.nousresearch.hermes/data/` and is
persistent across rebuilds. See `packaging/dev.nousresearch.hermes.yml`
(`finish-args`) for the full list.

## Bundled contents

The agent backend ships inside the flatpak at `/app/lib/hermes-agent`
(venv pre-synced with `uv sync --locked --extra all` at build time) so
first-run needs no network install. Bundled tools: git 2.55.0, ripgrep 14.1.1
(x86_64 only), cua-driver 0.23.2 (x86_64 only — computer-use via
Wayland/libei portal).

## CI

- **Daily bleeding edge** — `.github/workflows/flatter.yml` at 04:37 UTC:
  resolves `main` to its newest commit, builds both arches via
  [flatter](https://github.com/andyholmes/flatter), smoke-tests bundles, and
  overwrites the **`nightly`** release. Bundles also land as 7-day artifacts.
- **Release builds** — `.github/workflows/flatter-release.yml`, dispatched
  automatically by `upstream-watch.yml` when a new upstream tagged release
  appears (or run manually with `tag=<vX.Y.Z>`).
- Generated manifest: `packaging/generate-manifest.py` substitutes
  `HERMES_REF` into the template at build time; other package pins (uv,
  ripgrep, git, cua-driver) are hard-pinned with SHA256 in the manifest and
  committed separately from the agent version.

## Flathub note

This repo is NOT Flathub. Flathub submission for Hermes is on hold pending
maintainer permission from Nous Research — if that happens, this manifest is
already Flathub-shaped (remote sources, standard app-id, minimal finish-args).

## Local rebuild

The manifest in `packaging/` builds anywhere with `flatpak-builder`:

```sh
flatpak-builder --force-clean --disable-rofiles-fuse \
  --repo=repo _build packaging/dev.nousresearch.hermes.yml
# (requires HERMES_REF set, or replace __HERMES_REF__ in the template first)
```

The original local-source variant (with a checked-out `hermes-agent-src/`)
still lives in git history; this tree's CI switched fully to remote sources.

## License

MIT (packaging). Hermes Agent is a separate project under
[NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent).
