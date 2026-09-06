#!/bin/sh
# Launcher for Hermes Desktop inside the flatpak sandbox.
# - zypak provides the Chromium sandbox (setuid chrome-sandbox cannot work in flatpak).
# - HERMES_DESKTOP_HERMES_ROOT points at the agent backend bundled in this
#   flatpak (same pinned commit as the desktop payload); the desktop's
#   resolver adopts it directly (bootstrap: false) — no runtime clone/install.
# - --wayland-app-id / --class make the window's identity equal the flatpak
#   app-id so GNOME/KDE/niri window trackers match it to our .desktop file
#   (otherwise the dock shows a letter fallback instead of the Hermes icon).
# - HERMES_HOME must live under $XDG_DATA_HOME: flatpak only makes
#   ~/.var/app/<id>/{config,data,cache} persistent; ~/.hermes would land on
#   the ephemeral sandbox home and vanish on every restart (config, API
#   keys, sessions, logs would all reset).
export ELECTRON_OZONE_PLATFORM_HINT=auto
export HERMES_DESKTOP_HERMES_ROOT=/app/lib/hermes-agent
export HERMES_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/hermes"
# cua-driver (computer-use) persistence: its installer writes to ~/.cua-driver
# and ~/.local/bin — both ephemeral in the sandbox home. Redirect them onto
# $XDG_DATA_HOME (persistent) via symlinks recreated each launch, and put the
# bin dir on PATH for the backend and its child shells.
XDG_DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
mkdir -p "$XDG_DATA/cua-driver" "$XDG_DATA/local-bin"
if [ ! -L "$HOME/.cua-driver" ]; then rm -rf "$HOME/.cua-driver"; ln -s "$XDG_DATA/cua-driver" "$HOME/.cua-driver"; fi
mkdir -p "$HOME/.local"
if [ ! -L "$HOME/.local/bin" ]; then rm -rf "$HOME/.local/bin"; ln -s "$XDG_DATA/local-bin" "$HOME/.local/bin"; fi
export PATH="$XDG_DATA/local-bin:$PATH"
# The desktop replaces PATH from a login shell when spawning the backend
# ("merged login-shell PATH"), which drops the export above. Persist the
# PATH addition into the shell rc files (ephemeral, recreated each launch)
# so bash -l, interactive shells, and sh -c all see ~/.local/bin.
SNIP='export PATH="$HOME/.local/bin:$PATH" # flatpak-local-bin'
for RC in "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bashrc"; do
  [ -f "$RC" ] || : > "$RC"
  grep -q "flatpak-local-bin" "$RC" || printf '\n%s\n' "$SNIP" >> "$RC"
done
exec zypak-wrapper.sh /app/hermes/Hermes \
  --wayland-app-id=dev.nousresearch.hermes \
  --class=dev.nousresearch.hermes \
  "$@"
