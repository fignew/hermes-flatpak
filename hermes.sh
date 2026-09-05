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
exec zypak-wrapper.sh /app/hermes/Hermes \
  --wayland-app-id=dev.nousresearch.hermes \
  --class=dev.nousresearch.hermes \
  "$@"
