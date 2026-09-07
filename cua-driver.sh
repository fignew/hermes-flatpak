#!/bin/sh
# Bundled cua-driver launcher (flatpak).
#
# Telemetry opt-out lives HERE rather than in the callers so that EVERY
# invocation — Hermes' own spawns via PATH, app-terminal shells, doctor/
# status/check-update — inherits it: the environment override is first in
# the driver's consent precedence and beats both the persisted preference
# and the default-on policy. (Hermes' child-env policy in
# tools/computer_use/cua_backend.py sets the same variable; this covers
# the invocations Hermes does not make.)
#
# Inside the sandbox the driver cannot reach the network beyond the app's
# own grants and ships content-free telemetry only, but a bundled image
# should not phone home at all by default. Users who genuinely want it can
# run `CUA_DRIVER_RS_TELEMETRY_ENABLED=1 cua-driver ...` per-invocation.
export CUA_DRIVER_RS_TELEMETRY_ENABLED=0
exec /app/lib/cua-driver/cua-driver "$@"
