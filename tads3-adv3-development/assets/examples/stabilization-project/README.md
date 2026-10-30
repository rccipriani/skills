# Stabilization regression fixture

This original, neutral standard-adv3 fixture verifies four independently
observed development hazards: `.t3m` paths relative to a manifest below
`config/`, English `turn on`/`switch on` dispatch to `TurnOn`, paired lockable
doors, and explicit placement of a puzzle-critical object.

Run it through `tests/adv3-stabilization.sh`. Generated images, object files,
logs, status files, and transcripts remain below this project on the host and
are ignored as test output rather than source assets.

The debug build includes a zero-time `regressionarchiveside` command used only
to test the locked connector from its far side. It is excluded from release
and is not part of the fixture's unlocking path.
