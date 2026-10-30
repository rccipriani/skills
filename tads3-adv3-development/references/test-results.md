# Provisioning test results

Results recorded 2026-10-30 in the skill workspace:

- `bash -n scripts/tads3-toolchain.sh tests/run.sh tests/clean-container.sh`:
  passed with no syntax diagnostics.
- `tests/run.sh`: passed all 26 offline mock scenarios with zero failures.
  Acquisition coverage includes authorization refusal, transport failure with
  no published cache entry, wrong commit rejection, signature-verification
  failure, cache reuse without network access, locally calculated tree-hash
  mismatch, and incomplete-cache rejection.
- `python3 -m json.tool manifest.json`: passed.
- `shellcheck`: not run because it was not installed in the environment.
- Live upstream fetch: not run; no download authorization was granted for the
  test session, and the operator's trusted GnuPG keyring was not assumed.
- `tests/clean-container.sh`: not run; container image/repository access and
  package installation were not authorized for the test session.

These results do not claim a live network, clean-container, or compilation
test of the newly fetched upstream tree.
