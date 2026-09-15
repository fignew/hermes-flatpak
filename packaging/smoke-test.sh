#!/usr/bin/env bash
# Smoke-test a built Hermes flatpak bundle from CI (Linux).
#
# Installs the bundle into a user-local flatpak on the runner, then runs the
# core checks from AGENTS.md's verification checklist. Full Xvfb launch test
# is skipped (needs real display/audio/dbus); these in-sandbox checks instead
# cover the failure modes that actually bite this package — version drift,
# missing bundled tools, broken venv.
#
# Usage: smoke-test.sh <path-to-bundle.flatpak>
set -euo pipefail

BUNDLE="$1"
[ -f "$BUNDLE" ] || { echo "FAIL(1): bundle not found: $BUNDLE"; exit 1; }

APP_ID=dev.nousresearch.hermes
fail() { echo "FAIL: $*"; exit 1; }

# Install the bundle user-locally. No remote add needed — the bundle carries
# the app AND (with --runtime-repo pointing at flathub flatpakrepo) enough
# metadata to resolve the runtime from flathub; the flatter flathub remote
# added at build time is present in the image's flatpak config, so runtime
# resolution succeeds without extra setup.
echo "-- installing bundle (user installation) --"
flatpak install -y --user --noninteractive "$BUNDLE" 2>&1 | tail -20 || \
    fail "could not install bundle"
echo "OK: installed bundle"

# App ref should now exist for the right arch.
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  FP_ARCH=x86_64 ;;
    aarch64) FP_ARCH=aarch64 ;;
    *) fail "unsupported arch: $ARCH" ;;
esac

echo "-- flatpak info --"
flatpak info "$APP_ID" 2>&1 | head -30
flatpak info --show-metadata "$APP_ID" > /tmp/metainfo.xml 2>/dev/null || \
    fail "could not read installed metadata"
# `flatpak info --show-metadata` prints the deployment XML; the runtime lives
# under <metadata key="runtime">org.freedesktop.Platform/<arch>/25.08</metadata>.
grep -q "org.freedesktop.Platform/${FP_ARCH}/25.08" /tmp/metainfo.xml \
    || fail "runtime is not the expected freedesktop 25.08 for ${FP_ARCH}"
grep -q 'org.electronjs.Electron2.BaseApp' /tmp/metainfo.xml \
    || fail "BaseApp not declared in metadata"
echo "OK: metadata has freedesktop 25.08 runtime + Electron2 BaseApp"

# In-sandbox probes: each bundled binary must answer --version via flatpak run.
echo "-- in-sandbox probes --"
VER=$(flatpak run --command=hermes "$APP_ID" --version 2>&1) || fail "hermes --version: $VER"
echo "OK: hermes $VER"

if [ "$FP_ARCH" = "x86_64" ]; then
    RGV=$(flatpak run --command=rg "$APP_ID" --version 2>&1) || fail "rg --version: $RGV"
    echo "OK: $RGV"
else
    echo "SKIP: rg (no aarch64 musl build bundled)"
fi

GTV=$(flatpak run --command=git "$APP_ID" --version 2>&1) || fail "git --version: $GTV"
echo "OK: $GTV"

# Persistence spot-check: the agent's state dir should have been created
# under $XDG_DATA_HOME inside the sandbox home (in-sandbox ephemeral dir;
# existence proves HERMES_HOME was wired up correctly).
STATE=$(flatpak run --command=/bin/sh "$APP_ID" -c 'ls -d "${XDG_DATA_HOME:-$HOME/.local/share}/hermes" 2>/dev/null && echo OK' 2>&1 | tail -1)
[ "$STATE" = "OK" ] || echo "WARN: HERMES_HOME not present in sandbox home (created on demand per AGENTS.md — acceptable)"

echo "SMOKE OK ($FP_ARCH)"
