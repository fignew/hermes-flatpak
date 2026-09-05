#!/bin/sh
# Hermes agent CLI shim bundled with the desktop flatpak.
# Backed by the venv pre-built at package build time (uv sync --locked).
# Same HERMES_HOME policy as the desktop wrapper: persistent XDG data dir.
export HERMES_HOME="${HERMES_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/hermes}"
# Same cua-driver persistence redirect as the desktop wrapper.
XDG_DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
mkdir -p "$XDG_DATA/cua-driver" "$XDG_DATA/local-bin"
if [ ! -L "$HOME/.cua-driver" ]; then rm -rf "$HOME/.cua-driver"; ln -s "$XDG_DATA/cua-driver" "$HOME/.cua-driver"; fi
mkdir -p "$HOME/.local"
if [ ! -L "$HOME/.local/bin" ]; then rm -rf "$HOME/.local/bin"; ln -s "$XDG_DATA/local-bin" "$HOME/.local/bin"; fi
export PATH="$XDG_DATA/local-bin:$PATH"
exec /app/lib/hermes-agent/.venv/bin/python -m hermes_cli.main "$@"
