# AGENTS.md — Hermes Desktop Flatpak Packaging

Instructions for AI agents working in this tree. Read fully before changing anything.

## What this is

Flatpak packaging for Hermes Desktop (NousResearch/hermes-agent monorepo, apps/desktop
+ bundled agent backend). Final deliverable: a single-file `.flatpak` bundle installable
on any distro.

- App id: `dev.nousresearch.hermes`
- Version: **always the agent's version** from `hermes-agent/pyproject.toml` (0.21.0 as
  of this writing) — NOT the desktop npm version (0.17.0, internal, lags). Derived at
  build time into the metainfo; bundle filename must match.
- Bundle output: `Hermes-<ver>-x86_64.flatpak` (here; ~337 MB)

## Environment

- Build host: `f44.incus` Fedora 44 VM, 1 core / 5 GB RAM / 25 GB disk, user `thomas`,
  NOPASSWD sudo. This tree lives at `/srv/flatpak/build` — **never under /home** (mode-700
  parent breaks flatpak-builder's bwrap with EACCES even as root).
- This directory is a **git repo**. Commit BEFORE and AFTER every change/build. No
  exceptions. The docker feature (v10) and its revert (v11) are in history as
  `cf2dc85` / `31127ec` — reference, don't re-derive.
- Flathub remote is added to the SYSTEM installation; use `sudo flatpak` consistently
  (mixing system/user installs → `fchownat: Operation not permitted`; polkit blocks
  user system-ops on this headless VM).
- Runtimes installed: freedesktop 25.08 Sdk+Platform, Electron2.BaseApp 25.08,
  Sdk.Extension.node22 25.08. (24.08 also present; legacy.)

## Build (always in this order)

```sh
cd /srv/flatpak/build
sudo umount state/rofiles/* 2>/dev/null
sudo flatpak-builder --force-clean --disable-rofiles-fuse \
  --repo=repo --state-dir=state build-dir dev.nousresearch.hermes.yml
sudo flatpak build-update-repo repo
rm -f Hermes-*.flatpak
sudo flatpak build-bundle --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo \
  repo Hermes-0.21.0-x86_64.flatpak dev.nousresearch.hermes master
sudo chown thomas:thomas Hermes-0.21.0-x86_64.flatpak
sha256sum Hermes-0.21.0-x86_64.flatpak   # report this to the user
sudo flatpak install -y --noninteractive --or-update ./Hermes-0.21.0-x86_64.flatpak
```

Use `if/then/else` or `&&` discipline — never `;`-chain the bundle step after the build:
a failed build MUST NOT produce a bundle (that silently ships stale content; happened
once when GitHub 429'd the source fetch).

Full build ≈ 60-75 min on this 1-core VM (git ~10 min, npm ci + vite + electron-builder
~20 min, strip/debuginfo + commit ~15 min, bundle ~15-20 min). Run in background and
poll `tail /tmp/fb-*.log`; don't kill mid-build (stale rofiles-fuse mounts block the
next run — umount them first).

## Tree contents (tracked by git)

- `dev.nousresearch.hermes.yml` — the manifest. Modules: git 2.55.0 (NO_RUST=1 — the
  Sdk has no cargo; git ≥2.55 has optional Rust), ripgrep 14.1.1 (static musl, for the
  agent's fast search), hermes-desktop (in-sandbox: uv sync of agent venv + npm build
  of desktop payload + install of wrappers/metadata/icons).
- `hermes.sh` — desktop launcher. Sets OZONE hint, HERMES_DESKTOP_HERMES_ROOT,
  HERMES_HOME, cua-driver persistence redirects, window identity flags.
- `hermes-cli.sh` — `hermes` CLI shim into the bundled venv.
- `dev.nousresearch.hermes.desktop`, `.metainfo.xml` (has @AGENT_VERSION@ placeholders —
  filled by the build script), `.png` (512/256 icons).
- `hermes-agent-src/` — local clean clone at the pinned commit (source for the build;
  gitignored). Bump by re-cloning + updating the commit in commit messages, and
  re-verify `git -C hermes-agent-src log -1`. A remote `type: git` source works but
  re-fetches GitHub on every build (429 risk → stale-bundle trap above).
- `pinned/` — downloaded pinned tarballs (uv, docker-cli, ripgrep) with checksums.

## Load-bearing design decisions (do not undo casually)

1. **Bundled backend** — the agent ships inside the flatpak at `/app/lib/hermes-agent`
   (repo + `.venv` from `uv sync --locked --extra all`). The wrapper sets
   `HERMES_DESKTOP_HERMES_ROOT=/app/lib/hermes-agent`; the desktop's resolver
   (electron/main.ts `resolveHermesBackend` step 1) adopts it with `bootstrap: false`.
   This killed the runtime-bootstrap failure mode (installer hard-needs git; runtime
   has none). Alternative designs (host toolchains, runtime clone) were tried and
   rejected — see git history and skill notes.
2. **In-sandbox payload build** — node-pty must link against the RUNTIME's glibc.
   Host-built .node files need host glibc (Fedora 44 = 2.42 > runtime 25.08 = 2.41)
   and fail in-sandbox with a misleading "Cannot find module" (node-pty eats the real
   dlopen error). `npm_config_nodedir=/usr/lib/sdk/node22` is required: node-gyp's
   downloaded headers tarball hits `TAR_ENTRY_ERROR EINVAL: fchown` as root in bwrap.
3. **Persistence** — the sandbox home is ephemeral; ONLY `$XDG_DATA_HOME`
   (`~/.var/app/<id>/data` on host) survives. `HERMES_HOME` is redirected there;
   `~/.cua-driver` and `~/.local/bin` are symlinked there (recreated each launch).
   Any new "agent writes to ~" path needs the same treatment.
4. **Window identity** — Electron derives app_id from the npm name (`hermes`), which
   matches no desktop file → letter-fallback icons in dock/launchers. Wrapper forces
   `--wayland-app-id`/`--class` = app id; `StartupWMClass` in the desktop file matches.
5. **Permissions are minimal** — network, wayland+x11, pulseaudio (voice), dri,
   xdg-download, org.freedesktop.Notifications talk. NO --filesystem=home. Portals
   cover the rest (computer-use works via libei/RemoteDesktop portal — needs no grant).
   Docker/podman was deliberately reverted (v11): containers can't run inside a flatpak
   (userns blocked); host-socket architecture is documented in the skill reference if
   ever re-requested.

## Verification before declaring a build good

1. sha256sum of the bundle (report it).
2. `flatpak install --or-update` succeeds.
3. `flatpak info -m` shows expected runtime + finish-args.
4. In-sandbox probes: `flatpak build build-dir hermes --version` (agent version),
   `rg --version`, `git --version`.
5. Launch test under Xvfb (window maps ~45-60 s on this VM):
   ```sh
   Xvfb :99 -screen 0 1280x800x24 -ac & sleep 2
   timeout 90 flatpak run dev.nousresearch.hermes >/tmp/run.log 2>&1
   ```
   Check log for `install stamp` (real commit, not zeros) and absence of
   "bootstrap failed"/"prerequisites". Screenshot: `import -display :99 -window root`
   (xwd is not packaged in Fedora 44) + `convert -format %k` for color count; OCR via
   tesseract for text.
6. Persistence: kill the app, confirm `~/.var/app/dev.nousresearch.hermes/data/hermes/`
   still has `state.db` etc.

Known-cosmetic log noise (NOT bugs): dbus system-bus "connection refused" (sandbox has
no system bus), vaapi/libva failure on virtio GPU, `xdg-settings` execvp warning,
xkbcomp warnings from Xvfb, first-launch "Timed out connecting to backend" on a 1-core
VM under load.

## Gotchas (each one cost real time once)

- flatpak-builder 1.4.x: `--share=network` is manifest `build-options.build-args`,
  NOT a CLI flag ("Unknown option").
- Each build-command element runs in its own bwrap; only `/app` and
  `/run/build/<module>` persist. Multi-step work = ONE `|` block with `set -e`.
- `type: dir` sources check out the directory's CONTENTS at `dest` (double-nesting
  trap). Archive sources: flatpak-builder strips the top-level dir unless
  `strip-components: 0` (uv landed at `uv-dist/uv`, not `uv-dist/<triplet>/uv`).
- `npm ci` for the desktop must run from the REPO ROOT (workspaces live there).
- build-bundle is single-threaded ostree packing: 15-25 min here. Timeouts surface as
  silent exit 255 — check for partial bundle files.
- Backgrounded npm output is buffered; verify on disk, not via logs.
- Installing packages inside a chain that then launches the app: the `&&` from dnf
  swallows the rest — install first, test in a separate command.

## Update procedure (new upstream release)

1. Re-clone `hermes-agent-src` at the new pinned commit; confirm version in
   pyproject.toml; note it (bundle filename + metainfo derive automatically).
2. Check `flatpak remote-ls flathub | grep Electron2.BaseApp` — if a newer runtime
   branch's BaseApp exists (e.g. 26.08), consider bumping runtime-version/base-version
   (2 lines). 26.08 was blocked as of 2026-09-05 (no BaseApp branch yet).
3. Commit, build, verify per checklist, deliver bundle + sha to the user.

## Known open items

- Runtime 26.08 bump (blocked on Electron2.BaseApp branch; check periodically).
- sqlite 3.50.4 in 25.08 still trips the doctor WAL-reset warning (needs 3.50.7+;
  user DBs use rollback journal — practical risk nil).
- True background operation (windowless agent) needs upstream to implement the
  XDG Background portal request + close-to-tray; nothing to grant from the manifest.
- docker compose plugin: not bundled; Hermes code paths don't use it today.
- cua-driver inside the sandbox: install persists (v12), portal/libei path expected
  to work on GNOME/KDE Wayland; untested end-to-end — X11 fallback is dead in-sandbox
  (no host X server), libei/portal is the correct Wayland path.

## Where the deeper documentation lives

- Flatpak-packaging skill (on the Hermes host):
  `/var/lib/hermes/.hermes/skills/software-development/flatpak-packaging/` —
  `references/hermes-flatpak-build.md` (full session log + every gotcha),
  `references/manifest-template.md` (generalized template + dest semantics).
- Upstream app behavior: `hermes-agent-src/apps/desktop/electron/main.ts`
  (backend resolver ~line 4880, notifications ~line 16550, HERMES_HOME ~line 770).
