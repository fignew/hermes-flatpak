#!/bin/sh
# Hermes agent CLI shim bundled with the desktop flatpak.
# Backed by the venv pre-built at package build time (uv sync --locked).
# Same HERMES_HOME policy as the desktop wrapper: persistent XDG data dir.
export HERMES_HOME="${HERMES_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/hermes}"
# Same container-engine policy as the desktop wrapper.
if [ -S "${XDG_RUNTIME_DIR}/podman/podman.sock" ]; then
  export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
elif [ -S "${XDG_RUNTIME_DIR}/docker.sock" ]; then
  export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/docker.sock"
fi
exec /app/lib/hermes-agent/.venv/bin/python -m hermes_cli.main "$@"
