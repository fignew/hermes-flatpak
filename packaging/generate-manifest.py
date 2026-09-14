#!/usr/bin/env python3
"""Generate the CI manifest from the template + per-run substitutions.

Substitutions (all injected by CI via env, all validated here):
  HERMES_REF      upstream git ref (branch `main` or a tag like v2026.9.14)
  HERMES_COMMIT   resolved commit SHA of that ref (stamped for traceability;
                  the type:git source still needles the moving ref)

Manifest contract (see flatter/README):
  1. type:git source has `branch: __HERMES_REF__` placeholder.
  2. `x-checker-data.commit` note is rewritten with the resolved SHA.
  3. metainfo release description gets the packaged commit.

Rationale: `type: git` with a branch ref re-fetches upstream during build —
that's the intent for daily main-tracking (a hard-pinned `type: dir` /
`commit:` should NOT drift from what the workflow resolved; if you later want
bit-for-bit reproducibility, set HERMES_COMMIT and swap the source to
`commit:` via this same script).
"""

import os
import re
import sys
import pathlib

def die(msg: str) -> "None":
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(1)

def main() -> None:
    template = pathlib.Path(__file__).parent / "dev.nousresearch.hermes.yml"
    out_dir = pathlib.Path(os.environ.get("CI_MANIFEST_OUT", "."))
    out = out_dir / "dev.nousresearch.hermes.yml"

    hermes_ref = os.environ.get("HERMES_REF") or die("HERMES_REF not set")
    hermes_commit = os.environ.get("HERMES_COMMIT", "")

    # Sanitize the ref so `${HERMES_REF}` interpolation below can never
    # inject YAML structure (a ref like "main'; --evil" should die loudly).
    if not re.fullmatch(r"[A-Za-z0-9._/\-]+", hermes_ref):
        die(f"HERMES_REF has unlikely characters: {hermes_ref!r}")

    text = template.read_text()

    # Validate that both placeholders exist (fail loudly if the template
    # changed out from under this script).
    if "__HERMES_REF__" not in text:
        die("template is missing __HERMES_REF__ placeholder")

    text = text.replace("__HERMES_REF__", hermes_ref)

    if hermes_commit and "__HERMES_COMMIT__" in text:
        text = text.replace("__HERMES_COMMIT__", hermes_commit)
    elif hermes_commit:
        # Template has no commit placeholder — informational only.
        print(f"note: HERMES_COMMIT={hermes_commit} set but template has no "
              "__HERMES_COMMIT__ placeholder; skipping stamp")

    out.write_text(text)
    print(f"OK: wrote {out} (ref={hermes_ref} commit={hermes_commit or 'n/a'})")

if __name__ == "__main__":
    main()
